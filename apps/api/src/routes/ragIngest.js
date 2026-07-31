const { Router } = require('express');

// Namespace require (not destructured) so tests can mock
// ingestFile.ingestFromGcs directly.
const ingestFile = require('../rag/ingest-file');

const router = Router();

// Called by the Storage-trigger Cloud Function (functions/index.js) when a
// PDF/DOCX/text file lands under ragUploads/ in the app bucket — the
// "drop a PDF, it becomes searchable" path. Not requireAuth (a Storage
// trigger has no caregiver's Firebase ID token to send): a shared secret
// only the function and this server know is the gate instead. Nothing
// about this route is reachable by the mobile app.
router.post('/internal/rag/ingest-gcs', async (req, res) => {
  const configuredSecret = process.env.RAG_INGEST_SECRET;
  if (!configuredSecret) {
    // Fails closed: an unset secret must never be treated as "no auth
    // required", or anyone who finds this URL could make the server
    // download and embed an arbitrary object from the bucket.
    console.error('ragIngest: RAG_INGEST_SECRET is not configured, refusing all requests');
    return res.status(503).json({ error: 'Ingest endpoint is not configured' });
  }
  if (req.get('X-Internal-Secret') !== configuredSecret) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const { bucketName, objectName } = req.body || {};
  if (!bucketName || !objectName) {
    return res.status(400).json({ error: 'bucketName and objectName are required' });
  }

  try {
    const result = await ingestFile.ingestFromGcs({ bucketName, objectName });
    res.json(result);
  } catch (err) {
    console.error(`ragIngest: failed to ingest gs://${bucketName}/${objectName}:`, err);
    res.status(502).json({ error: 'Ingest failed', detail: err.message });
  }
});

module.exports = router;
