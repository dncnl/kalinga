const { db } = require('../firebase');
const embeddings = require('./embeddings');

function cosineSimilarity(a, b) {
  let dot = 0;
  let normA = 0;
  let normB = 0;
  for (let i = 0; i < a.length; i += 1) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA === 0 || normB === 0) return 0;
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

// Empirically calibrated (see PLAN.md): genuinely relevant chunks scored
// 0.53-0.69 cosine similarity against real test queries; a fully unrelated
// query ("what is the capital of France?") scored negative across the whole
// corpus. 0.2 sits well clear of both — below it, a chunk is noise, not a
// citation. Without this, off-topic questions still surfaced 4 irrelevant
// "sources" even when the LLM correctly refused to answer from them.
const MIN_RELEVANCE_SCORE = 0.2;

// Loads the whole corpus into memory and ranks by cosine similarity. Fine
// at this scale (a handful of documents, low hundreds of chunks at most) —
// swap for a real vector index (e.g. Firestore vector search, or a
// dedicated vector DB) if the corpus grows enough for this to matter.
async function retrieveRelevantChunks(query, { topK = 4, minScore = MIN_RELEVANCE_SCORE } = {}) {
  const queryEmbedding = await embeddings.embed(query);

  const snap = await db.collection('ragChunks').get();
  const scored = snap.docs.map((doc) => {
    const data = doc.data();
    return {
      score: cosineSimilarity(queryEmbedding, data.embedding),
      text: data.text,
      sourceId: data.sourceId,
      sourceTitle: data.sourceTitle,
      sourcePublisher: data.sourcePublisher,
      sourceUrl: data.sourceUrl,
      sourceCategory: data.sourceCategory,
    };
  });

  scored.sort((a, b) => b.score - a.score);
  return scored.filter((c) => c.score >= minScore).slice(0, topK);
}

module.exports = { retrieveRelevantChunks, cosineSimilarity };
