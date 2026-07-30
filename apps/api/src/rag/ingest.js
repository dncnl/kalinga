// Chunks + embeds every document in the ragSources Firestore collection and
// writes the results to ragChunks. Deterministic chunk doc ids
// (`${sourceId}-${chunkIndex}`) so re-running this after editing a source
// overwrites its chunks instead of duplicating them.
//
// ragSources is the actual knowledge base — add/edit documents there
// (Firestore console, or a future admin UI), not in code. sources/*.js is
// only the original seed content now (see seedSources.js); it is not read
// by this script.
//
// This is shared reference knowledge, not household data, so it lives in
// its own top-level collection rather than under households/{id}/... like
// the care-record schema (packages/kalinga_firestore_package).
//
// Run manually for now: `node src/rag/ingest.js` (from apps/api). No
// scheduler/trigger wired up — re-run it whenever ragSources changes.
require('dotenv').config({ quiet: true });

const { db } = require('../firebase');
const { chunkText } = require('./chunk');
const { embedBatch } = require('./embeddings');

async function fetchSources() {
  const snap = await db.collection('ragSources').get();
  return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

async function ingestAll() {
  const sources = await fetchSources();
  if (sources.length === 0) {
    console.log('ragSources is empty — run seedSources.js first, or add documents to ragSources in Firestore.');
    return;
  }

  let totalChunks = 0;

  for (const source of sources) {
    const chunks = chunkText(source.text);
    const embeddings = await embedBatch(chunks);

    const batch = db.batch();
    chunks.forEach((chunkContent, i) => {
      const ref = db.collection('ragChunks').doc(`${source.id}-${i}`);
      batch.set(ref, {
        sourceId: source.id,
        sourceTitle: source.title,
        sourcePublisher: source.publisher,
        sourceUrl: source.url,
        sourceRetrievedAt: source.retrievedAt,
        sourceCategory: source.category,
        chunkIndex: i,
        text: chunkContent,
        embedding: embeddings[i],
      });
    });
    await batch.commit();

    console.log(`  ${source.id}: ${chunks.length} chunks`);
    totalChunks += chunks.length;
  }

  console.log(`Ingested ${sources.length} sources, ${totalChunks} chunks total.`);
}

if (require.main === module) {
  ingestAll()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('Ingest failed:', err);
      process.exit(1);
    });
}

module.exports = { ingestAll };
