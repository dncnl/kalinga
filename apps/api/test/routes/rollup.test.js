const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const firebase = require('../../src/firebase');
const app = require('../../src/app');

const DAILY_ROUTE = '/households/h1/care-recipients/r1/rollup/daily';
const WEEKLY_ROUTE = '/households/h1/care-recipients/r1/rollup/weekly';

function mockAuthedUser(t, uid) {
  t.mock.method(firebase.auth, 'verifyIdToken', async () => ({ uid }));
}

// isCaregiverAssigned reads via db.doc(...).get() — this fakes an active
// assignment for any doc() call. The rollup functions themselves use
// db.collection(...) (queries) and db.doc(...) (writes), so we mock both.
function mockAssignedCaregiverAndStorage(t) {
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: true, data: () => ({ status: 'active' }) }),
    set: async () => {},
  }));
  t.mock.method(firebase.db, 'collection', () => ({
    where() {
      return this;
    },
    get: async () => ({ docs: [] }),
  }));
}

test('daily rollup rejects requests with no auth token', async () => {
  const res = await request(app).post(DAILY_ROUTE).send({ dateKey: '2026-07-29' });
  assert.equal(res.status, 401);
});

test('daily rollup rejects a malformed dateKey', async (t) => {
  mockAuthedUser(t, 'caregiver-1');

  const res = await request(app)
    .post(DAILY_ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ dateKey: 'not-a-date' });

  assert.equal(res.status, 400);
});

test('daily rollup rejects a caregiver with no active assignment', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: false, data: () => null }),
  }));

  const res = await request(app)
    .post(DAILY_ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ dateKey: '2026-07-29' });

  assert.equal(res.status, 403);
});

test('daily rollup succeeds for an assigned caregiver', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignedCaregiverAndStorage(t);

  const res = await request(app)
    .post(DAILY_ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ dateKey: '2026-07-29' });

  assert.equal(res.status, 200);
  assert.equal(res.body.dateKey, '2026-07-29');
});

test('weekly rollup rejects a missing weekKey/periodStart', async (t) => {
  mockAuthedUser(t, 'caregiver-1');

  const res = await request(app).post(WEEKLY_ROUTE).set('Authorization', 'Bearer token').send({});
  assert.equal(res.status, 400);
});

test('weekly rollup succeeds for an assigned caregiver', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignedCaregiverAndStorage(t);

  const res = await request(app)
    .post(WEEKLY_ROUTE)
    .set('Authorization', 'Bearer token')
    .send({ weekKey: '2026-W31', periodStart: '2026-07-27T00:00:00.000Z' });

  assert.equal(res.status, 200);
  assert.equal(res.body.weekKey, '2026-W31');
  assert.equal(res.body.trendSeries.sleep.length, 7);
});
