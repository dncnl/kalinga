const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const firebase = require('../../src/firebase');
const rollupDailySummary = require('../../src/lib/rollupDailySummary');
const rollupWeeklySummary = require('../../src/lib/rollupWeeklySummary');
const app = require('../../src/app');

const ROUTE = '/households/h1/care-recipients/r1/observations/demo-log';

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
  const res = await request(app).post(ROUTE).send({});
  assert.equal(res.status, 401);
});

test('rejects a caregiver with no active assignment', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, null);

  const res = await request(app).post(ROUTE).set('Authorization', 'Bearer token').send({});
  assert.equal(res.status, 403);
});

test('writes an observation and rolls up the trend for an assigned caregiver', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });
  mockRollups(t);

  const res = await request(app).post(ROUTE).set('Authorization', 'Bearer token').send({});

  assert.equal(res.status, 200);
  assert.ok(res.body.observationId);
  assert.equal(rollupDailySummary.computeAndSaveDailySummary.mock.callCount(), 1);
  assert.equal(rollupWeeklySummary.computeAndSaveWeeklySummary.mock.callCount(), 1);
});
