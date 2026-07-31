// One-time migration: uploads the original hardcoded sources/*.js corpus
// into the ragSources Firestore collection, which is what ingest.js reads
// from (see ingest.js). Run once to bootstrap a fresh project; after that,
// add/edit knowledge base documents directly in ragSources (Firestore
// console, or ingest-file.js for a new document) instead of editing code.
// Safe to re-run — upserts by sourceId, never duplicates.
require('dotenv').config({ quiet: true });

const { db } = require('../firebase');
const sources = require('./sources');

async function seedSources() {
  const batch = db.batch();
  for (const source of sources) {
    const ref = db.collection('ragSources').doc(source.id);
    batch.set(ref, {
      title: source.title,
      publisher: source.publisher,
      url: source.url,
      retrievedAt: source.retrievedAt,
      category: source.category,
      text: source.text,
      updatedAt: new Date(),
    });
  }
  await batch.commit();
  console.log(`Seeded ${sources.length} documents into ragSources.`);
}

if (require.main === module) {
  seedSources()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('Seed failed:', err);
      process.exit(1);
    });
}

module.exports = { seedSources };
