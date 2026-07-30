const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const firebase = require('../../src/firebase');
const retrieve = require('../../src/rag/retrieve');
const llmClient = require('../../src/lib/llmClient');
const app = require('../../src/app');

const ROUTE = '/rag/ask';

function mockAuthedUser(t, uid) {
  t.mock.method(firebase.auth, 'verifyIdToken', async () => ({ uid }));
}

test('rejects requests with no auth token', async () => {
  const res = await request(app).post(ROUTE).send({ question: 'hi' });
  assert.equal(res.status, 401);
});

test('rejects a missing question', async (t) => {
  mockAuthedUser(t, 'user-1');

  const res = await request(app).post(ROUTE).set('Authorization', 'Bearer token').send({});
  assert.equal(res.status, 400);
});

test('rejects a blank question', async (t) => {
  mockAuthedUser(t, 'user-1');

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ question: '   ' });
  assert.equal(res.status, 400);
});

test('returns a grounded answer with sources for an authed user', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(retrieve, 'retrieveRelevantChunks', async () => [
    {
      text: 'Taiwan LTC 2.0 covers 17 service types.',
      sourceTitle: 'MOHW LTC Overview',
      sourcePublisher: 'MOHW',
      sourceUrl: 'https://mohw.example',
      sourceCategory: 'taiwanHealthAuthority',
    },
  ]);
  t.mock.method(llmClient, 'generateText', async () => 'LTC 2.0 covers 17 service types [1].');

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ question: 'What does Taiwan LTC 2.0 cover?' });

  assert.equal(res.status, 200);
  assert.equal(res.body.answer, 'LTC 2.0 covers 17 service types [1].');
  assert.equal(res.body.sources.length, 1);
  assert.equal(res.body.sources[0].publisher, 'MOHW');
});

test('returns 502 when the LLM call fails', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(retrieve, 'retrieveRelevantChunks', async () => [
    { text: 'x', sourceTitle: 'x', sourcePublisher: 'x', sourceUrl: 'x', sourceCategory: 'x' },
  ]);
  t.mock.method(llmClient, 'generateText', async () => {
    throw new Error('rate limited upstream');
  });

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ question: 'anything' });

  assert.equal(res.status, 502);
  assert.match(res.body.detail, /rate limited upstream/);
});
