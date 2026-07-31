const { test } = require('node:test');
const assert = require('node:assert/strict');

const { db } = require('../../src/firebase');
const sources = require('../../src/rag/sources');
const { seedSources } = require('../../src/rag/seedSources');

test('seedSources upserts every hardcoded source into ragSources by id', async (t) => {
  const requestedCollections = [];
  const written = [];
  t.mock.method(db, 'collection', (name) => {
    requestedCollections.push(name);
    return { doc: (id) => ({ id }) };
  });
  t.mock.method(db, 'batch', () => ({
    set: (ref, data) => written.push({ id: ref.id, data }),
    commit: async () => {},
  }));

  await seedSources();

  assert.ok(requestedCollections.every((c) => c === 'ragSources'));
  assert.equal(written.length, sources.length);
  assert.equal(written[0].id, sources[0].id);
  assert.equal(written[0].data.title, sources[0].title);
  assert.equal(written[0].data.text, sources[0].text);
});
