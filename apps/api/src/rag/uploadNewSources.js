// Uploads any RAG source drafts (src/rag/drafts/*.json) that aren't already
// in the ragSources Firestore collection — the local-authoring counterpart
// to editing documents by hand in the Firestore console. Never overwrites
// an existing document (matched by `id`); to update existing content, edit
// it directly in Firestore. Run `node src/rag/ingest.js` afterward to
// chunk + embed anything newly uploaded — this script only uploads.
require('dotenv').config({ quiet: true });

const fs = require('fs');
const path = require('path');

const { db } = require('../firebase');

const DRAFTS_DIR = path.join(__dirname, 'drafts');
const REQUIRED_FIELDS = ['id', 'title', 'publisher', 'url', 'retrievedAt', 'category', 'text'];

function loadDraft(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  const doc = JSON.parse(raw);

  const missing = REQUIRED_FIELDS.filter((field) => !doc[field]);
  if (missing.length > 0) {
    throw new Error(`missing field(s): ${missing.join(', ')}`);
  }

  return doc;
}

async function uploadNewSources() {
  if (!fs.existsSync(DRAFTS_DIR)) {
    console.log(`No drafts directory at ${DRAFTS_DIR} — nothing to upload.`);
    return { uploaded: 0, skipped: 0 };
  }

  const files = fs.readdirSync(DRAFTS_DIR).filter((f) => f.endsWith('.json'));
  if (files.length === 0) {
    console.log(`No .json drafts found in ${DRAFTS_DIR}.`);
    return { uploaded: 0, skipped: 0 };
  }

  let uploaded = 0;
  let skipped = 0;

  for (const file of files) {
    let doc;
    try {
      doc = loadDraft(path.join(DRAFTS_DIR, file));
    } catch (e) {
      console.error(`  skip  ${file}: ${e.message}`);
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
    console.log(`  upload  ${id} (from ${file})`);
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

module.exports = { uploadNewSources };
