const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const firebase = require('../../src/firebase');
const { client: speechClient } = require('../../src/lib/transcribe');
const { client: translateClient } = require('../../src/lib/translate');
const app = require('../../src/app');

const ROUTE = '/households/h1/care-recipients/r1/observations/obs-1/process';

function mockAuthedUser(t, uid) {
  t.mock.method(firebase.auth, 'verifyIdToken', async () => ({ uid }));
}

function mockAssignment(t, data) {
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: data !== null, data: () => data }),
    set: async () => {},
  }));
}

function mockPipelineSuccess(t) {
  t.mock.method(firebase, 'getBucket', () => ({ name: 'kalinga-bc97f.firebasestorage.app' }));
  t.mock.method(speechClient, 'recognize', async () => [
    { results: [{ alternatives: [{ transcript: 'Natulog siya nang mahusay.' }] }] },
  ]);
  t.mock.method(translateClient, 'translateText', async () => [
    { translations: [{ translatedText: '他睡得很好。' }] },
  ]);
  t.mock.method(global, 'fetch', async () => ({
    ok: true,
    json: async () => ({
      choices: [
        {
          message: {
            tool_calls: [
              {
                function: {
                  arguments: JSON.stringify({
                    categories: ['sleep'],
                    comparisonToUsual: 'same',
                    structuredObservation: { summary: 'Slept well.' },
                    safetyAssessment: { concernLevel: 'none', concerns: [], recommendFollowUp: false },
                  }),
                },
              },
            ],
          },
        },
      ],
    }),
  }));
}

test('rejects requests with no auth token', async () => {
  const res = await request(app)
    .post(ROUTE)
    .send({ storagePath: 'p', locale: 'fil' });
  assert.equal(res.status, 401);
});

test('rejects a missing storagePath/locale', async (t) => {
  mockAuthedUser(t, 'caregiver-1');

  const res = await request(app).post(ROUTE).set('Authorization', 'Bearer token').send({});
  assert.equal(res.status, 400);
});

test('rejects an unsupported locale (ceb)', async (t) => {
  mockAuthedUser(t, 'caregiver-1');

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ storagePath: 'p', locale: 'ceb' });

  assert.equal(res.status, 400);
});

test('rejects a caregiver with no active assignment', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, null);

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ storagePath: 'p', locale: 'fil' });

  assert.equal(res.status, 403);
});

test('runs the full pipeline and saves the observation for an assigned caregiver', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });
  mockPipelineSuccess(t);

  let savedDoc;
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: true, data: () => ({ status: 'active' }) }),
    set: async (doc) => {
      savedDoc = doc;
    },
  }));

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ storagePath: 'households/h1/careRecipients/r1/observations/obs-1/audio.m4a', locale: 'fil' });

  assert.equal(res.status, 200);
  assert.equal(res.body.transcript, 'Natulog siya nang mahusay.');
  assert.equal(res.body.translatedText, '他睡得很好。');
  assert.deepEqual(res.body.categories, ['sleep']);

  assert.equal(savedDoc.authorUid, 'caregiver-1');
  assert.equal(savedDoc.originalText, 'Natulog siya nang mahusay.');
  assert.equal(savedDoc.translations['zh-TW'].text, '他睡得很好。');
  assert.equal(
    savedDoc.originalAudioAssetId,
    'households/h1/careRecipients/r1/observations/obs-1/audio.m4a',
  );
});

test('returns 502 when the pipeline throws', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: true, data: () => ({ status: 'active' }) }),
  }));
  t.mock.method(firebase, 'getBucket', () => ({ name: 'bucket' }));
  t.mock.method(speechClient, 'recognize', async () => {
    throw new Error('STT quota exceeded');
  });

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ storagePath: 'p', locale: 'fil' });

  assert.equal(res.status, 502);
  assert.match(res.body.detail, /STT quota exceeded/);
});
