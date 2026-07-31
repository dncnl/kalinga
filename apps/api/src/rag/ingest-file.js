// Ingests a single document: writes the raw text into ragSources (the same
// collection ingest.js reads from, so a later full re-ingest picks this
// document up too — see ingest.js), then chunks + embeds it straight into
// ragChunks so it's searchable immediately without a second manual step.
// Two ways to point it at a document:
//   - Local file:  node ingest-file.js ./doc.pdf --title=... --publisher=... --url=... [--category=...] [--id=...]
//   - GCS object (Cloud Run Job): set BUCKET_NAME / OBJECT_NAME env vars;
//     title/publisher/url/category/id are read from the object's custom
//     metadata instead of CLI flags.
// .pdf, .docx, and plain text/Markdown are all supported (see extractText) —
// dispatched by file extension.
// Same deterministic `${sourceId}-${chunkIndex}` doc ids as ingest.js, so
// re-running this against an updated file overwrites its old chunks.
require('dotenv').config({ quiet: true });

const path = require('path');
const { db } = require('../firebase');
const { chunkText } = require('./chunk');
const { embedBatch } = require('./embeddings');

function slugify(name) {
  return name.replace(/\.[^.]+$/, '').replace(/[^a-z0-9-]+/gi, '-').toLowerCase();
}

// Raw bytes only tell you the document's content directly for plain
// text/Markdown — PDF and DOCX are binary/structured formats that need a
// real parser to get text out of. Extension-based dispatch is good enough
// here since these are hand-picked reference documents, not untrusted
// user uploads with spoofable names.
async function extractText(buffer, filename) {
  const ext = path.extname(filename).toLowerCase();

  if (ext === '.pdf') {
    const pdfParse = require('pdf-parse');
    const { text } = await pdfParse(buffer);
    return text;
  }

  if (ext === '.docx') {
    const mammoth = require('mammoth');
    const { value } = await mammoth.extractRawText({ buffer });
    return value;
  }

  return buffer.toString('utf8');
}

async function loadFromGcs(bucketName, objectName) {
  // firebase-admin/storage's getStorage() failed to attach ADC credentials
  // to raw object downloads in practice (requests went out as anonymous
  // callers). @google-cloud/storage directly, with the same
  // googleAuthOptions() convention already used for Speech/Translate in
  // ../firebase.js, is the reliable path for non-Firebase-bucket access.
  const { Storage } = require('@google-cloud/storage');
  const { googleAuthOptions } = require('../firebase');
  const file = new Storage(googleAuthOptions()).bucket(bucketName).file(objectName);
  const [buffer] = await file.download();
  const [meta] = await file.getMetadata();
  const custom = meta.metadata || {};

  return {
    id: custom.id || slugify(objectName),
    title: custom.title || objectName,
    publisher: custom.publisher || 'unknown',
    url: custom.url || '',
    category: custom.category || 'uploaded',
    retrievedAt: meta.timeCreated,
    text: await extractText(buffer, objectName),
  };
}

async function loadFromLocalFile() {
  const [filePath, ...flagArgs] = process.argv.slice(2);
  if (!filePath) {
    throw new Error(
      'Usage: node ingest-file.js <path> --title=... --publisher=... --url=... [--category=...] [--id=...]',
    );
  }

  const flags = Object.fromEntries(flagArgs.map((arg) => arg.replace(/^--/, '').split('=')));
  const fs = require('fs');

  return {
    id: flags.id || slugify(path.basename(filePath)),
    title: flags.title || path.basename(filePath),
    publisher: flags.publisher || 'unknown',
    url: flags.url || '',
    category: flags.category || 'uploaded',
    retrievedAt: new Date().toISOString(),
    text: await extractText(fs.readFileSync(filePath), filePath),
  };
}

async function loadDocument() {
  const { BUCKET_NAME, OBJECT_NAME } = process.env;
  if (BUCKET_NAME && OBJECT_NAME) return loadFromGcs(BUCKET_NAME, OBJECT_NAME);
  return loadFromLocalFile();
}

// The actual ingest: persist the raw doc, then chunk + embed it. Shared by
// the CLI entrypoint below and by routes/ragIngest.js (the internal route
// the Storage-trigger Cloud Function calls — see functions/index.js) so
// there's exactly one place that knows how to turn a `source` into
// ragSources + ragChunks documents.
async function ingestSource(source) {
  // Persisted first and separately from the chunking below: if chunking or
  // embedding fails partway, the raw document is still saved and a plain
  // re-run of ingest.js (reading from ragSources) can pick it up later
  // instead of losing the whole upload.
  await db.collection('ragSources').doc(source.id).set({
    title: source.title,
    publisher: source.publisher,
    url: source.url,
    retrievedAt: source.retrievedAt,
    category: source.category,
    text: source.text,
    updatedAt: new Date(),
  });

  const chunks = chunkText(source.text);
  const embeddings = await embedBatch(chunks);

  const { FieldValue } = require('firebase-admin/firestore');
  // BulkWriter, not batch() — batch() hard-caps at 500 writes per commit,
  // which a large source document's chunk count can easily exceed.
  // BulkWriter handles chunking/rate-limiting/retries internally.
  const bulkWriter = db.bulkWriter();
  chunks.forEach((chunkContent, i) => {
    const ref = db.collection('ragChunks').doc(`${source.id}-${i}`);
    bulkWriter.set(ref, {
      sourceId: source.id,
      sourceTitle: source.title,
      sourcePublisher: source.publisher,
      sourceUrl: source.url,
      sourceRetrievedAt: source.retrievedAt,
      sourceCategory: source.category,
      chunkIndex: i,
      text: chunkContent,
      embedding: FieldValue.vector(embeddings[i]),
    });
  });
  await bulkWriter.close();

  return { sourceId: source.id, chunkCount: chunks.length };
}

// Entry point for the Storage-trigger route (routes/ragIngest.js): given a
// bucket + object name it already has from the trigger event, load and
// ingest that one object. Kept separate from ingestFile()/loadDocument()
// below, which read BUCKET_NAME/OBJECT_NAME from the environment for the
// CLI/Cloud Run Job path instead of taking explicit arguments.
async function ingestFromGcs({ bucketName, objectName }) {
  const source = await loadFromGcs(bucketName, objectName);
  return ingestSource(source);
}

async function ingestFile() {
  const source = await loadDocument();
  const { sourceId, chunkCount } = await ingestSource(source);
  console.log(`Ingested ${sourceId}: ${chunkCount} chunks`);
}

if (require.main === module) {
  ingestFile()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('ingest-file failed:', err);
      process.exit(1); // non-zero exit = Cloud Run Job execution marked failed
    });
}

module.exports = { ingestFile, ingestFromGcs, ingestSource };
