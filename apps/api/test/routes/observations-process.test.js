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

// Doubles as the assignment check (isCaregiverAssigned) and the observation
// placeholder lookup /process now does instead of trusting a client-supplied
// storagePath — differentiate by path since both hit firebase.db.doc().
function mockAssignment(t, data) {
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.includes('/assignments/')) {
      return { get: async () => ({ exists: data !== null, data: () => data }) };
    }
    return {
      get: async () => ({ exists: true, data: () => ({ status: 'pendingUpload', audioExtension: 'm4a' }) }),
      set: async () => {},
    };
  });
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
    .send({ locale: 'fil' });
  assert.equal(res.status, 401);
});

test('rejects a missing locale', async (t) => {
  mockAuthedUser(t, 'caregiver-1');

  const res = await request(app).post(ROUTE).set('Authorization', 'Bearer token').send({});
  assert.equal(res.status, 400);
});

test('rejects an unsupported locale (ceb)', async (t) => {
  mockAuthedUser(t, 'caregiver-1');

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ locale: 'ceb' });

  assert.equal(res.status, 400);
});

test('rejects a caregiver with no active assignment', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, null);

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ locale: 'fil' });

  assert.equal(res.status, 403);
});

test('404s when no upload was recorded for this observation', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.includes('/assignments/')) {
      return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
    }
    return { get: async () => ({ exists: false }) };
  });

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ locale: 'fil' });

  assert.equal(res.status, 404);
});

test('runs the full pipeline and saves the observation for an assigned caregiver', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockPipelineSuccess(t);

  let savedDoc;
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.includes('/assignments/')) {
      return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
    }
    return {
      get: async () => ({ exists: true, data: () => ({ status: 'pendingUpload', audioExtension: 'm4a' }) }),
      set: async (doc) => {
        savedDoc = doc;
      },
    };
  });

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ locale: 'fil' });

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

test('returns 422 when no speech is detected, without calling translate/extract', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });
  t.mock.method(firebase, 'getBucket', () => ({ name: 'bucket' }));
  t.mock.method(speechClient, 'recognize', async () => [{ results: [] }]);

  let translateCalled = false;
  t.mock.method(translateClient, 'translateText', async () => {
    translateCalled = true;
    return [{ translations: [{ translatedText: '' }] }];
  });

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ locale: 'fil' });

  assert.equal(res.status, 422);
  assert.equal(res.body.error, 'No speech detected in recording');
  assert.equal(translateCalled, false);
});

test('returns 502 when the pipeline throws', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.includes('/assignments/')) {
      return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
    }
    return { get: async () => ({ exists: true, data: () => ({ status: 'pendingUpload', audioExtension: 'm4a' }) }) };
  });
  t.mock.method(firebase, 'getBucket', () => ({ name: 'bucket' }));
  t.mock.method(speechClient, 'recognize', async () => {
    throw new Error('STT quota exceeded');
  });

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ locale: 'fil' });

  assert.equal(res.status, 502);
  assert.match(res.body.detail, /STT quota exceeded/);
});
