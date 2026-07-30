const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const { db } = require('../../src/firebase');
const { uploadNewSources } = require('../../src/rag/uploadNewSources');

const VALID_DRAFT = JSON.stringify({
  id: 'new-doc',
  title: 'T',
  publisher: 'P',
  url: 'https://x',
  retrievedAt: '2026-01-01',
  category: 'c',
  text: 'Some knowledge base text.',
});

test('uploads a draft whose id is not already in ragSources', async (t) => {
  t.mock.method(fs, 'existsSync', () => true);
  t.mock.method(fs, 'readdirSync', () => ['new-doc.json']);
  t.mock.method(fs, 'readFileSync', () => VALID_DRAFT);

  let saved;
  t.mock.method(db, 'collection', () => ({
    doc: () => ({
      get: async () => ({ exists: false }),
      set: async (data) => { saved = data; },
    }),
  }));

  const result = await uploadNewSources();

  assert.equal(result.uploaded, 1);
  assert.equal(result.skipped, 0);
  assert.equal(saved.title, 'T');
  assert.ok(!('id' in saved), 'id should not be duplicated inside the document fields');
});

test('skips (never overwrites) a draft whose id already exists in ragSources', async (t) => {
  t.mock.method(fs, 'existsSync', () => true);
  t.mock.method(fs, 'readdirSync', () => ['new-doc.json']);
  t.mock.method(fs, 'readFileSync', () => VALID_DRAFT);

  let setCalled = false;
  t.mock.method(db, 'collection', () => ({
    doc: () => ({
      get: async () => ({ exists: true }),
      set: async () => { setCalled = true; },
    }),
  }));

  const result = await uploadNewSources();

  assert.equal(result.uploaded, 0);
  assert.equal(result.skipped, 1);
  assert.equal(setCalled, false);
});

test('skips a draft with a missing required field without crashing', async (t) => {
  t.mock.method(fs, 'existsSync', () => true);
  t.mock.method(fs, 'readdirSync', () => ['bad-doc.json']);
  t.mock.method(fs, 'readFileSync', () => JSON.stringify({ id: 'bad-doc', title: 'T' }));

  let setCalled = false;
  t.mock.method(db, 'collection', () => ({
    doc: () => ({ get: async () => ({ exists: false }), set: async () => { setCalled = true; } }),
  }));

  const result = await uploadNewSources();

  assert.equal(result.uploaded, 0);
  assert.equal(result.skipped, 0);
  assert.equal(setCalled, false);
});

test('does nothing when there is no drafts directory', async (t) => {
  t.mock.method(fs, 'existsSync', () => false);

  const result = await uploadNewSources();

  assert.equal(result.uploaded, 0);
  assert.equal(result.skipped, 0);
});
