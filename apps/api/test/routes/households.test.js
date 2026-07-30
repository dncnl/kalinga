const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const firebase = require('../../src/firebase');
const app = require('../../src/app');

function mockAuthedUser(t, uid) {
  t.mock.method(firebase.auth, 'verifyIdToken', async () => ({ uid }));
}

function fakeBatch(sets) {
  return {
    set(ref, data) {
      sets.push({ path: ref.path, data });
    },
    commit: async () => {},
  };
}

// db.collection(path).doc() (no id) needs to hand back a ref with both a
// generated .id and a .path that includes it, for the batch-set spy above
// to be useful.
function fakeCollectionRef(path) {
  let counter = 0;
  return {
    doc: (id) => {
      const docId = id || `auto-${++counter}`;
      return { id: docId, path: `${path}/${docId}`, collection: (sub) => fakeCollectionRef(`${path}/${docId}/${sub}`) };
    },
  };
}

test('bootstrap rejects requests with no auth token', async () => {
  const res = await request(app).post('/households/bootstrap').send({});
  assert.equal(res.status, 401);
});

test('bootstrap returns the existing household if a membership doc exists', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: true, data: () => ({ householdId: 'existing-household' }) }),
  }));

  const res = await request(app).post('/households/bootstrap').set('Authorization', 'Bearer token');

  assert.equal(res.status, 200);
  assert.equal(res.body.householdId, 'existing-household');
});

test('bootstrap creates a new household when none exists', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: false, data: () => null }),
  }));
  t.mock.method(firebase.db, 'collection', (path) => fakeCollectionRef(path));

  const sets = [];
  t.mock.method(firebase.db, 'batch', () => fakeBatch(sets));

  const res = await request(app).post('/households/bootstrap').set('Authorization', 'Bearer token');

  assert.equal(res.status, 200);
  assert.ok(res.body.householdId);
  // household doc, members/{uid} doc, and the householdMemberships lookup
  assert.equal(sets.length, 3);
});

test('care-recipients POST rejects a missing displayName', async (t) => {
  mockAuthedUser(t, 'user-1');

  const res = await request(app)
    .post('/households/h1/care-recipients')
    .set('Authorization', 'Bearer token')
    .send({});

  assert.equal(res.status, 400);
});

test('care-recipients POST rejects a non-member', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: false, data: () => null }),
  }));

  const res = await request(app)
    .post('/households/h1/care-recipients')
    .set('Authorization', 'Bearer token')
    .send({ displayName: 'Lola Rosa' });

  assert.equal(res.status, 403);
});

test('care-recipients POST creates the recipient and an active assignment for the creator', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: true, data: () => ({ status: 'active' }) }),
  }));
  t.mock.method(firebase.db, 'collection', (path) => fakeCollectionRef(path));

  const sets = [];
  t.mock.method(firebase.db, 'batch', () => fakeBatch(sets));

  const res = await request(app)
    .post('/households/h1/care-recipients')
    .set('Authorization', 'Bearer token')
    .send({ displayName: 'Lola Rosa', age: 82, preferredLanguages: ['fil'], conditions: ['dementia'] });

  assert.equal(res.status, 200);
  assert.ok(res.body.careRecipientId);

  const recipientSet = sets.find((s) => s.path.includes('careRecipients/'));
  assert.equal(recipientSet.data.displayName, 'Lola Rosa');
  assert.equal(recipientSet.data.careProfile.age, 82);
  assert.deepEqual(recipientSet.data.careProfile.conditions, ['dementia']);
  assert.equal(recipientSet.data.primaryCaregiverUid, 'user-1');

  const assignmentSet = sets.find((s) => s.path.includes('/assignments/'));
  assert.equal(assignmentSet.data.status, 'active');
  assert.equal(assignmentSet.data.caregiverUid, 'user-1');
});

test('care-recipients GET rejects a non-member', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: false, data: () => null }),
  }));

  const res = await request(app).get('/households/h1/care-recipients').set('Authorization', 'Bearer token');

  assert.equal(res.status, 403);
});

test('care-recipients GET lists active recipients for a member', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: true, data: () => ({ status: 'active' }) }),
  }));
  t.mock.method(firebase.db, 'collection', () => ({
    where() {
      return this;
    },
    get: async () => ({
      docs: [{ id: 'rec-1', data: () => ({ displayName: 'Lola Rosa' }) }],
    }),
  }));

  const res = await request(app).get('/households/h1/care-recipients').set('Authorization', 'Bearer token');

  assert.equal(res.status, 200);
  assert.equal(res.body.careRecipients.length, 1);
  assert.equal(res.body.careRecipients[0].id, 'rec-1');
  assert.equal(res.body.careRecipients[0].displayName, 'Lola Rosa');
});
