const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const { db } = require('../../src/firebase');
const uploadNewSourcesModule = require('../../src/rag/uploadNewSources');
const { uploadNewSources } = uploadNewSourcesModule;

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

const PDF_METADATA_ONLY = JSON.stringify({
  id: 'pdf-doc',
  title: 'PDF Title',
  publisher: 'P',
  url: 'https://x',
  retrievedAt: '2026-01-01',
  category: 'c',
});

test('uploads a PDF + metadata sidecar pair, using the extracted PDF text', async (t) => {
  t.mock.method(fs, 'existsSync', () => true);
  t.mock.method(fs, 'readdirSync', () => ['pdf-doc.pdf', 'pdf-doc.json']);
  t.mock.method(fs, 'readFileSync', () => PDF_METADATA_ONLY);
  t.mock.method(uploadNewSourcesModule, 'extractPdfText', async () => 'Extracted PDF text.');

  let saved;
  t.mock.method(db, 'collection', () => ({
    doc: () => ({
      get: async () => ({ exists: false }),
      set: async (data) => { saved = data; },
    }),
  }));

  const result = await uploadNewSources();

  assert.equal(result.uploaded, 1);
  assert.equal(saved.title, 'PDF Title');
  assert.equal(saved.text, 'Extracted PDF text.');
});

test('skips a .pdf with no matching metadata sidecar', async (t) => {
  t.mock.method(fs, 'existsSync', () => true);
  t.mock.method(fs, 'readdirSync', () => ['orphan.pdf']);

  let setCalled = false;
  t.mock.method(db, 'collection', () => ({
    doc: () => ({ get: async () => ({ exists: false }), set: async () => { setCalled = true; } }),
  }));

  const result = await uploadNewSources();

  assert.equal(result.uploaded, 0);
  assert.equal(setCalled, false);
});

test('skips a PDF with no extractable text (scanned/image-only)', async (t) => {
  t.mock.method(fs, 'existsSync', () => true);
  t.mock.method(fs, 'readdirSync', () => ['pdf-doc.pdf', 'pdf-doc.json']);
  t.mock.method(fs, 'readFileSync', () => PDF_METADATA_ONLY);
  t.mock.method(uploadNewSourcesModule, 'extractPdfText', async () => '');

  let setCalled = false;
  t.mock.method(db, 'collection', () => ({
    doc: () => ({ get: async () => ({ exists: false }), set: async () => { setCalled = true; } }),
  }));

  const result = await uploadNewSources();

  assert.equal(result.uploaded, 0);
  assert.equal(setCalled, false);
});

test("a PDF's metadata .json sidecar is not also processed as a standalone text draft", async (t) => {
  t.mock.method(fs, 'existsSync', () => true);
  t.mock.method(fs, 'readdirSync', () => ['pdf-doc.pdf', 'pdf-doc.json']);
  t.mock.method(fs, 'readFileSync', () => PDF_METADATA_ONLY);
  t.mock.method(uploadNewSourcesModule, 'extractPdfText', async () => 'Extracted PDF text.');

  const setCalls = [];
  t.mock.method(db, 'collection', () => ({
    doc: () => ({
      get: async () => ({ exists: false }),
      set: async (data) => { setCalls.push(data); },
    }),
  }));

  const result = await uploadNewSources();

  assert.equal(result.uploaded, 1, 'the pair should upload exactly once, not twice');
  assert.equal(setCalls.length, 1);
});

test('does nothing when there is no drafts directory', async (t) => {
  t.mock.method(fs, 'existsSync', () => false);

  const result = await uploadNewSources();

  assert.equal(result.uploaded, 0);
  assert.equal(result.skipped, 0);
});
