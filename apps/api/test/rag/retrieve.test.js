const { test } = require('node:test');
const assert = require('node:assert/strict');

const { db } = require('../../src/firebase');
const embeddings = require('../../src/rag/embeddings');
const { retrieveRelevantChunks, cosineSimilarity } = require('../../src/rag/retrieve');

test('cosineSimilarity is 1 for identical vectors', () => {
  assert.ok(Math.abs(cosineSimilarity([1, 0, 0], [1, 0, 0]) - 1) < 1e-9);
});

test('cosineSimilarity is 0 for orthogonal vectors', () => {
  assert.ok(Math.abs(cosineSimilarity([1, 0], [0, 1])) < 1e-9);
});

test('cosineSimilarity handles a zero vector without dividing by zero', () => {
  assert.equal(cosineSimilarity([0, 0], [1, 1]), 0);
});

test('retrieveRelevantChunks ranks by similarity and respects topK', async (t) => {
  t.mock.method(embeddings, 'embed', async () => [1, 0]);

  const docs = [
    { data: () => ({ embedding: [1, 0], text: 'exact match', sourceId: 'a', sourceTitle: 'A', sourcePublisher: 'Pub A', sourceUrl: 'https://a', sourceCategory: 'cat' }) },
    { data: () => ({ embedding: [0, 1], text: 'orthogonal', sourceId: 'b', sourceTitle: 'B', sourcePublisher: 'Pub B', sourceUrl: 'https://b', sourceCategory: 'cat' }) },
    { data: () => ({ embedding: [0.9, 0.1], text: 'close match', sourceId: 'c', sourceTitle: 'C', sourcePublisher: 'Pub C', sourceUrl: 'https://c', sourceCategory: 'cat' }) },
  ];
  t.mock.method(db, 'collection', () => ({ get: async () => ({ docs }) }));

  const results = await retrieveRelevantChunks('anything', { topK: 2 });

  assert.equal(results.length, 2);
  assert.equal(results[0].text, 'exact match');
  assert.equal(results[1].text, 'close match');
  assert.equal(results[0].sourceUrl, 'https://a');
});

test('retrieveRelevantChunks filters out chunks below the relevance threshold', async (t) => {
  t.mock.method(embeddings, 'embed', async () => [1, 0]);

  const docs = [
    { data: () => ({ embedding: [1, 0], text: 'relevant', sourceId: 'a', sourceTitle: 'A', sourcePublisher: 'Pub A', sourceUrl: 'https://a', sourceCategory: 'cat' }) },
    { data: () => ({ embedding: [-1, 0], text: 'opposite direction', sourceId: 'b', sourceTitle: 'B', sourcePublisher: 'Pub B', sourceUrl: 'https://b', sourceCategory: 'cat' }) },
    { data: () => ({ embedding: [0, 1], text: 'orthogonal / unrelated', sourceId: 'c', sourceTitle: 'C', sourcePublisher: 'Pub C', sourceUrl: 'https://c', sourceCategory: 'cat' }) },
  ];
  t.mock.method(db, 'collection', () => ({ get: async () => ({ docs }) }));

  const results = await retrieveRelevantChunks('anything');

  assert.equal(results.length, 1);
  assert.equal(results[0].text, 'relevant');
});

test('retrieveRelevantChunks returns empty array when corpus is empty', async (t) => {
  t.mock.method(embeddings, 'embed', async () => [1, 0]);
  t.mock.method(db, 'collection', () => ({ get: async () => ({ docs: [] }) }));

  const results = await retrieveRelevantChunks('anything');

  assert.deepEqual(results, []);
});
