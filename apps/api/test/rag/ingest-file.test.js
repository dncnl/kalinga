const { test } = require('node:test');
const assert = require('node:assert/strict');

const { db } = require('../../src/firebase');
const embeddings = require('../../src/rag/embeddings');
const { ingestSource } = require('../../src/rag/ingest-file');

function mockFirestore(t) {
  const sourceWrites = [];
  const chunkWrites = [];
  t.mock.method(db, 'collection', (name) => {
    if (name === 'ragSources') {
      return { doc: (id) => ({ id, set: async (data) => sourceWrites.push({ id, data }) }) };
    }
    return { doc: (id) => ({ id }) };
  });
  t.mock.method(db, 'bulkWriter', () => ({
    set: (ref, data) => chunkWrites.push({ id: ref.id, data }),
    close: async () => {},
  }));
  return { sourceWrites, chunkWrites };
}

test('ingestSource writes the raw doc to ragSources and its chunks to ragChunks', async (t) => {
  t.mock.method(embeddings, 'embedBatch', async (chunks) => chunks.map(() => [1, 0]));
  const { sourceWrites, chunkWrites } = mockFirestore(t);

  const result = await ingestSource({
    id: 'my-doc',
    title: 'My Doc',
    publisher: 'Someone',
    url: 'https://example.com',
    retrievedAt: '2026-01-01',
    category: 'uploaded',
    text: 'Some raw document text.',
  });

  assert.equal(sourceWrites.length, 1);
  assert.equal(sourceWrites[0].id, 'my-doc');
  assert.equal(sourceWrites[0].data.text, 'Some raw document text.');
  assert.ok(chunkWrites.length > 0);
  assert.equal(chunkWrites[0].id, 'my-doc-0');
  assert.equal(chunkWrites[0].data.sourceId, 'my-doc');
  assert.equal(result.sourceId, 'my-doc');
  assert.equal(result.chunkCount, chunkWrites.length);
});
