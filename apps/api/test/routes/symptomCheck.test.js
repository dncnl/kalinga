const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const firebase = require('../../src/firebase');
const app = require('../../src/app');

const BASE = '/households/h1/care-recipients/r1';
const ROUTE = `${BASE}/symptom-check`;

function mockAuthedUser(t, uid) {
  t.mock.method(firebase.auth, 'verifyIdToken', async () => ({ uid }));
}

function mockAssignment(t, data) {
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: data !== null, data: () => data }),
  }));
}

// One fetch mock serves both the RAG-answer call (rag/answer.js ->
// llmClient.generateText) and the urgency-classification call
// (rag/classifyUrgency.js) — both hit OpenRouter's chat/completions shape.
function mockLlmSuccess(t, { answerContent, urgencyBody }) {
  t.mock.method(global, 'fetch', async (url, opts) => {
    const body = JSON.parse(opts.body);
    const isUrgencyCall = body.response_format?.type === 'json_object' && body.messages[0].content.includes('triage-urgency');
    if (isUrgencyCall) {
      return { ok: true, json: async () => ({ choices: [{ message: { content: JSON.stringify(urgencyBody) } }] }) };
    }
    return { ok: true, json: async () => ({ choices: [{ message: { content: answerContent } }] }) };
  });
}

function mockRetrieveAndTranslate(t, { chunks = defaultChunks(), translatedText = '她昨天吃得比較少。' } = {}) {
  const retrieve = require('../../src/rag/retrieve');
  t.mock.method(retrieve, 'retrieveRelevantChunks', async () => chunks);

  const translate = require('../../src/lib/translate');
  t.mock.method(translate.client, 'translateText', async () => [
    { translations: [{ translatedText }] },
  ]);
}

function defaultChunks() {
  return [
    {
      score: 0.6, text: 'Reduced appetite in older adults can indicate...', sourceId: 's1',
      sourceTitle: 'WHO iCOPE', sourcePublisher: 'WHO', sourceUrl: 'https://who.int/x', sourceCategory: 'guideline',
    },
  ];
}

test('rejects requests with no auth token', async () => {
  const res = await request(app).post(ROUTE).send({ message: 'she is not eating', locale: 'fil' });
  assert.equal(res.status, 401);
});

test('rejects a caregiver with no active assignment', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, null);

  const res = await request(app).post(ROUTE).set('Authorization', 'Bearer token').send({ message: 'x', locale: 'fil' });

  assert.equal(res.status, 403);
});

test('rejects a missing message', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });

  const res = await request(app).post(ROUTE).set('Authorization', 'Bearer token').send({ locale: 'fil' });

  assert.equal(res.status, 400);
});

test('rejects an unsupported locale', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });

  const res = await request(app).post(ROUTE).set('Authorization', 'Bearer token').send({ message: 'x', locale: 'ceb-fake' });

  assert.equal(res.status, 400);
});

test('saves a non-urgent symptom check and does not create an alert', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockRetrieveAndTranslate(t);
  mockLlmSuccess(t, {
    answerContent: 'Konting pagbaba ng gana ay normal minsan. Panoorin lang.',
    urgencyBody: { urgency: 'attention', reason: 'Minor appetite change.' },
  });

  let savedSymptomCheck;
  let alertCreated = false;
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.includes('/assignments/')) return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
    return {};
  });
  t.mock.method(firebase.db, 'collection', (path) => {
    if (path.endsWith('/symptomChecks')) {
      return { doc: () => ({ id: 'sc-1', path: `${path}/sc-1`, set: async (data) => { savedSymptomCheck = data; } }) };
    }
    if (path.endsWith('/alerts')) {
      return { doc: () => ({ id: 'alert-1', set: async () => { alertCreated = true; } }) };
    }
    return { doc: () => ({}) };
  });

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ message: 'She ate a little less today.', locale: 'fil' });

  assert.equal(res.status, 200, JSON.stringify(res.body));
  assert.equal(res.body.urgency, 'attention');
  assert.equal(res.body.alertId, null);
  assert.equal(res.body.flaggedToFamily, false);
  assert.equal(alertCreated, false);
  assert.equal(savedSymptomCheck.urgency, 'attention');
  assert.equal(savedSymptomCheck.alertId, null);
  assert.equal(savedSymptomCheck.locale, 'fil');
  assert.ok(savedSymptomCheck.familySummaryZh);
});

test('saves an urgent symptom check and creates an alert with family/doctor recipients', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockRetrieveAndTranslate(t);
  mockLlmSuccess(t, {
    answerContent: 'Ito ay maaaring seryoso. Tumawag agad sa doktor o 119.',
    urgencyBody: { urgency: 'emergency', reason: 'Possible cardiac event.' },
  });

  let savedSymptomCheck;
  let savedAlert;
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.includes('/assignments/')) return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
    return {};
  });
  t.mock.method(firebase.db, 'collection', (path) => {
    if (path.endsWith('/symptomChecks')) {
      return { doc: () => ({ id: 'sc-2', path: `${path}/sc-2`, set: async (data) => { savedSymptomCheck = data; } }) };
    }
    if (path.endsWith('/alerts')) {
      return { doc: () => ({ id: 'alert-2', set: async (data) => { savedAlert = data; } }) };
    }
    if (path.endsWith('/members')) {
      return {
        where: () => ({
          where: () => ({
            get: async () => ({
              docs: [
                { id: 'family-uid-1', data: () => ({ role: 'family', status: 'active' }) },
                { id: 'admin-uid-1', data: () => ({ role: 'householdAdmin', status: 'active' }) },
              ],
            }),
          }),
        }),
      };
    }
    return { doc: () => ({}) };
  });

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ message: 'She has chest pain and can\'t breathe.', locale: 'fil' });

  assert.equal(res.status, 200, JSON.stringify(res.body));
  assert.equal(res.body.urgency, 'emergency');
  assert.equal(res.body.alertId, 'alert-2');
  assert.equal(res.body.flaggedToFamily, true);
  assert.equal(savedSymptomCheck.alertId, 'alert-2');
  assert.equal(savedAlert.severity, 'emergency');
  assert.equal(savedAlert.type, 'emergency');
  assert.deepEqual(savedAlert.recipientUids, ['family-uid-1', 'admin-uid-1']);
  assert.equal(savedAlert.status, 'active');
});

test('GET history lists past symptom checks, most recent first', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  t.mock.method(firebase.db, 'doc', () => ({ get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) }));
  t.mock.method(firebase.db, 'collection', () => ({
    orderBy: () => ({
      limit: () => ({
        get: async () => ({
          docs: [
            {
              id: 'sc-1',
              data: () => ({
                messageText: 'x', urgency: 'none', createdAt: { toDate: () => new Date('2026-07-30T00:00:00.000Z') },
              }),
            },
          ],
        }),
      }),
    }),
  }));

  const res = await request(app).get(ROUTE).set('Authorization', 'Bearer token');

  assert.equal(res.status, 200);
  assert.equal(res.body.symptomChecks.length, 1);
  assert.equal(res.body.symptomChecks[0].id, 'sc-1');
  assert.equal(typeof res.body.symptomChecks[0].createdAt, 'string');
});
