# Wire up ragSources + auto-ingest Storage trigger

Branch: `feature/rag-auto-ingest-storage-trigger`, stacked on
`chore/rag-raw-sources-collection` (cut from `main`). Merge that branch
first, then this one.

## Part 1 — ragSources (see chore/rag-raw-sources-collection's own history)

`ragSources` was already fully declared in the schema package as the raw
source doc → chunked into `ragChunks` collection, but `ingest.js` never
read from it. Recovered + ported forward two real commits (`0000010`,
`e16a10e`) found deep in this repo's history that had already fixed this
once, live-verified, but never merged to `main`. `ingest.js` now reads
`ragSources`; `seedSources.js` backfills it from the local corpus;
`ingest-file.js` persists the raw doc there too.

## Part 2 — this branch: drop a PDF, it auto-ingests

Ralph asked for a place to drop PDFs directly and have them automatically
become `ragChunks`. Nothing in the repo auto-triggered ingestion — closest
was `ingest-file.js`'s GCS mode, but that only runs when someone invokes it
manually or as a one-off Cloud Run Job.

Design (kept deliberately thin — one implementation of "how to ingest",
not two):

- `apps/api/src/rag/ingest-file.js` — refactored into `ingestSource()`
  (the actual write-to-ragSources-then-chunk logic, unchanged behavior) +
  `ingestFromGcs({ bucketName, objectName })` (new: same thing, explicit
  args instead of reading `BUCKET_NAME`/`OBJECT_NAME` from `process.env`,
  for a caller that already has those from elsewhere).
- `apps/api/src/routes/ragIngest.js` — new internal route,
  `POST /internal/rag/ingest-gcs`. Gated by a shared secret
  (`RAG_INGEST_SECRET`) header, not `requireAuth` — a Storage-triggered
  Cloud Function has no caregiver ID token to send. Fails closed if the
  secret isn't configured server-side.
- `packages/kalinga_firestore_package/functions/` — new Cloud Function
  (`ingestRagUpload`, 2nd gen `onObjectFinalized` Storage trigger),
  filtered to objects under `ragUploads/` in the app's default bucket. It
  does NOT parse/chunk/embed anything itself — it just calls apps/api's new
  route with the bucket/object name. See `functions/README.md` for the
  one-time setup (shared secret, `API_BASE_URL`) and deploy steps.
- No `storage.rules` changes needed — the existing catch-all already denies
  client read/write outside `/public/`, so `ragUploads/` is admin-only by
  default (console / `gsutil` / a service account).

## Status

- [x] `ingestFromGcs()` + `/internal/rag/ingest-gcs` route + Cloud Function
      written
- [x] Tests: `ingest-file.test.js`, `rag-ingest.test.js` — full backend
      suite 186/186
- [x] Schema package `validate` still passes with the new `functions`
      block in `firebase.json`
- [ ] **Not deployed, not fire-tested** — needs `firebase deploy --only
      functions` and a real object upload to verify end to end; can't be
      done from this session (no `gcloud`, no way to trigger a live GCS
      event). See `functions/README.md`'s "Verifying it worked".
- [ ] Set `RAG_INGEST_SECRET` (same value) on both apps/api's deployment
      and the function's secret config
- [ ] PR review, merge to `main` (after chore/rag-raw-sources-collection)
