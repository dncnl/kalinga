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
    update(ref, data) {
      sets.push({ path: ref.path, data, update: true });
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

test('bootstrap returns the active household if a membership doc exists', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: true, data: () => ({ householdIds: ['existing-household'], activeHouseholdId: 'existing-household' }) }),
  }));

  const res = await request(app).post('/households/bootstrap').set('Authorization', 'Bearer token');

  assert.equal(res.status, 200);
  assert.equal(res.body.householdId, 'existing-household');
});

test('bootstrap creates a new household when none exists', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', (path) => ({
    path,
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
  const membershipSet = sets.find((s) => s.path.startsWith('householdMemberships/'));
  assert.deepEqual(membershipSet.data.householdIds, [res.body.householdId]);
  assert.equal(membershipSet.data.activeHouseholdId, res.body.householdId);
});

test('GET /households/mine returns empty when the caller has no membership doc', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', () => ({ get: async () => ({ exists: false }) }));

  const res = await request(app).get('/households/mine').set('Authorization', 'Bearer token');

  assert.equal(res.status, 200);
  assert.equal(res.body.activeHouseholdId, null);
  assert.deepEqual(res.body.households, []);
});

test('GET /households/mine lists all households with names', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.startsWith('householdMemberships/')) {
      return { get: async () => ({ exists: true, data: () => ({ householdIds: ['h1', 'h2'], activeHouseholdId: 'h1' }) }) };
    }
    const id = path.split('/').pop();
    return { get: async () => ({ data: () => ({ name: `Household ${id}` }) }) };
  });

  const res = await request(app).get('/households/mine').set('Authorization', 'Bearer token');

  assert.equal(res.status, 200);
  assert.equal(res.body.activeHouseholdId, 'h1');
  assert.deepEqual(res.body.households, [
    { id: 'h1', name: 'Household h1' },
    { id: 'h2', name: 'Household h2' },
  ]);
});

test('POST /households/switch rejects a non-member', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', () => ({ get: async () => ({ exists: false }) }));

  const res = await request(app)
    .post('/households/switch')
    .set('Authorization', 'Bearer token')
    .send({ householdId: 'h2' });

  assert.equal(res.status, 403);
});

test('POST /households/switch updates activeHouseholdId for a member', async (t) => {
  mockAuthedUser(t, 'user-1');
  let setCall;
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: true, data: () => ({ status: 'active' }) }),
    set: async (data, opts) => {
      setCall = { data, opts };
    },
  }));

  const res = await request(app)
    .post('/households/switch')
    .set('Authorization', 'Bearer token')
    .send({ householdId: 'h2' });

  assert.equal(res.status, 200);
  assert.equal(res.body.householdId, 'h2');
  assert.equal(setCall.data.activeHouseholdId, 'h2');
  assert.equal(setCall.opts.merge, true);
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

test('care-recipients POST creates the recipient, an assignment, and a location lookup', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', (path) => ({
    path,
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

  const locationSet = sets.find((s) => s.path.startsWith(`careRecipientLocations/${res.body.careRecipientId}`));
  assert.equal(locationSet.data.householdId, 'h1');
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

test('care-recipients PATCH rejects a non-member', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', () => ({ get: async () => ({ exists: false }) }));

  const res = await request(app)
    .patch('/households/h1/care-recipients/rec-1')
    .set('Authorization', 'Bearer token')
    .send({ displayName: 'New Name' });

  assert.equal(res.status, 403);
});

test('care-recipients PATCH 404s on an unknown recipient', async (t) => {
  mockAuthedUser(t, 'user-1');
  let call = 0;
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => {
      call += 1;
      // 1st call: membership check (exists, active). 2nd: recipient (missing).
      return call === 1
        ? { exists: true, data: () => ({ status: 'active' }) }
        : { exists: false };
    },
  }));

  const res = await request(app)
    .patch('/households/h1/care-recipients/rec-1')
    .set('Authorization', 'Bearer token')
    .send({ displayName: 'New Name' });

  assert.equal(res.status, 404);
});

test('care-recipients PATCH updates only the provided fields, merging careProfile', async (t) => {
  mockAuthedUser(t, 'user-1');
  let updateCall;
  let call = 0;
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => {
      call += 1;
      return call === 1
        ? { exists: true, data: () => ({ status: 'active' }) }
        : { exists: true, data: () => ({ careProfile: { age: 80, conditions: ['dementia'] } }) };
    },
    update: async (data) => {
      updateCall = data;
    },
  }));

  const res = await request(app)
    .patch('/households/h1/care-recipients/rec-1')
    .set('Authorization', 'Bearer token')
    .send({ displayName: 'New Name', conditions: ['dementia', 'hypertension'] });

  assert.equal(res.status, 200);
  assert.equal(updateCall.displayName, 'New Name');
  assert.equal(updateCall.careProfile.age, 80); // preserved, not overwritten
  assert.deepEqual(updateCall.careProfile.conditions, ['dementia', 'hypertension']);
});

test('care-recipients DELETE soft-deletes (archives), not a hard delete', async (t) => {
  mockAuthedUser(t, 'user-1');
  let updateCall;
  let deleteCalled = false;
  let call = 0;
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => {
      call += 1;
      return call === 1
        ? { exists: true, data: () => ({ status: 'active' }) }
        : { exists: true, data: () => ({}) };
    },
    update: async (data) => {
      updateCall = data;
    },
    delete: async () => {
      deleteCalled = true;
    },
  }));

  const res = await request(app)
    .delete('/households/h1/care-recipients/rec-1')
    .set('Authorization', 'Bearer token');

  assert.equal(res.status, 200);
  assert.equal(updateCall.status, 'archived');
  assert.ok(updateCall.deletedAt);
  assert.equal(deleteCalled, false);
});

test('GET /care-recipients/:id/household 404s when there is no location doc', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', () => ({ get: async () => ({ exists: false }) }));

  const res = await request(app)
    .get('/care-recipients/rec-1/household')
    .set('Authorization', 'Bearer token');

  assert.equal(res.status, 404);
});

test('GET /care-recipients/:id/household rejects a caller who is not a household member', async (t) => {
  mockAuthedUser(t, 'user-1');
  let call = 0;
  t.mock.method(firebase.db, 'doc', () => {
    call += 1;
    if (call === 1) {
      return { get: async () => ({ exists: true, data: () => ({ householdId: 'h1' }) }) };
    }
    return { get: async () => ({ exists: false }) };
  });

  const res = await request(app)
    .get('/care-recipients/rec-1/household')
    .set('Authorization', 'Bearer token');

  assert.equal(res.status, 403);
});

test('GET /care-recipients/:id/household resolves the householdId for a member', async (t) => {
  mockAuthedUser(t, 'user-1');
  let call = 0;
  t.mock.method(firebase.db, 'doc', () => {
    call += 1;
    if (call === 1) {
      return { get: async () => ({ exists: true, data: () => ({ householdId: 'h1' }) }) };
    }
    return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
  });

  const res = await request(app)
    .get('/care-recipients/rec-1/household')
    .set('Authorization', 'Bearer token');

  assert.equal(res.status, 200);
  assert.equal(res.body.householdId, 'h1');
});
