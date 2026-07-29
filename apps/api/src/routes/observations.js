const { Router } = require('express');

const firebase = require('../firebase');
const { requireAuth } = require('../middleware/auth');
const { isCaregiverAssigned } = require('../lib/authorizeCaregiver');

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

module.exports = router;
