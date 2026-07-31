// Original seed corpus, used ONLY by seedSources.js to bootstrap the
// ragSources Firestore collection on a fresh project. The knowledge base
// itself lives in ragSources (Firestore) — add/edit documents there (or via
// ingest-file.js for a new document), not here; ingest.js reads from
// Firestore, not from this file. Each entry here is a real, cited public
// source (Taiwan health authority, WHO, or peer-reviewed research) — see
// individual files for URLs and retrieval dates.
module.exports = [
  require('./taiwan-mohw-ltc-overview'),
  require('./taiwan-ltc-policy-transformation'),
  require('./who-icope'),
  require('./ncbi-medication-safety-older-adults'),
  require('./ncbi-abdominal-emergencies-elderly'),
];
