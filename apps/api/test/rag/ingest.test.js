const { test } = require('node:test');
const assert = require('node:assert/strict');

const { db } = require('../../src/firebase');
const embeddings = require('../../src/rag/embeddings');
const { ingestAll } = require('../../src/rag/ingest');

test('ingestAll reads from ragSources (not the hardcoded seed files) and writes chunks to ragChunks', async (t) => {
  t.mock.method(embeddings, 'embedBatch', async (chunks) => chunks.map(() => [1, 0]));

  const sourceDocs = [
    { id: 'test-source', data: () => ({ title: 'T', publisher: 'P', url: 'https://x', retrievedAt: '2026-01-01', category: 'c', text: 'Some knowledge base text.' }) },
  ];

  const written = [];
  const requestedCollections = [];
  t.mock.method(db, 'collection', (name) => {
    requestedCollections.push(name);
    if (name === 'ragSources') return { get: async () => ({ docs: sourceDocs }) };
    return { doc: (id) => ({ id }) };
  });
  t.mock.method(db, 'batch', () => ({
    set: (ref, data) => written.push({ id: ref.id, data }),
    commit: async () => {},
  }));

  await ingestAll();

  assert.ok(requestedCollections.includes('ragSources'), 'expected ingest to read from ragSources');
  assert.ok(written.length > 0, 'expected at least one chunk to be written');
  assert.equal(written[0].data.sourceId, 'test-source');
  assert.ok(written[0].id.startsWith('test-source-'));
});

test('ingestAll does nothing (no crash) when ragSources is empty', async (t) => {
  t.mock.method(db, 'collection', () => ({ get: async () => ({ docs: [] }) }));

  await ingestAll();
});
