const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const firebase = require('../../src/firebase');
const app = require('../../src/app');

const ROUTE = '/households/h1/care-recipients/r1/observations/upload-url';

function mockAuthedUser(t, uid) {
  t.mock.method(firebase.auth, 'verifyIdToken', async () => ({ uid }));
}

function mockAssignment(t, data) {
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: data !== null, data: () => data }),
    set: async () => {},
  }));
}

test('rejects requests with no auth token', async () => {
  const res = await request(app).post(ROUTE).send({ contentType: 'audio/m4a' });
  assert.equal(res.status, 401);
});

test('rejects an unsupported content type', async (t) => {
  mockAuthedUser(t, 'caregiver-1');

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ contentType: 'video/mp4' });

  assert.equal(res.status, 400);
});

test('rejects a caregiver with no active assignment', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, null);

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ contentType: 'audio/m4a' });

  assert.equal(res.status, 403);
});

test('returns a signed upload URL for an assigned caregiver', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });

  t.mock.method(firebase.db, 'collection', () => ({
    doc: () => ({ id: 'obs-123' }),
  }));

  t.mock.method(firebase, 'getBucket', () => ({
    file: (path) => ({
      getSignedUrl: async (opts) => {
        assert.equal(path, 'households/h1/careRecipients/r1/observations/obs-123/audio.m4a');
        assert.equal(opts.action, 'write');
        assert.equal(opts.contentType, 'audio/m4a');
        return ['https://signed.example.com/upload'];
      },
    }),
  }));

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ contentType: 'audio/m4a' });

  assert.equal(res.status, 200);
  assert.equal(res.body.observationId, 'obs-123');
  assert.equal(res.body.uploadUrl, 'https://signed.example.com/upload');
  assert.equal(
    res.body.storagePath,
    'households/h1/careRecipients/r1/observations/obs-123/audio.m4a',
  );
});

// Regression: this used to be an unhandled rejection, which Express served
// as a raw HTML error page (the caregiver saw a stack trace instead of a
// message). Must now come back as clean JSON.
test('returns a clean JSON error when signing fails', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });

  t.mock.method(firebase.db, 'collection', () => ({ doc: () => ({ id: 'obs-123' }) }));
  t.mock.method(firebase, 'getBucket', () => ({
    file: () => ({
      getSignedUrl: async () => {
        throw new Error('Cannot sign data without `client_email`.');
      },
    }),
  }));

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ contentType: 'audio/m4a' });

  assert.equal(res.status, 502);
  assert.match(res.body.error, /FIREBASE_SERVICE_ACCOUNT/);
});
