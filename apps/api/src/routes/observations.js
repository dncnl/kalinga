const { Router } = require('express');

const firebase = require('../firebase');
const { requireAuth } = require('../middleware/auth');
const { isCaregiverAssigned } = require('../lib/authorizeCaregiver');
const { STT_LANGUAGE_CODES } = require('../lib/transcribe');
// Namespace require (not destructured) so tests can mock
// processObservationJob.processObservationJob directly.
const processObservationJobLib = require('../lib/processObservationJob');
const { timestampId } = require('../lib/readableId');

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
    const [uploadUrl] = await firebase
      .getBucket()
      .file(storagePath)
      .getSignedUrl({ version: 'v4', action: 'write', expires: expiresAt, contentType });

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

module.exports = router;
