const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const ingestFile = require('../../src/rag/ingest-file');
const app = require('../../src/app');

const ROUTE = '/internal/rag/ingest-gcs';

test('rejects when RAG_INGEST_SECRET is not configured', async (t) => {
  const original = process.env.RAG_INGEST_SECRET;
  delete process.env.RAG_INGEST_SECRET;
  t.after(() => {
    if (original !== undefined) process.env.RAG_INGEST_SECRET = original;
  });

  const res = await request(app)
    .post(ROUTE)
    .send({ bucketName: 'b', objectName: 'ragUploads/x.pdf' });
  assert.equal(res.status, 503);
});

test('rejects a request with the wrong secret', async (t) => {
  process.env.RAG_INGEST_SECRET = 'test-secret';
  t.after(() => { delete process.env.RAG_INGEST_SECRET; });

  const res = await request(app)
    .post(ROUTE)
    .set('X-Internal-Secret', 'wrong')
    .send({ bucketName: 'b', objectName: 'ragUploads/x.pdf' });
  assert.equal(res.status, 401);
});

test('rejects a missing bucketName/objectName', async (t) => {
  process.env.RAG_INGEST_SECRET = 'test-secret';
  t.after(() => { delete process.env.RAG_INGEST_SECRET; });

  const res = await request(app)
    .post(ROUTE)
    .set('X-Internal-Secret', 'test-secret')
    .send({});
  assert.equal(res.status, 400);
});

test('ingests the object when the secret matches', async (t) => {
  process.env.RAG_INGEST_SECRET = 'test-secret';
  t.after(() => { delete process.env.RAG_INGEST_SECRET; });

  t.mock.method(ingestFile, 'ingestFromGcs', async ({ bucketName, objectName }) => {
    assert.equal(bucketName, 'my-bucket');
    assert.equal(objectName, 'ragUploads/doc.pdf');
    return { sourceId: 'doc', chunkCount: 3 };
  });

  const res = await request(app)
    .post(ROUTE)
    .set('X-Internal-Secret', 'test-secret')
    .send({ bucketName: 'my-bucket', objectName: 'ragUploads/doc.pdf' });

  assert.equal(res.status, 200);
  assert.equal(res.body.sourceId, 'doc');
  assert.equal(res.body.chunkCount, 3);
});

test('returns 502 when ingestion fails', async (t) => {
  process.env.RAG_INGEST_SECRET = 'test-secret';
  t.after(() => { delete process.env.RAG_INGEST_SECRET; });

  t.mock.method(ingestFile, 'ingestFromGcs', async () => {
    throw new Error('pdf-parse blew up');
  });

  const res = await request(app)
    .post(ROUTE)
    .set('X-Internal-Secret', 'test-secret')
    .send({ bucketName: 'my-bucket', objectName: 'ragUploads/doc.pdf' });

  assert.equal(res.status, 502);
});
