# RAG source drafts

Drop new knowledge-base documents here, then run:

```
npm run rag:upload   # uploads any not already in ragSources
npm run rag:ingest    # chunks + embeds everything into ragChunks
```

Two ways to add a document:

## Plain text: a single `.json` file

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

## PDF: a `.pdf` file + a matching `.json` metadata sidecar

Drop `who-fall-prevention.pdf` next to `who-fall-prevention.json` (same base
name, both required). The `.json` holds metadata only — **no `text` field**,
it's extracted from the PDF automatically:

```json
{
  "id": "who-fall-prevention",
  "title": "Fall Prevention in Elderly Patients",
  "publisher": "World Health Organization (WHO)",
  "url": "https://example.org/source.pdf",
  "retrievedAt": "2026-07-30",
  "category": "internationalGuideline"
}
```

Only works for PDFs with real embedded text (anything you can select/copy
in a PDF viewer). Scanned/image-only PDFs have no extractable text and will
be skipped with an error — those need OCR first, which this doesn't do.

## Either way

- `id` becomes the Firestore document id in `ragSources` — pick something short and stable (lowercase, hyphenated). Uploading again with the same `id` is a no-op; to update existing content, edit it directly in Firestore instead.
- `rag:upload` only uploads documents whose `id` doesn't already exist in `ragSources` — it never overwrites one that's already there. Delete the file(s) here once uploaded (not needed again), or leave them; they'll just be skipped on future runs.
- Nothing here is read by the app directly — it's a staging area for this one script.
