const { test } = require('node:test');
const assert = require('node:assert/strict');

const { chunkText } = require('../../src/rag/chunk');

test('chunkText returns a single chunk for short text', () => {
  const chunks = chunkText('a short sentence with few words', { chunkWords: 120, overlapWords: 30 });
  assert.equal(chunks.length, 1);
  assert.equal(chunks[0], 'a short sentence with few words');
});

test('chunkText splits long text with overlap', () => {
  const words = Array.from({ length: 300 }, (_, i) => `w${i}`);
  const text = words.join(' ');

  const chunks = chunkText(text, { chunkWords: 100, overlapWords: 20 });

  assert.ok(chunks.length > 1);
  // last word of chunk 1 should reappear near the start of chunk 2 (overlap)
  const chunk1Words = chunks[0].split(' ');
  const chunk2Words = chunks[1].split(' ');
  assert.equal(chunk1Words[chunk1Words.length - 1], chunk2Words[19]);
});

test('chunkText returns empty array for empty input', () => {
  assert.deepEqual(chunkText(''), []);
  assert.deepEqual(chunkText('   '), []);
});

test('chunkText covers the full text without dropping words', () => {
  const words = Array.from({ length: 50 }, (_, i) => `word${i}`);
  const text = words.join(' ');

  const chunks = chunkText(text, { chunkWords: 20, overlapWords: 5 });
  const lastChunkWords = chunks[chunks.length - 1].split(' ');

  assert.equal(lastChunkWords[lastChunkWords.length - 1], 'word49');
});
