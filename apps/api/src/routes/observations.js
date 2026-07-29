const { Router } = require('express');

const firebase = require('../firebase');
const { requireAuth } = require('../middleware/auth');
const { isCaregiverAssigned } = require('../lib/authorizeCaregiver');
const { transcribeAudio, STT_LANGUAGE_CODES } = require('../lib/transcribe');
const { translateToMandarin } = require('../lib/translate');
const { extractObservation } = require('../lib/extractObservation');
const { buildObservationDocument } = require('../lib/buildObservationDocument');

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
      .doc().id;

    const storagePath = `households/${householdId}/careRecipients/${careRecipientId}/observations/${observationId}/audio.${extension}`;

    const expiresAt = Date.now() + UPLOAD_URL_TTL_MS;
    const [uploadUrl] = await firebase
      .getBucket()
      .file(storagePath)
      .getSignedUrl({ version: 'v4', action: 'write', expires: expiresAt, contentType });

    res.json({ observationId, uploadUrl, storagePath, expiresAt });
  },
);

// Caregiver's phone calls this once the raw PUT to the signed URL finishes.
// Synchronous for now (simplest to build/test); revisit as a Storage-triggered
// background job if processing time becomes a problem for the UI.
router.post(
  '/households/:householdId/care-recipients/:careRecipientId/observations/:observationId/process',
  requireAuth,
  async (req, res) => {
    const { householdId, careRecipientId, observationId } = req.params;
    const { storagePath, locale } = req.body || {};

    if (!storagePath || !locale) {
      return res.status(400).json({ error: 'storagePath and locale are required' });
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

    try {
      const bucketName = firebase.getBucket().name;
      const gcsUri = `gs://${bucketName}/${storagePath}`;

      const { text: transcript } = await transcribeAudio({ gcsUri, locale });
      const { text: translatedText } = await translateToMandarin({
        text: transcript,
        sourceLocale: locale,
        projectId: firebase.app.options.projectId,
      });
      const extraction = await extractObservation({ transcript });

      const observationDoc = buildObservationDocument({
        uid: req.uid,
        locale,
        transcript,
        translatedText,
        extraction,
      });
      observationDoc.originalAudioAssetId = storagePath;

      await firebase.db
        .doc(`households/${householdId}/careRecipients/${careRecipientId}/observations/${observationId}`)
        .set(observationDoc);

      res.json({ observationId, transcript, translatedText, ...extraction });
    } catch (err) {
      console.error('observation processing failed:', err);
      res.status(502).json({ error: 'Processing failed', detail: err.message });
    }
  },
);

module.exports = router;
