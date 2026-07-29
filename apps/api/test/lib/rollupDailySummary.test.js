const { test } = require('node:test');
const assert = require('node:assert/strict');

const { db } = require('../../src/firebase');
const {
  computeAndSaveDailySummary,
  fetchObservationsForDay,
  summarizeDay,
  dayBoundsUtc,
} = require('../../src/lib/rollupDailySummary');

test('dayBoundsUtc returns a 24h UTC window', () => {
  const { start, end } = dayBoundsUtc('2026-07-29');
  assert.equal(start.toISOString(), '2026-07-29T00:00:00.000Z');
  assert.equal(end.toISOString(), '2026-07-30T00:00:00.000Z');
});

test('summarizeDay counts categories, alerts, and unresolved concerns', () => {
  const observations = [
    {
      categories: ['sleep', 'appetite'],
      safetyAssessment: { concernLevel: 'high', recommendFollowUp: true },
      reviewedByAuthor: false,
      structuredObservation: { summary: 'Slept poorly.' },
    },
    {
      categories: ['sleep'],
      safetyAssessment: { concernLevel: 'none', recommendFollowUp: false },
      reviewedByAuthor: false,
      structuredObservation: { summary: 'Slept fine later.' },
    },
    {
      categories: ['mood'],
      safetyAssessment: { concernLevel: 'medium', recommendFollowUp: true },
      reviewedByAuthor: true, // already reviewed -> shouldn't count as unresolved
      structuredObservation: { summary: 'Seemed low.' },
    },
  ];

  const summary = summarizeDay(observations);

  assert.deepEqual(summary.observationCounts, { sleep: 2, appetite: 1, mood: 1 });
  assert.equal(summary.activeAlertCount, 2); // high + medium
  assert.equal(summary.unresolvedConcernCount, 1); // only the unreviewed one
  assert.equal(summary.summaryText.en, 'Slept poorly. Slept fine later. Seemed low.');
  assert.deepEqual(summary.taskCounts, {});
  assert.deepEqual(summary.medicationCounts, {});
  assert.deepEqual(summary.measurementHighlights, []);
});

test('summarizeDay handles zero observations', () => {
  const summary = summarizeDay([]);
  assert.deepEqual(summary.observationCounts, {});
  assert.equal(summary.activeAlertCount, 0);
  assert.equal(summary.unresolvedConcernCount, 0);
  assert.equal(summary.summaryText.en, null);
});

test('fetchObservationsForDay queries the right collection and date range', async (t) => {
  const queries = [];
  t.mock.method(db, 'collection', (path) => {
    const query = {
      where(field, op, value) {
        queries.push({ path, field, op, value });
        return query;
      },
      get: async () => ({ docs: [{ data: () => ({ categories: ['sleep'] }) }] }),
    };
    return query;
  });

  const result = await fetchObservationsForDay({
    householdId: 'h1',
    careRecipientId: 'r1',
    dateKey: '2026-07-29',
  });

  assert.deepEqual(result, [{ categories: ['sleep'] }]);
  assert.equal(queries[0].path, 'households/h1/careRecipients/r1/observations');
  assert.equal(queries[0].field, 'observedAt');
  assert.equal(queries[0].op, '>=');
  assert.equal(queries[1].op, '<');
});

test('computeAndSaveDailySummary writes to the dailySummaries doc', async (t) => {
  t.mock.method(db, 'collection', () => ({
    where() {
      return this;
    },
    get: async () => ({ docs: [] }),
  }));

  let savedPath;
  let savedDoc;
  t.mock.method(db, 'doc', (path) => ({
    set: async (doc) => {
      savedPath = path;
      savedDoc = doc;
    },
  }));

  const result = await computeAndSaveDailySummary({
    householdId: 'h1',
    careRecipientId: 'r1',
    dateKey: '2026-07-29',
  });

  assert.equal(savedPath, 'households/h1/careRecipients/r1/dailySummaries/2026-07-29');
  assert.equal(savedDoc.dateKey, '2026-07-29');
  assert.equal(result, savedDoc);
});
