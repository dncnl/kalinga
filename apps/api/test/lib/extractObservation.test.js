const { test } = require('node:test');
const assert = require('node:assert/strict');

const llmClient = require('../../src/lib/llmClient');
const { extractObservation, normalizeCategories, normalizeScore } = require('../../src/lib/extractObservation');

function mockExtraction(t, parsed) {
  return t.mock.method(llmClient, 'generateStructured', async ({ prompt }) => {
    assert.match(prompt, /Transcript:/);
    return parsed;
  });
}

test('extractObservation returns the parsed extraction with normalized fields', async (t) => {
  mockExtraction(t, {
    categories: ['sleep', 'appetite'],
    comparisonToUsual: 'worse',
    structuredObservation: {
      summary: 'Slept poorly, ate less than usual.',
      sleepQuality: 0.2,
      appetiteLevel: 0.4,
    },
    safetyAssessment: { concernLevel: 'low', concerns: [], recommendFollowUp: false },
  });

  const result = await extractObservation({ transcript: 'Slept poorly, ate less than usual.' });

  assert.deepEqual(result, {
    categories: ['sleep', 'appetite'],
    comparisonToUsual: 'worse',
    structuredObservation: {
      summary: 'Slept poorly, ate less than usual.',
      sleepQuality: 0.2,
      appetiteLevel: 0.4,
      moodScore: null,
    },
    safetyAssessment: { concernLevel: 'low', concerns: [], recommendFollowUp: false },
  });
});

test('extractObservation normalizes category synonyms and out-of-range scores', async (t) => {
  mockExtraction(t, {
    categories: ['energy', 'food'],
    comparisonToUsual: 'same',
    structuredObservation: { summary: 'x', sleepQuality: 5, moodScore: -1 },
    safetyAssessment: { concernLevel: 'none', concerns: [], recommendFollowUp: false },
  });

  const result = await extractObservation({ transcript: 'anything' });

  assert.deepEqual(result.categories, ['mobility', 'appetite']);
  assert.equal(result.structuredObservation.sleepQuality, 1);
  assert.equal(result.structuredObservation.moodScore, 0);
});

test('extractObservation propagates errors from the LLM client', async (t) => {
  t.mock.method(llmClient, 'generateStructured', async () => {
    throw new Error('rate limited upstream');
  });

  await assert.rejects(
    () => extractObservation({ transcript: 'anything' }),
    /rate limited upstream/,
  );
});

test('normalizeCategories passes through valid enum values unchanged', () => {
  assert.deepEqual(normalizeCategories(['sleep', 'appetite']), ['sleep', 'appetite']);
});

test('normalizeCategories maps known synonyms onto real categories', () => {
  assert.deepEqual(normalizeCategories(['energy', 'food', 'Water']), ['mobility', 'appetite', 'hydration']);
});

test('normalizeCategories falls back to "other" for unknown words', () => {
  assert.deepEqual(normalizeCategories(['xyz-not-a-category']), ['other']);
});

test('normalizeCategories dedupes after normalization', () => {
  assert.deepEqual(normalizeCategories(['sleep', 'sleep', 'energy', 'fatigue']), ['sleep', 'mobility']);
});

test('normalizeCategories returns an empty array for non-array input', () => {
  assert.deepEqual(normalizeCategories(undefined), []);
});

test('normalizeScore passes valid 0-1 numbers through unchanged', () => {
  assert.equal(normalizeScore(0.5), 0.5);
  assert.equal(normalizeScore(0), 0);
  assert.equal(normalizeScore(1), 1);
});

test('normalizeScore clamps out-of-range numbers', () => {
  assert.equal(normalizeScore(5), 1);
  assert.equal(normalizeScore(-3), 0);
});

test('normalizeScore returns null for non-numbers or missing values', () => {
  assert.equal(normalizeScore('high'), null);
  assert.equal(normalizeScore(undefined), null);
  assert.equal(normalizeScore(NaN), null);
});
