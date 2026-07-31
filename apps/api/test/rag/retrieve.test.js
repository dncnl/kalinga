const { test } = require('node:test');
const assert = require('node:assert/strict');

const { db } = require('../../src/firebase');
const embeddings = require('../../src/rag/embeddings');
const { retrieveRelevantChunks } = require('../../src/rag/retrieve');

function mockFindNearest(t, docs) {
  t.mock.method(db, 'collection', () => ({
    findNearest: () => ({ get: async () => ({ docs }) }),
  }));
}

function fakeDoc({ score, ...fields }) {
  return { data: () => ({ vectorDistance: 1 - score, ...fields }) };
}

test('retrieveRelevantChunks maps Firestore vector-search results, ranked by the server', async (t) => {
  t.mock.method(embeddings, 'embed', async () => [1, 0]);

  const docs = [
    fakeDoc({ score: 1, text: 'exact match', sourceId: 'a', sourceTitle: 'A', sourcePublisher: 'Pub A', sourceUrl: 'https://a', sourceCategory: 'cat' }),
    fakeDoc({ score: 0.9, text: 'close match', sourceId: 'c', sourceTitle: 'C', sourcePublisher: 'Pub C', sourceUrl: 'https://c', sourceCategory: 'cat' }),
  ];
  mockFindNearest(t, docs);

  const results = await retrieveRelevantChunks('anything', { topK: 2 });

  assert.equal(results.length, 2);
  assert.equal(results[0].text, 'exact match');
  assert.equal(results[1].text, 'close match');
  assert.equal(results[0].sourceUrl, 'https://a');
  assert.ok(Math.abs(results[0].score - 1) < 1e-9);
});

test('retrieveRelevantChunks filters out chunks below the relevance threshold', async (t) => {
  t.mock.method(embeddings, 'embed', async () => [1, 0]);

  const docs = [
    fakeDoc({ score: 0.5, text: 'relevant', sourceId: 'a', sourceTitle: 'A', sourcePublisher: 'Pub A', sourceUrl: 'https://a', sourceCategory: 'cat' }),
    fakeDoc({ score: 0.1, text: 'below threshold', sourceId: 'b', sourceTitle: 'B', sourcePublisher: 'Pub B', sourceUrl: 'https://b', sourceCategory: 'cat' }),
  ];
  mockFindNearest(t, docs);

  const results = await retrieveRelevantChunks('anything');

  assert.equal(results.length, 1);
  assert.equal(results[0].text, 'relevant');
});

test('retrieveRelevantChunks returns empty array when corpus is empty', async (t) => {
  t.mock.method(embeddings, 'embed', async () => [1, 0]);
  mockFindNearest(t, []);

  const results = await retrieveRelevantChunks('anything');

  assert.deepEqual(results, []);
});
