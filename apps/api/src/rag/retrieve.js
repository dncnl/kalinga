const { FieldValue } = require('firebase-admin/firestore');
const { db } = require('../firebase');
const embeddings = require('./embeddings');

// Empirically calibrated (see PLAN.md): genuinely relevant chunks scored
// 0.53-0.69 cosine similarity against real test queries; a fully unrelated
// query ("what is the capital of France?") scored negative across the whole
// corpus. 0.2 sits well clear of both — below it, a chunk is noise, not a
// citation. Without this, off-topic questions still surfaced 4 irrelevant
// "sources" even when the LLM correctly refused to answer from them.
const MIN_RELEVANCE_SCORE = 0.2;

// Uses Firestore's native vector index (see firestore.indexes.json) instead
// of loading the whole corpus into memory, so retrieval cost scales with
// the index rather than the collection size.
async function retrieveRelevantChunks(query, { topK = 4, minScore = MIN_RELEVANCE_SCORE } = {}) {
  const queryEmbedding = await embeddings.embed(query);
  const maxDistance = 1 - minScore; // COSINE distanceMeasure returns 1 - cosine_similarity

  const snap = await db
    .collection('ragChunks')
    .findNearest({
      vectorField: 'embedding',
      queryVector: FieldValue.vector(queryEmbedding),
      limit: topK,
      distanceMeasure: 'COSINE',
      distanceResultField: 'vectorDistance',
      distanceThreshold: maxDistance,
    })
    .get();

  return snap.docs
    .map((doc) => {
      const data = doc.data();
      return {
        score: 1 - data.vectorDistance,
        text: data.text,
        sourceId: data.sourceId,
        sourceTitle: data.sourceTitle,
        sourcePublisher: data.sourcePublisher,
        sourceUrl: data.sourceUrl,
        sourceCategory: data.sourceCategory,
      };
    })
    // Defensive filter in case distanceThreshold is a soft optimization
    // rather than a hard cutoff in this SDK version.
    .filter((c) => c.score >= minScore);
}

module.exports = { retrieveRelevantChunks };
