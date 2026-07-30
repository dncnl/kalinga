// Chunks + embeds every document in src/rag/sources/ and writes them to the
// ragChunks Firestore collection. Deterministic chunk doc ids
// (`${sourceId}-${chunkIndex}`) so re-running this after editing a source
// overwrites its chunks instead of duplicating them.
//
// This is shared reference knowledge, not household data, so it lives in
// its own top-level collection rather than under households/{id}/... like
// the care-record schema (packages/kalinga_firestore_package).
//
// Run manually for now: `node src/rag/ingest.js` (from apps/api). No
// scheduler/trigger wired up — re-run it whenever sources/ changes.
require('dotenv').config({ quiet: true });

const { db } = require('../firebase');
const { chunkText } = require('./chunk');
const { embedBatch } = require('./embeddings');
const sources = require('./sources');

async function ingestAll() {
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
