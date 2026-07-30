// Splits document text into overlapping word-count chunks. Simple on
// purpose — this corpus is small (a handful of documents), so a naive
// sliding window is enough; revisit with sentence/semantic-aware chunking
// if the corpus grows much larger.
function chunkText(text, { chunkWords = 120, overlapWords = 30 } = {}) {
  const words = text.split(/\s+/).filter(Boolean);
  if (words.length === 0) return [];

  const chunks = [];
  let start = 0;
  while (start < words.length) {
    const end = Math.min(start + chunkWords, words.length);
    chunks.push(words.slice(start, end).join(' '));
    if (end === words.length) break;
    start += chunkWords - overlapWords;
  }
  return chunks;
}

module.exports = { chunkText };
