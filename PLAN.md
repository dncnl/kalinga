# Feature: RAG — Firestore native vector search + document ingestion pipeline

Replaces the RAG pipeline's brute-force, in-memory cosine-similarity
retrieval with Firestore's native vector search, and adds a real way to
grow the knowledge base beyond the original 5 hand-authored sources:
upload a document to a Cloud Storage bucket, run a Cloud Run Job against
it, and it's chunked, embedded, and searchable via `/rag/ask`.

## Why this replaced the brute-force retrieval

`retrieve.js` used to load the *entire* `ragChunks` collection into memory
on every query and rank chunks by cosine similarity computed in
JavaScript — explicitly called out in the old code as a stopgap. That
stopped being reasonable once real reference documents (14 clinical
guidelines/research papers on dementia, medication safety, hypertension,
CKD, pneumonia, multimorbidity, plus a 500KB Taiwan nursing-care policy
document) were added to the corpus.

## Design decisions made this session

1. **Firestore `findNearest`, not a dedicated vector DB.** Embeddings
   (local, `Xenova/all-MiniLM-L6-v2`, 384-dim, no API key) are now stored
   as native Firestore `VectorValue`s (`FieldValue.vector()`) instead of
   plain arrays, queried via `collection.findNearest({ distanceMeasure:
   'COSINE', ... })` against a vector index (added to
   `packages/kalinga_firestore_package/firestore.indexes.json`). Rejected
   Vertex AI Search / a dedicated vector DB as overkill for a corpus this
   size and inconsistent with "keep everything in Firestore" — see the
   conversation history for the full tradeoff discussion.
2. **`BulkWriter`, not `batch()`, for chunk writes.** `batch()` hard-caps
   at 500 writes; a single large source document can produce more than
   500 chunks (the 500KB Taiwan nursing-care doc does). Both `ingest.js`
   and the new `ingest-file.js` now use `db.bulkWriter()`.
3. **New `ingest-file.js`, separate from `ingest.js`.** `ingest.js` stays
   as the bulk "seed the 5 hand-authored sources" script. `ingest-file.js`
   ingests one document at a time and has two modes: a local-file mode
   (CLI args, for dev/testing with zero GCP calls) and a GCS mode (reads
   `BUCKET_NAME`/`OBJECT_NAME` env vars, metadata from the object's custom
   metadata) — the mode a deployed Cloud Run Job actually uses.
4. **PDF/DOCX support**, via `pdf-parse` (pinned to the stable 1.x
   function-based API — 2.x ships a very different class-based API) and
   `mammoth`, dispatched by file extension in `extractText()`.
5. **Cloud Run Job, not a Function**, for ingestion — Jobs fit
   "run to completion, no HTTP request/response" far better, and give
   headroom (1Gi memory, 30-minute task timeout) for loading the
   embedding model and processing large documents.
6. **Manual trigger for now (Stage 1); Storage-event auto-trigger is
   Stage 2**, deliberately deferred to a separate branch so each new GCP
   concept (Cloud Run Jobs/IAM first, eventing later) lands on its own.

## Bugs found and fixed this session (all pre-existing or newly introduced,
now resolved)

1. **Dead dependency blocking fresh installs**: `package.json` declared
   `@dataconnect/admin-generated` as a `file:` dependency pointing at a
   directory that doesn't exist in this checkout, and nothing in
   `apps/api/src` actually imports it. Any fresh `npm install` (Cloud
   Build, CI, a new clone) would fail on it. Removed.
2. **Missing `apps/api/.gcloudignore`**: `gcloud run jobs deploy --source`
   had no ignore rules for that subdirectory (the root `.gitignore`'s
   `node_modules/` rule doesn't apply to a `--source` deploy from a
   subdirectory), so it tried to upload the entire local `node_modules` —
   including a broken symlink from (1) — and crashed. Added.
3. **`firebase-admin/storage`'s `getStorage()` silently sent
   unauthenticated ("anonymous caller") requests** when downloading
   objects from the new RAG bucket, even with valid credentials elsewhere
   in the same process (Firestore calls worked fine). Switched
   `ingest-file.js`'s GCS download to `@google-cloud/storage` directly
   with `googleAuthOptions()` — the same pattern `firebase.js` already
   uses for Speech/Translate.
4. **Every single Cloud Run Job execution failed silently** (exit code 1,
   zero captured stdout/stderr) until diagnosed via a local Docker
   reproduction: `--command=node --args=...` bypasses the Buildpacks
   image's launcher entirely, so `node` isn't on the container's static
   PATH (`exec: "node": executable file not found in $PATH`). Fixed by
   routing through `/cnb/lifecycle/launcher` instead:
   `--command=/cnb/lifecycle/launcher --args=node,src/rag/ingest-file.js`.

## What's done vs. deferred to later branches

Done, this branch: Firestore vector search migration, `ingest-file.js`,
the Cloud Run Job (`rag-ingest-job`, `us-central1`), a dedicated bucket
(`kalinga-bc97f-rag-sources`) and service account
(`rag-ingest-job@kalinga-bc97f.iam.gserviceaccount.com`), and all 14 new
reference documents ingested and confirmed retrievable.

**Not built here, deliberately deferred:**
- Stage 2: a Cloud Storage → Eventarc → Cloud Run Job trigger, so upload
  alone (no manual `gcloud run jobs execute`) is enough.
- Switching `llmClient.js`'s default provider from OpenRouter to Vertex
  AI/Gemini (both for `/rag/ask` and `extractObservation.js`) — separate
  branch, since it's an unrelated concern from retrieval/ingestion.

## Progress

- [x] `retrieve.js` / `ingest.js`: Firestore `findNearest` + `BulkWriter`.
- [x] `ingest-file.js`: local-file + GCS modes, PDF/DOCX/text extraction.
- [x] Cloud Run Job deployed and working (bucket + IAM + launcher fix).
- [x] 14 real reference documents ingested and spot-verified in Firestore
      (correct metadata, real `VectorValue` embeddings).
- [x] `retrieve.test.js` rewritten for `findNearest` mocks; full test
      suite otherwise unaffected (130/133 passing — the 3 failures are
      pre-existing OpenRouter rate-limit flakes in
      `extractObservation`/`observations-process`, unrelated to this
      branch).
- [ ] Stage 2 (Eventarc auto-trigger) — separate branch.
- [ ] Vertex AI/Gemini LLM provider switch — separate branch.
