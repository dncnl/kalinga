const { db } = require('../firebase');
const { Timestamp } = require('firebase-admin/firestore');

// Simplification: treats dateKey as a UTC calendar day. Households aren't
// modeled with a timezone anywhere yet, so there's no better answer right
// now — flagged in PLAN.md.
function dayBoundsUtc(dateKey) {
  const start = new Date(`${dateKey}T00:00:00.000Z`);
  const end = new Date(`${dateKey}T00:00:00.000Z`);
  end.setUTCDate(end.getUTCDate() + 1);
  return { start, end };
}

async function fetchObservationsForDay({ householdId, careRecipientId, dateKey }) {
  const { start, end } = dayBoundsUtc(dateKey);

  const snap = await db
    .collection(`households/${householdId}/careRecipients/${careRecipientId}/observations`)
    .where('observedAt', '>=', Timestamp.fromDate(start))
    .where('observedAt', '<', Timestamp.fromDate(end))
    .get();

  return snap.docs.map((doc) => doc.data());
}

// Only counts what this feature actually produces (voice observations).
// taskCounts/medicationCounts/measurementHighlights stay empty until those
// features exist — not faking data for fields nothing writes yet.
function summarizeDay(observations) {
  const observationCounts = {};
  let activeAlertCount = 0;
  let unresolvedConcernCount = 0;

  for (const obs of observations) {
    for (const category of obs.categories || []) {
      observationCounts[category] = (observationCounts[category] || 0) + 1;
    }

    const concernLevel = obs.safetyAssessment?.concernLevel;
    if (concernLevel === 'medium' || concernLevel === 'high') {
      activeAlertCount += 1;
    }
    if (obs.safetyAssessment?.recommendFollowUp && !obs.reviewedByAuthor) {
      unresolvedConcernCount += 1;
    }
  }

  const summaries = observations
    .map((obs) => obs.structuredObservation?.summary)
    .filter(Boolean);

  return {
    taskCounts: {},
    medicationCounts: {},
    observationCounts,
    measurementHighlights: [],
    activeAlertCount,
    unresolvedConcernCount,
    summaryText: { en: summaries.join(' ') || null },
  };
}

async function computeAndSaveDailySummary({ householdId, careRecipientId, dateKey }) {
  const observations = await fetchObservationsForDay({ householdId, careRecipientId, dateKey });
  const summary = summarizeDay(observations);

  const doc = {
    dateKey,
    timezone: 'UTC',
    ...summary,
    generatedFromVersion: 1,
    generatedAt: new Date(),
  };

  await db
    .doc(`households/${householdId}/careRecipients/${careRecipientId}/dailySummaries/${dateKey}`)
    .set(doc);

  return doc;
}

module.exports = { computeAndSaveDailySummary, fetchObservationsForDay, summarizeDay, dayBoundsUtc };
