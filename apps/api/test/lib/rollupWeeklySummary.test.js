const { test } = require('node:test');
const assert = require('node:assert/strict');

const { db } = require('../../src/firebase');
const rollupDailySummary = require('../../src/lib/rollupDailySummary');
const {
  computeAndSaveWeeklySummary,
  isoDateKeysInRange,
  averageMetric,
  NO_DATA_DEFAULT,
} = require('../../src/lib/rollupWeeklySummary');

test('isoDateKeysInRange returns 7 consecutive UTC dates', () => {
  const keys = isoDateKeysInRange('2026-07-27T00:00:00.000Z');
  assert.deepEqual(keys, [
    '2026-07-27', '2026-07-28', '2026-07-29', '2026-07-30',
    '2026-07-31', '2026-08-01', '2026-08-02',
  ]);
});

test('averageMetric averages only numeric values for the given field', () => {
  const observations = [
    { structuredObservation: { sleepQuality: 0.8 } },
    { structuredObservation: { sleepQuality: 0.4 } },
    { structuredObservation: {} }, // no sleepQuality mentioned
  ];
  assert.ok(Math.abs(averageMetric(observations, 'sleepQuality') - 0.6) < 1e-9);
});

test('averageMetric returns null when nothing has the field', () => {
  assert.equal(averageMetric([{ structuredObservation: {} }], 'moodScore'), null);
  assert.equal(averageMetric([], 'moodScore'), null);
});

test('computeAndSaveWeeklySummary fills days with no data using the neutral default', async (t) => {
  t.mock.method(rollupDailySummary, 'fetchObservationsForDay', async ({ dateKey }) => {
    if (dateKey === '2026-07-27') {
      return [{ structuredObservation: { sleepQuality: 0.9, appetiteLevel: 0.7, moodScore: 0.8 } }];
    }
    return [];
  });

  let savedPath;
  let savedDoc;
  t.mock.method(db, 'doc', (path) => ({
    set: async (doc) => {
      savedPath = path;
      savedDoc = doc;
    },
  }));

  const result = await computeAndSaveWeeklySummary({
    householdId: 'h1',
    careRecipientId: 'r1',
    weekKey: '2026-W31',
    periodStart: '2026-07-27T00:00:00.000Z',
  });

  assert.equal(savedPath, 'households/h1/careRecipients/r1/weeklySummaries/2026-W31');
  assert.equal(result.trendSeries.sleep[0], 0.9);
  assert.equal(result.trendSeries.food[0], 0.7);
  assert.equal(result.trendSeries.mood[0], 0.8);
  // every other day had no data -> neutral default
  for (let i = 1; i < 7; i += 1) {
    assert.equal(result.trendSeries.sleep[i], NO_DATA_DEFAULT);
  }
  assert.equal(savedDoc.trendSeries.days.length, 7);
});

test('computeAndSaveWeeklySummary counts medium/high alerts across the week', async (t) => {
  t.mock.method(rollupDailySummary, 'fetchObservationsForDay', async ({ dateKey }) => {
    if (dateKey === '2026-07-27') return [{ safetyAssessment: { concernLevel: 'high' } }];
    if (dateKey === '2026-07-29') return [{ safetyAssessment: { concernLevel: 'medium' } }];
    if (dateKey === '2026-07-30') return [{ safetyAssessment: { concernLevel: 'none' } }];
    return [];
  });
  t.mock.method(db, 'doc', () => ({ set: async () => {} }));

  const result = await computeAndSaveWeeklySummary({
    householdId: 'h1',
    careRecipientId: 'r1',
    weekKey: '2026-W31',
    periodStart: '2026-07-27T00:00:00.000Z',
  });

  assert.equal(result.activeAlertCount, 2);
});
