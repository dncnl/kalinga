const test = require('node:test');
const assert = require('node:assert');

const { CHECKIN_FORMS, scoresFor, buildCheckinSummary } = require('../src/lib/reminderCheckin');

test('eating answers map onto appetiteLevel across the whole range', () => {
  const of = (howMuch) => scoresFor({ category: 'meal', answers: { howMuch } }).appetiteLevel;
  assert.strictEqual(of('all'), 1.0);
  assert.strictEqual(of('half'), 0.5);
  assert.strictEqual(of('none'), 0.0);
});

test('a refusal pulls appetite down even when she ate something', () => {
  const scores = scoresFor({ category: 'meal', answers: { howMuch: 'most', refused: 'yes' } });
  assert.ok(scores.appetiteLevel <= 0.25, `expected a low appetite score, got ${scores.appetiteLevel}`);
});

test('answering about a meal never invents a sleep or mood score', () => {
  // The neutral 0.5 is the extractor's "not mentioned" value — anything
  // else here would put fabricated points on the family's trend chart.
  const scores = scoresFor({ category: 'meal', answers: { howMuch: 'none' } });
  assert.strictEqual(scores.sleepQuality, 0.5);
  assert.strictEqual(scores.moodScore, 0.5);
});

test('exercise records mobility separately, not squeezed into another score', () => {
  const scores = scoresFor({ category: 'exercise', answers: { duration: 'long', difficulty: 'yes' } });
  assert.strictEqual(scores.mobilityLevel, 1.0);
  assert.strictEqual(scores.mobilityHarderThanUsual, true);
  assert.strictEqual(scores.appetiteLevel, 0.5);
});

test('an unknown category yields neutral scores rather than throwing', () => {
  // Custom labels are allowed and get no question set — they must still
  // complete cleanly.
  const scores = scoresFor({ category: 'other', answers: { anything: 'x' } });
  assert.deepStrictEqual(scores, { sleepQuality: 0.5, appetiteLevel: 0.5, moodScore: 0.5 });
});

test('unrecognised answer ids are ignored, not scored', () => {
  const scores = scoresFor({ category: 'meal', answers: { howMuch: 'not-an-option' } });
  assert.strictEqual(scores.appetiteLevel, 0.5);
});

test('summary reads as a sentence and carries the note', () => {
  const text = buildCheckinSummary({
    category: 'meal',
    taskTitle: 'Lunch',
    answers: { howMuch: 'half', refused: 'yes' },
    note: 'She said it was too salty.',
  });
  assert.match(text, /^Lunch:/);
  assert.match(text, /she ate about half/i);
  assert.match(text, /refused or pushed the food away/i);
  assert.match(text, /too salty/);
});

test('summary still says something when nothing was answered', () => {
  const text = buildCheckinSummary({ category: 'other', taskTitle: 'Water', answers: {} });
  assert.strictEqual(text, 'Water: done.');
});

test('every option value stays inside the 0..1 score range', () => {
  for (const form of Object.values(CHECKIN_FORMS)) {
    for (const question of form.questions) {
      for (const option of question.options) {
        if (option.value === null) continue;
        assert.ok(option.value >= 0 && option.value <= 1, `${option.id} is out of range`);
      }
    }
  }
});
