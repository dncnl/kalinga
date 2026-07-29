const { test } = require('node:test');
const assert = require('node:assert/strict');

const { extractObservation, normalizeCategories, normalizeScore } = require('../../src/lib/extractObservation');

function mockFetchOk(t, toolCallArguments) {
  t.mock.method(global, 'fetch', async (url, options) => {
    assert.equal(url, 'https://openrouter.ai/api/v1/chat/completions');
    JSON.parse(options.body); // just confirm it's valid JSON

    return {
      ok: true,
      json: async () => ({
        choices: [
          {
            message: {
              tool_calls: toolCallArguments
                ? [{ function: { arguments: JSON.stringify(toolCallArguments) } }]
                : undefined,
            },
          },
        ],
      }),
    };
  });
}

test('extractObservation parses the tool call arguments', async (t) => {
  const fakeExtraction = {
    categories: ['sleep', 'appetite'],
    comparisonToUsual: 'worse',
    structuredObservation: {
      summary: 'Slept poorly, ate less than usual.',
      sleepQuality: 0.2,
      appetiteLevel: 0.4,
    },
    safetyAssessment: { concernLevel: 'low', concerns: [], recommendFollowUp: false },
  };

  mockFetchOk(t, fakeExtraction);

  const result = await extractObservation({ transcript: 'Slept poorly, ate less than usual.' });

  assert.deepEqual(result, {
    ...fakeExtraction,
    structuredObservation: {
      ...fakeExtraction.structuredObservation,
      moodScore: null,
    },
  });
});

test('extractObservation throws when the model does not call the tool', async (t) => {
  mockFetchOk(t, null);

  await assert.rejects(
    () => extractObservation({ transcript: 'anything' }),
    /did not return structured observation data/,
  );
});

test('extractObservation throws on a non-ok HTTP response', async (t) => {
  t.mock.method(global, 'fetch', async () => ({
    ok: false,
    status: 429,
    text: async () => 'rate limited',
  }));

  await assert.rejects(
    () => extractObservation({ transcript: 'anything' }),
    /OpenRouter request failed \(429\)/,
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
