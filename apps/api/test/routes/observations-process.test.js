const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const firebase = require('../../src/firebase');
const processObservationJobLib = require('../../src/lib/processObservationJob');
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
      update: async () => {},
    };
  });
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

// The actual pipeline (transcribe/translate/extract/rollup) now runs in
// processObservationJob, tested separately in test/lib/processObservationJob.test.js
// -- this route's only job is to validate, flip status to 'processing', respond
// fast, and hand off to that job with the right arguments.
test('responds immediately with status "processing" and hands off to the background job', async (t) => {
  mockAuthedUser(t, 'caregiver-1');

  let updatedDoc;
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.includes('/assignments/')) {
      return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
    }
    return {
      get: async () => ({ exists: true, data: () => ({ status: 'pendingUpload', audioExtension: 'm4a' }) }),
      update: async (data) => { updatedDoc = data; },
    };
  });

  let jobArgs;
  let resolveJob;
  const jobStarted = new Promise((resolve) => { resolveJob = resolve; });
  t.mock.method(processObservationJobLib, 'processObservationJob', async (args) => {
    jobArgs = args;
    resolveJob();
  });

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ locale: 'fil' });

  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { observationId: 'obs-1', status: 'processing' });
  assert.equal(updatedDoc.status, 'processing');

  await jobStarted; // background job is fired-and-forgotten -- wait for it so the test doesn't exit early
  assert.equal(jobArgs.householdId, 'h1');
  assert.equal(jobArgs.careRecipientId, 'r1');
  assert.equal(jobArgs.observationId, 'obs-1');
  assert.equal(jobArgs.uid, 'caregiver-1');
  assert.equal(jobArgs.locale, 'fil');
  assert.equal(jobArgs.storagePath, 'households/h1/careRecipients/r1/observations/obs-1/audio.m4a');
});

test('a background job failure is caught and logged, never crashes the process', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });
  t.mock.method(processObservationJobLib, 'processObservationJob', async () => {
    throw new Error('boom');
  });

  let loggedArgs;
  let resolveLog;
  const logged = new Promise((resolve) => { resolveLog = resolve; });
  t.mock.method(console, 'error', (...args) => {
    loggedArgs = args;
    resolveLog();
  });

  const res = await request(app)
    .post(ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ locale: 'fil' });

  assert.equal(res.status, 200);
  await logged;
  assert.match(loggedArgs[0], /unhandled error from processObservationJob/);
});
