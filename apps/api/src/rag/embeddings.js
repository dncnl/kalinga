// Local embeddings (no API key, no per-call cost) via transformers.js
// running a small sentence-transformer model on CPU. First call downloads
// the model (~90MB) to a local cache; subsequent calls are fast.
//
// Deliberately not using a hosted embeddings API here: every paid/quota-
// limited option hit in this project so far (Anthropic, Gemini) has been a
// dead end without billing set up (see PLAN.md). This has zero external
// dependency for the embedding step itself.
const MODEL_NAME = 'Xenova/all-MiniLM-L6-v2';

let extractorPromise = null;

function getExtractor() {
  if (!extractorPromise) {
    extractorPromise = import('@xenova/transformers').then(({ pipeline }) =>
      pipeline('feature-extraction', MODEL_NAME),
    );
  }
  return extractorPromise;
}

async function embed(text) {
  const extractor = await getExtractor();
  const output = await extractor(text, { pooling: 'mean', normalize: true });
  return Array.from(output.data);
}

async function embedBatch(texts) {
  const results = [];
  for (const text of texts) {
    results.push(await embed(text));
  }
  return results;
}

module.exports = { embed, embedBatch, MODEL_NAME };
