const test = require('node:test');
const assert = require('node:assert');

const {
  SYMPTOMS,
  URGENCY,
  assessSymptom,
  buildSummaryText,
} = require('../src/lib/symptomTriage');

// These tests are the safety net for the only part of the app that tells a
// caregiver whether to call an ambulance. They assert the direction of the
// rules (never silently downgrade), not just that the code runs.

test('every red-flag answer escalates to emergency, for every symptom', () => {
  for (const [symptomKey, symptom] of Object.entries(SYMPTOMS)) {
    for (const question of symptom.questions.filter((q) => q.redFlag)) {
      const result = assessSymptom({ symptomKey, answers: { [question.id]: true } });
      assert.strictEqual(
        result.urgency,
        URGENCY.emergency,
        `${symptomKey}.${question.id} is a red flag but did not escalate`,
      );
      assert.strictEqual(result.concernLevel, 'high');
    }
  }
});

test('no answers falls back to the symptom baseline, never to nothing', () => {
  for (const [symptomKey, symptom] of Object.entries(SYMPTOMS)) {
    const result = assessSymptom({ symptomKey, answers: {} });
    assert.strictEqual(result.urgency, symptom.baseline);
    assert.ok(
      [URGENCY.today, URGENCY.watch].includes(result.urgency),
      `${symptomKey} baseline should be today or watch`,
    );
  }
});

test('breathing, chest pain, fall, confusion and fever are never "watch"', () => {
  // An elder with any of these needs care today even with a clean answer
  // sheet — see the reasoning comments in symptomTriage.js.
  for (const symptomKey of ['breathing', 'chestPain', 'fall', 'confusion', 'fever']) {
    const result = assessSymptom({ symptomKey, answers: {} });
    assert.notStrictEqual(result.urgency, URGENCY.watch, `${symptomKey} must not be "watch"`);
  }
});

test('not-eating starts at watch but lifts to today on any concern', () => {
  assert.strictEqual(assessSymptom({ symptomKey: 'notEating', answers: {} }).urgency, URGENCY.watch);
  assert.strictEqual(
    assessSymptom({ symptomKey: 'notEating', answers: { noDrinkOneDay: true } }).urgency,
    URGENCY.today,
  );
  // weakDizzy is a red flag, so it goes all the way up.
  assert.strictEqual(
    assessSymptom({ symptomKey: 'notEating', answers: { weakDizzy: true } }).urgency,
    URGENCY.emergency,
  );
});

test('explicit "no" answers do not escalate', () => {
  const result = assessSymptom({
    symptomKey: 'breathing',
    answers: { atRest: false, blueLips: false, cannotSpeak: false },
  });
  assert.strictEqual(result.urgency, URGENCY.today);
  assert.deepStrictEqual(result.concerns, []);
});

test('non-boolean answers are not treated as yes', () => {
  // A client sending "true", 1, or null must not be able to trip an
  // emergency by accident — only a real boolean true counts.
  for (const truthy of ['true', 1, {}, [], 'yes']) {
    const result = assessSymptom({ symptomKey: 'fall', answers: { hitHead: truthy } });
    assert.strictEqual(result.urgency, URGENCY.today, `${JSON.stringify(truthy)} should not escalate`);
  }
});

test('unknown symptom is rejected rather than silently assessed', () => {
  assert.throws(() => assessSymptom({ symptomKey: 'nope', answers: {} }), /Unknown symptom/);
});

test('summary names the symptom, the concerns, and the action', () => {
  const text = buildSummaryText({
    symptomKey: 'fall',
    answers: { hitHead: true },
    note: 'She slipped in the bathroom.',
  });
  assert.match(text, /She fell down/);
  assert.match(text, /She hit her head\./);
  assert.match(text, /She slipped in the bathroom\./);
  assert.match(text, /Call 119 now/);
});

test('summary states facts, never echoes the questions back', () => {
  // This text is machine-translated for the family. "Yes: did she hit her
  // head?" reads as a question being asked of them, which is worse in
  // Mandarin than in English — so no question marks may survive into it.
  for (const [symptomKey, symptom] of Object.entries(SYMPTOMS)) {
    const answers = Object.fromEntries(symptom.questions.map((q) => [q.id, true]));
    const text = buildSummaryText({ symptomKey, answers });
    assert.doesNotMatch(text, /\?/, `${symptomKey} summary contains a question`);
  }
});

test('every question carries a statement form', () => {
  for (const [symptomKey, symptom] of Object.entries(SYMPTOMS)) {
    for (const question of symptom.questions) {
      assert.ok(
        typeof question.statement === 'string' && question.statement.length > 0,
        `${symptomKey}.${question.id} has no statement`,
      );
      assert.doesNotMatch(question.statement, /\?/);
    }
  }
});

test('summary is honest when nothing was flagged', () => {
  const text = buildSummaryText({ symptomKey: 'notEating', answers: {} });
  assert.match(text, /No warning signs reported\./);
  assert.doesNotMatch(text, /Call 119/);
});
