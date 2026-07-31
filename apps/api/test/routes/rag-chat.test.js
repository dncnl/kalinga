const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const firebase = require('../../src/firebase');
const retrieve = require('../../src/rag/retrieve');
const llmClient = require('../../src/lib/llmClient');
const translate = require('../../src/lib/translate');
const rollupDailySummary = require('../../src/lib/rollupDailySummary');
const rollupWeeklySummary = require('../../src/lib/rollupWeeklySummary');
const app = require('../../src/app');

const ROUTE = '/households/h1/care-recipients/r1/rag/ask';

function mockAuthedUser(t, uid) {
  t.mock.method(firebase.auth, 'verifyIdToken', async () => ({ uid }));
}

function mockAssignment(t, data) {
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: data !== null, data: () => data }),
    set: async () => {},
  }));
}

function mockRollups(t) {
  t.mock.method(rollupDailySummary, 'computeAndSaveDailySummary', async () => {});
  t.mock.method(rollupWeeklySummary, 'computeAndSaveWeeklySummary', async () => {});
}

test('rejects requests with no auth token', async () => {
  const res = await request(app).post(ROUTE).send({ question: 'hi', locale: 'fil' });
  assert.equal(res.status, 401);
});

test('rejects a missing question', async (t) => {
  mockAuthedUser(t, 'caregiver-1');

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ locale: 'fil' });
  assert.equal(res.status, 400);
});

test('rejects a missing or unsupported locale', async (t) => {
  mockAuthedUser(t, 'caregiver-1');

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ question: 'She is not eating' });
  assert.equal(res.status, 400);
});

test('rejects a caregiver with no active assignment', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, null);

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ question: 'She is not eating', locale: 'fil' });
  assert.equal(res.status, 403);
});

test('answers, translates, records an observation, and flags no concern for an unremarkable question', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });
  t.mock.method(retrieve, 'retrieveRelevantChunks', async () => [
    { text: 'x', sourceTitle: 'x', sourcePublisher: 'x', sourceUrl: 'x', sourceCategory: 'x' },
  ]);
  t.mock.method(llmClient, 'generateText', async () => 'That is normal at her age [1].');
  t.mock.method(translate, 'translateToMandarin', async () => ({ text: '這是正常的。' }));
  mockRollups(t);

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ question: 'Is it normal for her to sleep a lot?', locale: 'fil' });

  assert.equal(res.status, 200);
  assert.equal(res.body.answer, 'That is normal at her age [1].');
  assert.equal(res.body.translatedText, '這是正常的。');
  assert.equal(res.body.concern, null);
  assert.ok(res.body.observationId);
});

test('flags a concern for a red-flag phrase without asserting urgency', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });
  t.mock.method(retrieve, 'retrieveRelevantChunks', async () => [
    { text: 'x', sourceTitle: 'x', sourcePublisher: 'x', sourceUrl: 'x', sourceCategory: 'x' },
  ]);
  t.mock.method(llmClient, 'generateText', async () => 'This could be serious [1].');
  t.mock.method(translate, 'translateToMandarin', async () => ({ text: '這可能很嚴重。' }));
  mockRollups(t);

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ question: 'She says she cant breathe and is scared', locale: 'en' });

  assert.equal(res.status, 200);
  assert.equal(res.body.concern.symptomKey, 'breathing');
  assert.match(res.body.concern.message, /symptom check/);
});

test('still records the exchange if translation fails', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });
  t.mock.method(retrieve, 'retrieveRelevantChunks', async () => [
    { text: 'x', sourceTitle: 'x', sourcePublisher: 'x', sourceUrl: 'x', sourceCategory: 'x' },
  ]);
  t.mock.method(llmClient, 'generateText', async () => 'An answer.');
  t.mock.method(translate, 'translateToMandarin', async () => {
    throw new Error('translate api unavailable');
  });
  mockRollups(t);

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ question: 'Is this ok?', locale: 'vi' });

  assert.equal(res.status, 200);
  assert.equal(res.body.translatedText, null);
  assert.ok(res.body.observationId);
});

test('returns 502 when the LLM call fails', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });
  t.mock.method(retrieve, 'retrieveRelevantChunks', async () => [
    { text: 'x', sourceTitle: 'x', sourcePublisher: 'x', sourceUrl: 'x', sourceCategory: 'x' },
  ]);
  t.mock.method(llmClient, 'generateText', async () => {
    throw new Error('rate limited upstream');
  });

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ question: 'anything', locale: 'id' });

  assert.equal(res.status, 502);
});
