// Auto-ingest trigger: drop a PDF/DOCX/text file under ragUploads/ in the
// app's default Storage bucket, and it becomes searchable in the RAG
// knowledge base without anyone running a CLI command.
//
// Deliberately thin — this function does NOT parse the file, chunk it, or
// call the embedding model itself. It just tells apps/api "a new object
// landed at gs://bucket/object", and apps/api's existing ingestFromGcs()
// (apps/api/src/rag/ingest-file.js) does the real work: same code path as
// the CLI (`node ingest-file.js`) and the Cloud Run Job mode, so there is
// exactly one implementation of "how to turn a source into ragSources +
// ragChunks documents" rather than a second copy living in here.
//
// Deploy: from this directory, `npm install` then `npm run deploy` (or
// `firebase deploy --only functions` from the project root). Requires the
// Blaze plan (already in use) and the Eventarc/Cloud Functions APIs
// enabled, which onObjectFinalized's first deploy prompts for.
//
// Config (set once via `firebase functions:secrets:set RAG_INGEST_SECRET`
// and `firebase functions:config` / .env.<project-id>, see README below):
//   API_BASE_URL       apps/api's base URL, e.g. https://kalinga-api-xyz.run.app
//   RAG_INGEST_SECRET  shared secret; must match apps/api's env var of the
//                      same name (checked in apps/api/src/routes/ragIngest.js)

const { onObjectFinalized } = require('firebase-functions/v2/storage');
const { defineSecret, defineString } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const fetch = require('node-fetch');

const ragIngestSecret = defineSecret('RAG_INGEST_SECRET');
const apiBaseUrl = defineString('API_BASE_URL');

const UPLOAD_PREFIX = 'ragUploads/';
const SUPPORTED_EXTENSIONS = ['.pdf', '.docx', '.txt', '.md'];

exports.ingestRagUpload = onObjectFinalized(
  { secrets: [ragIngestSecret], region: 'us-central1', retry: true },
  async (event) => {
    const { bucket, name: objectName, contentType } = event.data;

    if (!objectName.startsWith(UPLOAD_PREFIX)) return; // not a RAG upload
    if (!SUPPORTED_EXTENSIONS.some((ext) => objectName.toLowerCase().endsWith(ext))) {
      logger.warn(`ingestRagUpload: skipping ${objectName} (${contentType}) — unsupported extension`);
      return;
    }

    const res = await fetch(`${apiBaseUrl.value()}/internal/rag/ingest-gcs`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Internal-Secret': ragIngestSecret.value(),
      },
      body: JSON.stringify({ bucketName: bucket, objectName }),
    });

    if (!res.ok) {
      const detail = await res.text().catch(() => '');
      // Throwing (rather than just logging) surfaces the failure in the
      // Functions error rate and, with `retry: true` above, gets Eventarc
      // to retry the event a few times — a knowledge-base document that
      // silently failed to ingest is a support headache nobody would
      // otherwise notice.
      throw new Error(`ingest-gcs returned ${res.status}: ${detail}`);
    }

    const body = await res.json();
    logger.info(`ingestRagUpload: gs://${bucket}/${objectName} -> ${body.sourceId} (${body.chunkCount} chunks)`);
  },
);
