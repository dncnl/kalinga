// Uploads any RAG source drafts in src/rag/drafts/ that aren't already in
// the ragSources Firestore collection — the local-authoring counterpart to
// editing documents by hand in the Firestore console. Never overwrites an
// existing document (matched by `id`); to update existing content, edit it
// directly in Firestore. Run `node src/rag/ingest.js` afterward to chunk +
// embed anything newly uploaded — this script only uploads.
//
// Two draft shapes are supported:
//   - foo.json, standalone: full document including `text` (see drafts/README.md).
//   - foo.pdf + foo.json, paired: foo.json holds metadata only (id, title,
//     publisher, url, retrievedAt, category — no `text` required), and the
//     PDF's extracted text becomes the document's `text`.
require('dotenv').config({ quiet: true });

const fs = require('fs');
const path = require('path');

const { db } = require('../firebase');

const DRAFTS_DIR = path.join(__dirname, 'drafts');
const METADATA_FIELDS = ['id', 'title', 'publisher', 'url', 'retrievedAt', 'category'];

function loadMetadata(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  const doc = JSON.parse(raw);

  const missing = METADATA_FIELDS.filter((field) => !doc[field]);
  if (missing.length > 0) {
    throw new Error(`missing field(s): ${missing.join(', ')}`);
  }

  return doc;
}

async function extractPdfText(filePath) {
  // Lazy import: pdf-parse is only needed by this one path, no reason to
  // pay its startup cost for a plain-text-only upload run.
  const { PDFParse } = await import('pdf-parse');
  const data = fs.readFileSync(filePath);
  const parser = new PDFParse({ data });
  try {
    const result = await parser.getText();
    // pdf-parse inserts "-- N of M --" page-separator lines into the text
    // itself (confirmed by inspection, undocumented) — strip them so they
    // don't pollute what gets embedded/cited as real document content.
    return result.text
      .replace(/^--\s*\d+\s+of\s+\d+\s*--$/gm, '')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  } finally {
    await parser.destroy();
  }
}

async function collectDrafts() {
  const files = fs.readdirSync(DRAFTS_DIR);
  const pdfBaseNames = new Set(
    files.filter((f) => f.endsWith('.pdf')).map((f) => f.slice(0, -'.pdf'.length)),
  );

  const drafts = [];

  for (const file of files) {
    if (file.endsWith('.pdf')) {
      const base = file.slice(0, -'.pdf'.length);
      const sidecar = `${base}.json`;
      if (!files.includes(sidecar)) {
        console.error(`  skip  ${file}: no matching ${sidecar} metadata file`);
        continue;
      }
      drafts.push({ kind: 'pdf', pdfFile: file, metadataFile: sidecar });
      continue;
    }

    if (file.endsWith('.json') && !pdfBaseNames.has(file.slice(0, -'.json'.length))) {
      // A standalone .json draft — but NOT one that's actually a PDF's
      // metadata sidecar (those are handled above, skip them here so
      // they aren't processed twice).
      drafts.push({ kind: 'json', jsonFile: file });
    }
  }

  return drafts;
}

async function loadDraftDocument(draft) {
  if (draft.kind === 'json') {
    const raw = fs.readFileSync(path.join(DRAFTS_DIR, draft.jsonFile), 'utf8');
    const doc = JSON.parse(raw);
    const missing = [...METADATA_FIELDS, 'text'].filter((field) => !doc[field]);
    if (missing.length > 0) {
      throw new Error(`missing field(s): ${missing.join(', ')}`);
    }
    return { doc, sourceLabel: draft.jsonFile };
  }

  const metadata = loadMetadata(path.join(DRAFTS_DIR, draft.metadataFile));
  // Via module.exports (not the bare local name) so tests can mock PDF
  // extraction without exercising the real pdf-parse import.
  const text = await module.exports.extractPdfText(path.join(DRAFTS_DIR, draft.pdfFile));
  if (!text) {
    throw new Error(`no extractable text in ${draft.pdfFile} (scanned/image-only PDFs aren't supported)`);
  }
  return { doc: { ...metadata, text }, sourceLabel: draft.pdfFile };
}

async function uploadNewSources() {
  if (!fs.existsSync(DRAFTS_DIR)) {
    console.log(`No drafts directory at ${DRAFTS_DIR} — nothing to upload.`);
    return { uploaded: 0, skipped: 0 };
  }

  const drafts = await collectDrafts();
  if (drafts.length === 0) {
    console.log(`No drafts found in ${DRAFTS_DIR}.`);
    return { uploaded: 0, skipped: 0 };
  }

  let uploaded = 0;
  let skipped = 0;

  for (const draft of drafts) {
    let doc, sourceLabel;
    try {
      ({ doc, sourceLabel } = await loadDraftDocument(draft));
    } catch (e) {
      console.error(`  skip  ${draft.pdfFile || draft.jsonFile}: ${e.message}`);
      continue;
    }

    const { id, ...fields } = doc;
    const ref = db.collection('ragSources').doc(id);
    const existing = await ref.get();

    if (existing.exists) {
      console.log(`  skip    ${id} (already in ragSources)`);
      skipped += 1;
      continue;
    }

    await ref.set({ ...fields, updatedAt: new Date() });
    console.log(`  upload  ${id} (from ${sourceLabel})`);
    uploaded += 1;
  }

  console.log(`\n${uploaded} uploaded, ${skipped} already present.`);
  if (uploaded > 0) {
    console.log('Run `node src/rag/ingest.js` next to chunk + embed the new source(s).');
  }

  return { uploaded, skipped };
}

if (require.main === module) {
  uploadNewSources()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('Upload failed:', err);
      process.exit(1);
    });
}

module.exports = { uploadNewSources, extractPdfText, collectDrafts };
