const { db } = require('../firebase');
const rollupDailySummary = require('./rollupDailySummary');

// Average of whatever the day's observations reported for this metric.
// A day with zero mentions returns null (see mergeWithDefault below) rather
// than a made-up number.
function averageMetric(observations, field) {
  const values = observations
    .map((obs) => obs.structuredObservation?.[field])
    .filter((v) => typeof v === 'number');

  if (values.length === 0) return null;
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

// The trend chart needs a bar height for every day even if the caregiver
// didn't log that metric that day. 0.5 (neutral/middle) is a placeholder,
// not a real reading — flagged in PLAN.md as worth revisiting (e.g.
// carry-forward the last known value instead) once this has real users.
const NO_DATA_DEFAULT = 0.5;

function mergeWithDefault(value) {
  return value === null ? NO_DATA_DEFAULT : value;
}

function isoDateKeysInRange(periodStart, days = 7) {
  const keys = [];
  const cursor = new Date(periodStart);
  for (let i = 0; i < days; i += 1) {
    keys.push(cursor.toISOString().slice(0, 10));
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return keys;
}

async function computeAndSaveWeeklySummary({ householdId, careRecipientId, weekKey, periodStart }) {
  const dateKeys = isoDateKeysInRange(periodStart);

  const dayObservations = await Promise.all(
    dateKeys.map((dateKey) =>
      rollupDailySummary.fetchObservationsForDay({ householdId, careRecipientId, dateKey }),
    ),
  );

  const sleep = dayObservations.map((obs) => mergeWithDefault(averageMetric(obs, 'sleepQuality')));
  const food = dayObservations.map((obs) => mergeWithDefault(averageMetric(obs, 'appetiteLevel')));
  const mood = dayObservations.map((obs) => mergeWithDefault(averageMetric(obs, 'moodScore')));

  const activeAlertCount = dayObservations
    .flat()
    .filter((obs) => ['medium', 'high'].includes(obs.safetyAssessment?.concernLevel)).length;

  const periodEnd = new Date(periodStart);
  periodEnd.setUTCDate(periodEnd.getUTCDate() + 7);

  const doc = {
    weekKey,
    periodStart: new Date(periodStart),
    periodEnd,
    timezone: 'UTC',
    trendSeries: { days: dateKeys, sleep, food, mood },
    notableChanges: [],
    activeAlertCount,
    summaryText: {},
    generatedFromVersion: 1,
    generatedAt: new Date(),
  };

  await db
    .doc(`households/${householdId}/careRecipients/${careRecipientId}/weeklySummaries/${weekKey}`)
    .set(doc);

  return doc;
}

module.exports = { computeAndSaveWeeklySummary, isoDateKeysInRange, averageMetric, NO_DATA_DEFAULT };
