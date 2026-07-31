# RAG auto-ingest Cloud Function

Drop a PDF/DOCX/text file into the app's default Storage bucket under
`ragUploads/`, and `ingestRagUpload` (`index.js`) fires automatically,
calls apps/api's `POST /internal/rag/ingest-gcs`, and the document becomes
searchable — no CLI command needed. See `index.js`'s header comment for why
this function is deliberately thin (it doesn't parse/chunk/embed anything
itself — apps/api's existing `ingestFromGcs()` does that, same code path as
the CLI `node ingest-file.js`).

## One-time setup

1. Pick (or generate) a secret and set it on **both** sides — they must
   match exactly:
   ```
   firebase functions:secrets:set RAG_INGEST_SECRET
   ```
   and set `RAG_INGEST_SECRET` in apps/api's own environment (Cloud Run
   env var / `.env`), same value.

2. Copy `.env.example` to `.env.<firebase-project-id>` (e.g.
   `.env.kalinga-bc97f`) and fill in apps/api's actual deployed base URL:
   ```
   API_BASE_URL=https://<your apps/api Cloud Run URL>
   ```
   (2nd-gen Cloud Functions load non-secret params from this file
   automatically — see Firebase's "Configure your environment" docs if the
   naming convention has moved on since this was written.)

3. Install dependencies and deploy:
   ```
   cd functions
   npm install
   npm run deploy
   ```
   First deploy will prompt to enable the Cloud Functions and Eventarc
   APIs if they aren't already — accept. Requires the Blaze (pay-as-you-go)
   plan, which this project is already on.

## Verifying it worked

Upload a test file (`gsutil cp test.pdf gs://<bucket>/ragUploads/test.pdf`,
or drag it into that path in the Firebase console's Storage tab), then
check:

- Cloud Functions logs (`firebase functions:log` or the console) for
  `ingestRagUpload: gs://... -> test (<N> chunks)`.
- A new `ragSources/test` document and matching `ragChunks/test-0`, etc.,
  in Firestore.
- `/rag/ask` (or the mobile Ask page) returning something grounded in the
  new document's content.

## Why ragUploads/ specifically

`storage.rules`' catch-all already denies client read/write on every path
outside `/public/` (see that file), so this prefix needs no rule changes —
only someone with direct bucket access (Firebase console, `gsutil`, a
service account) can drop a file here. This is intentionally an
admin/back-office path, not something the caregiver-facing app writes to.
