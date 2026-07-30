const firebase = require('../firebase');
const { transcribeAudio } = require('./transcribe');
const { translateToMandarin } = require('./translate');
const { extractObservation } = require('./extractObservation');
const { buildObservationDocument } = require('./buildObservationDocument');
// Namespace requires (not destructured) so tests can mock these directly.
const rollupDailySummary = require('./rollupDailySummary');
const rollupWeeklySummary = require('./rollupWeeklySummary');
const { currentWeekKey, currentWeekStartUtc, dateKeyOf } = require('./weekKey');

// The actual slow part of voice-log processing (Speech-to-Text, then
// translate+extract) — runs AFTER the route has already responded, so the
// caregiver sees "Logged" immediately instead of waiting through all of
// this. See routes/observations.js for the fast-response side.
//
// Firestore's RecordStatus enum (schema conventions) has no "failed" value
// — 'cancelled' is the closest existing fit for "this didn't complete";
// processingError is an additive, unmodeled-in-schema field carrying why,
// left null on success.
async function processObservationJob({ householdId, careRecipientId, observationId, uid, locale, storagePath }) {
  const observationRef = firebase.db.doc(
    `households/${householdId}/careRecipients/${careRecipientId}/observations/${observationId}`,
  );

  try {
    const bucketName = firebase.getBucket().name;
    const gcsUri = `gs://${bucketName}/${storagePath}`;

    const { text: transcript } = await transcribeAudio({ gcsUri, locale });
    if (!transcript.trim()) {
      await observationRef.update({
        status: 'cancelled',
        processingError: 'No speech detected in recording.',
        updatedAt: new Date(),
      });
      return;
    }

    // Translation and LLM extraction both only need the transcript —
    // run them in parallel.
    const [{ text: translatedText }, extraction] = await Promise.all([
      translateToMandarin({ text: transcript, sourceLocale: locale, projectId: firebase.projectId }),
      extractObservation({ transcript }),
    ]);

    const observationDoc = buildObservationDocument({ uid, locale, transcript, translatedText, extraction });
    observationDoc.originalAudioAssetId = storagePath;
    observationDoc.processingError = null;

    await observationRef.set(observationDoc);

    // Chart-relevant rollup, now that the observation this data point
    // depends on has actually finished writing — triggering it any
    // earlier (e.g. from the client right after the fast response) would
    // race the write above and roll up stale data missing this entry.
    const today = dateKeyOf(new Date());
    const weekStart = currentWeekStartUtc();
    await Promise.all([
      rollupDailySummary.computeAndSaveDailySummary({ householdId, careRecipientId, dateKey: today }),
      rollupWeeklySummary.computeAndSaveWeeklySummary({
        householdId,
        careRecipientId,
        weekKey: currentWeekKey(),
        periodStart: weekStart.toISOString(),
      }),
    ]);
  } catch (err) {
    console.error(`processObservationJob failed for ${observationRef.path}:`, err);
    await observationRef.update({
      status: 'cancelled',
      processingError: err.message,
      updatedAt: new Date(),
    }).catch((updateErr) => {
      console.error(`processObservationJob: also failed to record the failure for ${observationRef.path}:`, updateErr);
    });
  }
}

module.exports = { processObservationJob };
