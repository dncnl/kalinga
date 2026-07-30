# RAG source drafts

Drop new knowledge-base documents here as `.json` files, then run:

```
node src/rag/uploadNewSources.js   # uploads any not already in ragSources
node src/rag/ingest.js             # chunks + embeds everything into ragChunks
```

Each file must be a single JSON object:

```json
{
  "id": "who-fall-prevention",
  "title": "Fall Prevention in Elderly Patients",
  "publisher": "World Health Organization (WHO)",
  "url": "https://example.org/source",
  "retrievedAt": "2026-07-30",
  "category": "internationalGuideline",
  "text": "The actual reference content goes here — plain text, as much as you want. It gets automatically split into overlapping chunks before embedding, so paste in the real source material, not a summary."
}
```

- `id` becomes the Firestore document id in `ragSources` — pick something short and stable (lowercase, hyphenated). Uploading again with the same `id` is a no-op (see below); to update existing content, edit it directly in Firestore instead.
- `uploadNewSources.js` only uploads documents whose `id` doesn't already exist in `ragSources` — it will never overwrite one that's already there. Delete the `.json` file here once it's uploaded (it isn't needed again), or leave it; it'll just be skipped on future runs.
- Nothing here is read by the app directly — it's a staging area for this one script.
