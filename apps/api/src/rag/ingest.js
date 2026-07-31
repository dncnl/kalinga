// Chunks + embeds every document in the ragSources Firestore collection and
// writes the results to ragChunks. Deterministic chunk doc ids
// (`${sourceId}-${chunkIndex}`) so re-running this after editing a source
// overwrites its chunks instead of duplicating them; any now-excess trailing
// chunks (source got shorter) are deleted so stale chunks can't outlive the
// text they came from.
//
// ragSources is the actual knowledge base — add/edit documents there
// (Firestore console, seedSources.js, or ingest-file.js), not in code.
// sources/*.js is only the original seed content; it is not read here.
//
// This is shared reference knowledge, not household data, so it lives in
// its own top-level collection rather than under households/{id}/... like
// the care-record schema (packages/kalinga_firestore_package).
//
// Run manually for now: `node src/rag/ingest.js` (from apps/api). No
// scheduler/trigger wired up — re-run it whenever ragSources changes.
require('dotenv').config({ quiet: true });

const { FieldValue } = require('firebase-admin/firestore');
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

    // Existing chunk count for this source, so a source that got shorter on
    // re-ingest doesn't leave its old tail chunks retrievable forever.
    const existingSnap = await db.collection('ragChunks').where('sourceId', '==', source.id).get();
    const staleDocs = existingSnap.docs.filter((doc) => doc.data().chunkIndex >= chunks.length);

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
    staleDocs.forEach((doc) => bulkWriter.delete(doc.ref));
    await bulkWriter.close();

    console.log(`  ${source.id}: ${chunks.length} chunks${staleDocs.length ? ` (removed ${staleDocs.length} stale)` : ''}`);
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

module.exports = { ingestAll, fetchSources };
