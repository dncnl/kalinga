# Wire up ragSources (recover lost work + finish it)

Branch: `chore/rag-raw-sources-collection`, cut from `main`.

## What Ralph actually asked for

Ralph (relaying Drei's assignment) asked to unify `ragChunks`/`ragSources`
if they're the same, add a raw-sources collection, and run a script to turn
raw sources into chunks.

## What was actually going on

`ragSources` was never a stray/duplicate collection — it's formally
declared in `packages/kalinga_firestore_package` (schema, rules, contracts,
seed data) as exactly "raw source doc → chunked into ragChunks by
ingest.js". It's just that `apps/api/src/rag/ingest.js` on `main` never
implemented that: it hardcodes the corpus in `src/rag/sources/*.js` and
writes straight to `ragChunks`, bypassing `ragSources` entirely.

Turns out this was already built once — `git log --all -S"ragSources"`
turned up two real commits (`0000010`, `e16a10e`) deep in this repo's
history, reachable from the `polish/home-page-animations` branch lineage,
verified live at the time, but never merged into `main`. That's very
likely also the direct explanation for "ragSources has chunks in it too"
in the Firestore console: real docs from that earlier run, still sitting
there, now orphaned from current `main`'s code path.

This branch ports that lost work forward onto current `main` (which has
since gained `bulkWriter`, PDF/DOCX/GCS ingestion via `ingest-file.js` —
none of that existed when the original commits were written) rather than
reimplementing from scratch, plus finishes the loop `ingest-file.js` was
missing (it wrote straight to `ragChunks`, never persisting the raw doc to
`ragSources`, so a file ingested that way couldn't survive a later
`ingest.js` re-run).

## Changes

- `ingest.js` — reads sources from Firestore `ragSources` (not the local
  JS files) via `fetchSources()`. Added on top of the recovered version:
  deletes now-stale trailing chunks when a re-ingested source got shorter,
  which the original didn't handle.
- `seedSources.js` — new, one-time: upserts `src/rag/sources/*.js` into
  `ragSources` by id. `src/rag/sources/` is seed-only now, not read by
  `ingest.js` anymore.
- `ingest-file.js` — now also upserts the raw doc into `ragSources` (before
  chunking, so a chunk/embed failure doesn't lose the raw text) alongside
  its existing direct `ragChunks` write.
- No schema/rules changes — `ragSources` was already fully declared.

## Status

- [x] Root cause of "ragSources looks like ragChunks" understood (see above)
- [x] `ingest.js`, `seedSources.js`, `ingest-file.js` updated
- [x] Tests: `ingest.test.js` (4), `seedSources.test.js` (1) — full backend
      suite 180/180
- [ ] Run `seedSources.js` + `ingest.js` against real Firestore to backfill
      `ragSources` and regenerate `ragChunks` from it (needs live GCP
      creds — not run from this session)
- [ ] Confirm with Drei/Ralph whether the old orphaned `ragSources` docs
      (if their shape differs from this branch's) should be cleared before
      re-seeding, or just overwritten (seedSources.js upserts by id, so a
      stale doc under a *different* id would survive untouched)
- [ ] PR review, merge to `main`
