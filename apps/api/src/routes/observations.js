const { Router } = require('express');

const firebase = require('../firebase');
const { requireAuth } = require('../middleware/auth');
const { isCaregiverAssigned } = require('../lib/authorizeCaregiver');
const { STT_LANGUAGE_CODES } = require('../lib/transcribe');
// Namespace require (not destructured) so tests can mock
// processObservationJob.processObservationJob directly.
const processObservationJobLib = require('../lib/processObservationJob');
const { timestampId } = require('../lib/readableId');
const { translateToMandarin } = require('../lib/translate');
const { buildObservationDocument } = require('../lib/buildObservationDocument');
const symptomTriage = require('../lib/symptomTriage');
const rollupDailySummary = require('../lib/rollupDailySummary');
const rollupWeeklySummary = require('../lib/rollupWeeklySummary');
const { currentWeekKey, currentWeekStartUtc, dateKeyOf } = require('../lib/weekKey');
// Namespace require (not destructured) so tests can mock
// signedUploadUrl.getSignedUploadUrl directly.
const signedUploadUrl = require('../lib/signedUploadUrl');

const router = Router();

const UPLOAD_URL_TTL_MS = 15 * 60 * 1000;

// Only formats the mobile `record` package realistically produces.
const ALLOWED_CONTENT_TYPES = {
  'audio/m4a': 'm4a',
  'audio/mp4': 'm4a',
  'audio/aac': 'm4a',
  'audio/wav': 'wav',
  'audio/webm': 'webm',
};

// Caregiver's phone calls this first to get a short-lived signed URL, then
// PUTs the recording straight to Storage — audio never passes through this
// server. Processing (step 3) is triggered separately once the upload lands.
router.post(
  '/households/:householdId/care-recipients/:careRecipientId/observations/upload-url',
  requireAuth,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;
    const { contentType } = req.body || {};

    const extension = ALLOWED_CONTENT_TYPES[contentType];
    if (!extension) {
      return res.status(400).json({
        error: `Unsupported contentType. Allowed: ${Object.keys(ALLOWED_CONTENT_TYPES).join(', ')}`,
      });
    }

    const assigned = await isCaregiverAssigned({
      householdId,
      careRecipientId,
      uid: req.uid,
    });
    if (!assigned) {
      return res.status(403).json({ error: 'Not an active caregiver for this care recipient' });
    }

    const observationId = firebase.db
      .collection(`households/${householdId}/careRecipients/${careRecipientId}/observations`)
      .doc(timestampId()).id;

    const storagePath = `households/${householdId}/careRecipients/${careRecipientId}/observations/${observationId}/audio.${extension}`;

    // Recorded so /process can rebuild storagePath itself instead of
    // trusting whatever path the client sends it — otherwise a caller could
    // point processing at an arbitrary object in the bucket.
    await firebase.db
      .doc(`households/${householdId}/careRecipients/${careRecipientId}/observations/${observationId}`)
      .set({ status: 'pendingUpload', audioExtension: extension, createdAt: new Date() });

    const expiresAt = Date.now() + UPLOAD_URL_TTL_MS;
    let uploadUrl;
    try {
      uploadUrl = await signedUploadUrl.getSignedUploadUrl({ storagePath, contentType, expiresAt });
    } catch (err) {
      console.error('observations upload-url: could not sign URL:', err.cause || err);
      return res.status(502).json({ error: err.message });
    }

    res.json({ observationId, uploadUrl, storagePath, expiresAt });
  },
);

// Caregiver's phone calls this once the raw PUT to the signed URL finishes.
// Responds as soon as the upload is confirmed valid — the actual pipeline
// (Speech-to-Text, then translate+extract, then rollup) runs afterward as
// a background job (see lib/processObservationJob.js) instead of blocking
// this response, since STT + LLM extraction were taking long enough to
// make the caregiver wait through the whole thing before seeing "Logged."
// The observation doc's `status` field tracks progress
// (processing -> ready, or cancelled + processingError on failure) for
// anything that wants to reflect that later (e.g. a Firestore listener).
router.post(
  '/households/:householdId/care-recipients/:careRecipientId/observations/:observationId/process',
  requireAuth,
  async (req, res) => {
    const { householdId, careRecipientId, observationId } = req.params;
    const { locale } = req.body || {};

    if (!locale) {
      return res.status(400).json({ error: 'locale is required' });
    }
    if (!STT_LANGUAGE_CODES[locale]) {
      return res.status(400).json({
        error: `locale "${locale}" is not supported for transcription yet`,
      });
    }

    const assigned = await isCaregiverAssigned({
      householdId,
      careRecipientId,
      uid: req.uid,
    });
    if (!assigned) {
      return res.status(403).json({ error: 'Not an active caregiver for this care recipient' });
    }

    // storagePath is rebuilt server-side from the extension recorded at
    // upload-url time — never trust a client-supplied path, since that would
    // let a caller point transcription at an arbitrary object in the bucket.
    const observationRef = firebase.db.doc(
      `households/${householdId}/careRecipients/${careRecipientId}/observations/${observationId}`,
    );
    const observationSnap = await observationRef.get();
    if (!observationSnap.exists || observationSnap.data().status !== 'pendingUpload') {
      return res.status(404).json({ error: 'No upload found for this observation' });
    }
    const extension = observationSnap.data().audioExtension;
    const storagePath = `households/${householdId}/careRecipients/${careRecipientId}/observations/${observationId}/audio.${extension}`;

    await observationRef.update({ status: 'processing', updatedAt: new Date() });
    res.json({ observationId, status: 'processing' });

    processObservationJobLib.processObservationJob({
      householdId,
      careRecipientId,
      observationId,
      uid: req.uid,
      locale,
      storagePath,
    }).catch((err) => {
      // processObservationJob already catches its own errors and writes
      // them to the doc — this is a last-resort net for a bug in that
      // catch handling itself, so a failure can never be fully silent.
      console.error(`unhandled error from processObservationJob (${observationRef.path}):`, err);
    });
  },
);

// F1 · Structured symptom check-in.
//
// Additive endpoint. The voice pipeline above cannot serve this: it starts
// from an audio upload, and a tap-based triage has no audio. Everything
// downstream is reused unchanged — same observations collection, same
// document builder, same daily/weekly rollups, so a check-in shows up in
// the family viewer and the trend charts exactly like a voice log.
//
// Note what is NOT here: no LLM. Urgency comes from lib/symptomTriage.js,
// which is a fixed table (see the reasoning in that file). The client sends
// which symptom and which yes/no answers were tapped; the server recomputes
// the assessment itself rather than trusting a client-sent urgency, since a
// stale or tampered client must not be able to downgrade an emergency.
router.post(
  '/households/:householdId/care-recipients/:careRecipientId/observations/symptom-check',
  requireAuth,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;
    const { symptomKey, answers, note, locale } = req.body || {};

    if (!symptomTriage.SYMPTOMS[symptomKey]) {
      return res.status(400).json({
        error: `Unknown symptomKey. Allowed: ${Object.keys(symptomTriage.SYMPTOMS).join(', ')}`,
      });
    }
    if (!locale) {
      return res.status(400).json({ error: 'locale is required' });
    }

    const assigned = await isCaregiverAssigned({ householdId, careRecipientId, uid: req.uid });
    if (!assigned) {
      return res.status(403).json({ error: 'Not an active caregiver for this care recipient' });
    }

    const assessment = symptomTriage.assessSymptom({ symptomKey, answers });
    const summaryText = symptomTriage.buildSummaryText({ symptomKey, answers, note });

    // The whole point of the feature for the family: they read it in
    // Mandarin. If translation fails the check-in must still be recorded —
    // losing an urgent observation because a translation API blipped would
    // be the worst possible trade.
    let translatedText = null;
    let translationError = null;
    try {
      ({ text: translatedText } = await translateToMandarin({
        text: summaryText,
        sourceLocale: locale,
        projectId: firebase.projectId,
      }));
    } catch (err) {
      translationError = err.message;
      console.error('symptom-check: translation failed, storing untranslated:', err);
    }

    const observationId = timestampId();
    const observationRef = firebase.db.doc(
      `households/${householdId}/careRecipients/${careRecipientId}/observations/${observationId}`,
    );

    const observationDoc = buildObservationDocument({
      uid: req.uid,
      locale,
      transcript: summaryText,
      translatedText: translatedText ?? summaryText,
      inputMode: 'structuredForm',
      extraction: {
        categories: [assessment.category],
        comparisonToUsual: 'worse',
        structuredObservation: {
          summary: summaryText,
          symptomKey,
          urgency: assessment.urgency,
          // Scores stay neutral rather than guessed: this check-in asked
          // about one symptom, so claiming to know how she slept would
          // pollute the trend chart with invented data. The exception is
          // the one the caregiver actually answered about.
          sleepQuality: 0.5,
          appetiteLevel: symptomKey === 'notEating' ? 0.1 : 0.5,
          moodScore: 0.5,
        },
        safetyAssessment: {
          concernLevel: assessment.concernLevel,
          concerns: assessment.concerns,
          recommendFollowUp: assessment.recommendFollowUp,
        },
      },
    });
    if (translationError) observationDoc.processingError = translationError;

    await observationRef.set(observationDoc);

    await Promise.all([
      rollupDailySummary.computeAndSaveDailySummary({
        householdId,
        careRecipientId,
        dateKey: dateKeyOf(new Date()),
      }),
      rollupWeeklySummary.computeAndSaveWeeklySummary({
        householdId,
        careRecipientId,
        weekKey: currentWeekKey(),
        periodStart: currentWeekStartUtc().toISOString(),
      }),
    ]);

    res.json({
      observationId,
      urgency: assessment.urgency,
      concernLevel: assessment.concernLevel,
      concerns: assessment.concerns,
      action: symptomTriage.ACTION_TEXT[assessment.urgency],
      summaryText,
      translatedText,
    });
  },
);

// Dev-only demo log — for filming/showcasing the voice-log trend chart
// without needing a working mic or real speech, so a screen recording
// isn't at the mercy of Speech-to-Text picking up whatever's actually
// said. Skips the whole audio pipeline (upload/STT) and writes a
// plausible-looking observation straight through the same
// buildObservationDocument + rollup path a real voice log uses, so the
// chart updates exactly the way it would for a real log. Randomized
// gently upward of neutral so a short demo clip shows a nice trend
// without looking obviously fake or reusing one canned number.
router.post(
  '/households/:householdId/care-recipients/:careRecipientId/observations/demo-log',
  requireAuth,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;

    const assigned = await isCaregiverAssigned({ householdId, careRecipientId, uid: req.uid });
    if (!assigned) {
      return res.status(403).json({ error: 'Not an active caregiver for this care recipient' });
    }

    const randomInRange = (min, max) => Math.round((min + Math.random() * (max - min)) * 100) / 100;
    const summaryText = 'Demo log for showcase recording — no real observation.';

    const observationId = timestampId();
    const observationRef = firebase.db.doc(
      `households/${householdId}/careRecipients/${careRecipientId}/observations/${observationId}`,
    );

    await observationRef.set(
      buildObservationDocument({
        uid: req.uid,
        locale: 'en',
        transcript: summaryText,
        // No real translation call — this never needs to be read by
        // family, it exists purely to move the demo trend chart, and a
        // live network call here is one more thing that could stall a
        // recording.
        translatedText: '（展示用示範記錄，非真實內容）',
        inputMode: 'text',
        extraction: {
          categories: ['sleep', 'appetite', 'mood'],
          comparisonToUsual: 'better',
          structuredObservation: {
            summary: summaryText,
            sleepQuality: randomInRange(0.65, 0.95),
            appetiteLevel: randomInRange(0.65, 0.95),
            moodScore: randomInRange(0.65, 0.95),
          },
          safetyAssessment: { concernLevel: 'none', concerns: [], recommendFollowUp: false },
        },
      }),
    );

    await Promise.all([
      rollupDailySummary.computeAndSaveDailySummary({
        householdId,
        careRecipientId,
        dateKey: dateKeyOf(new Date()),
      }),
      rollupWeeklySummary.computeAndSaveWeeklySummary({
        householdId,
        careRecipientId,
        weekKey: currentWeekKey(),
        periodStart: currentWeekStartUtc().toISOString(),
      }),
    ]);

    res.json({ observationId });
  },
);

module.exports = router;
