const { test } = require('node:test');
const assert = require('node:assert/strict');

const { db } = require('../../src/firebase');
const embeddings = require('../../src/rag/embeddings');
const { ingestAll, fetchSources } = require('../../src/rag/ingest');

function mockBulkWriter(t, written, deleted) {
  t.mock.method(db, 'bulkWriter', () => ({
    set: (ref, data) => written.push({ id: ref.id, data }),
    delete: (ref) => deleted.push(ref.id),
    close: async () => {},
  }));
}

test('fetchSources reads from ragSources, not the hardcoded seed files', async (t) => {
  const sourceDocs = [
    { id: 'test-source', data: () => ({ title: 'T', publisher: 'P', url: 'https://x', retrievedAt: '2026-01-01', category: 'c', text: 'hi' }) },
  ];
  const requestedCollections = [];
  t.mock.method(db, 'collection', (name) => {
    requestedCollections.push(name);
    return { get: async () => ({ docs: sourceDocs }) };
  });

  const sources = await fetchSources();

  assert.deepEqual(requestedCollections, ['ragSources']);
  assert.equal(sources.length, 1);
  assert.equal(sources[0].id, 'test-source');
  assert.equal(sources[0].title, 'T');
});

test('ingestAll does nothing (no crash) when ragSources is empty', async (t) => {
  t.mock.method(db, 'collection', () => ({ get: async () => ({ docs: [] }) }));

  await ingestAll();
});

test('ingestAll chunks every ragSources document into ragChunks', async (t) => {
  t.mock.method(embeddings, 'embedBatch', async (chunks) => chunks.map(() => [1, 0]));

  const sourceDocs = [
    { id: 'test-source', data: () => ({ title: 'T', publisher: 'P', url: 'https://x', retrievedAt: '2026-01-01', category: 'c', text: 'Some knowledge base text.' }) },
  ];
  t.mock.method(db, 'collection', (name) => {
    if (name === 'ragSources') return { get: async () => ({ docs: sourceDocs }) };
    // ragChunks: no pre-existing chunks for this source in this scenario.
    return {
      doc: (id) => ({ id }),
      where: () => ({ get: async () => ({ docs: [] }) }),
    };
  });

  const written = [];
  const deleted = [];
  mockBulkWriter(t, written, deleted);

  await ingestAll();

  assert.ok(written.length > 0, 'expected at least one chunk to be written');
  assert.equal(written[0].data.sourceId, 'test-source');
  assert.ok(written[0].id.startsWith('test-source-'));
  assert.equal(deleted.length, 0);
});

test('ingestAll deletes trailing chunks left over from a source that got shorter', async (t) => {
  t.mock.method(embeddings, 'embedBatch', async (chunks) => chunks.map(() => [1, 0]));

  // Short enough to produce exactly one chunk this time.
  const sourceDocs = [
    { id: 'test-source', data: () => ({ title: 'T', publisher: 'P', url: 'https://x', retrievedAt: '2026-01-01', category: 'c', text: 'short text' }) },
  ];
  // Previously had 3 chunks (indices 0, 1, 2) — indices 1 and 2 are now stale.
  const existingChunkDocs = [0, 1, 2].map((chunkIndex) => ({
    ref: { id: `test-source-${chunkIndex}` },
    data: () => ({ chunkIndex }),
  }));

  t.mock.method(db, 'collection', (name) => {
    if (name === 'ragSources') return { get: async () => ({ docs: sourceDocs }) };
    return {
      doc: (id) => ({ id }),
      where: () => ({ get: async () => ({ docs: existingChunkDocs }) }),
    };
  });

  const written = [];
  const deleted = [];
  mockBulkWriter(t, written, deleted);

  await ingestAll();

  assert.equal(written.length, 1);
  assert.deepEqual(deleted.sort(), ['test-source-1', 'test-source-2']);
});
