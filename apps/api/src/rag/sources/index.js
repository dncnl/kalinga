// Seed corpus. Each entry is a real, cited public source (Taiwan health
// authority, WHO, or peer-reviewed research) — see individual files for URLs
// and retrieval dates. To add more: drop a new module here in the same
// shape ({ id, title, publisher, url, retrievedAt, category, text }) and
// list it below, then re-run ingest (`node src/rag/ingest.js`).
module.exports = [
  require('./taiwan-mohw-ltc-overview'),
  require('./taiwan-ltc-policy-transformation'),
  require('./who-icope'),
  require('./ncbi-medication-safety-older-adults'),
];
