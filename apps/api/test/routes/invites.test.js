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

function fakeCollectionRef(path) {
  let counter = 0;
  return {
    doc: (id) => {
      const docId = id || `auto-${++counter}`;
      return { id: docId, path: `${path}/${docId}` };
    },
  };
}

function futureDate(days = 7) {
  return { toDate: () => new Date(Date.now() + days * 24 * 60 * 60 * 1000) };
}

function pastDate() {
  return { toDate: () => new Date(Date.now() - 1000) };
}

test('POST invitations rejects a bad intendedRole', async (t) => {
  mockAuthedUser(t, 'user-1');

  const res = await request(app)
    .post('/households/h1/invitations')
    .set('Authorization', 'Bearer token')
    .send({ intendedRole: 'doctor', invitedEmail: 'a@b.com' });

  assert.equal(res.status, 400);
});

test('POST invitations rejects a missing invitedEmail', async (t) => {
  mockAuthedUser(t, 'user-1');

  const res = await request(app)
    .post('/households/h1/invitations')
    .set('Authorization', 'Bearer token')
    .send({ intendedRole: 'family' });

  assert.equal(res.status, 400);
});

test('POST invitations rejects a non-member', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', () => ({ get: async () => ({ exists: false }) }));

  const res = await request(app)
    .post('/households/h1/invitations')
    .set('Authorization', 'Bearer token')
    .send({ intendedRole: 'family', invitedEmail: 'a@b.com' });

  assert.equal(res.status, 403);
});

test('POST invitations creates an invitation and a token lookup, returns the raw token', async (t) => {
  mockAuthedUser(t, 'user-1');
  t.mock.method(firebase.db, 'doc', (path) => ({
    path,
    get: async () => ({ exists: true, data: () => ({ status: 'active' }) }),
  }));
  t.mock.method(firebase.db, 'collection', (path) => fakeCollectionRef(path));

  const sets = [];
  t.mock.method(firebase.db, 'batch', () => fakeBatch(sets));

  const res = await request(app)
    .post('/households/h1/invitations')
    .set('Authorization', 'Bearer token')
    .send({ intendedRole: 'family', invitedEmail: 'Family@Example.com', careRecipientId: 'rec-1' });

  assert.equal(res.status, 200);
  assert.ok(res.body.token);
  assert.equal(res.body.token.length, 48); // 24 random bytes, hex-encoded

  const invitationSet = sets.find((s) => s.path.includes('/invitations/'));
  assert.equal(invitationSet.data.intendedRole, 'family');
  assert.equal(invitationSet.data.invitedEmailNormalized, 'family@example.com');
  assert.equal(invitationSet.data.status, 'pending');
  assert.notEqual(invitationSet.data.tokenHash, res.body.token); // hash, not raw token

  const lookupSet = sets.find((s) => s.path.startsWith(`inviteTokens/${res.body.token}`));
  assert.equal(lookupSet.data.householdId, 'h1');
});

test('GET /invites/:token 404s for an unknown token', async (t) => {
  t.mock.method(firebase.db, 'doc', () => ({ get: async () => ({ exists: false }) }));

  const res = await request(app).get('/invites/nope');
  assert.equal(res.status, 404);
});

test('GET /invites/:token 404s for an expired invite', async (t) => {
  let call = 0;
  t.mock.method(firebase.db, 'doc', () => {
    call += 1;
    if (call === 1) {
      return { get: async () => ({ exists: true, data: () => ({ householdId: 'h1', invitationId: 'inv-1' }) }) };
    }
    return {
      get: async () => ({
        exists: true,
        data: () => ({ status: 'pending', expiresAt: pastDate(), invitedEmailNormalized: 'a@b.com' }),
      }),
    };
  });

  const res = await request(app).get('/invites/some-token');
  assert.equal(res.status, 404);
});

test('GET /invites/:token returns inviter and patient info for a valid pending invite', async (t) => {
  let call = 0;
  t.mock.method(firebase.db, 'doc', () => {
    call += 1;
    if (call === 1) {
      return { get: async () => ({ exists: true, data: () => ({ householdId: 'h1', invitationId: 'inv-1' }) }) };
    }
    if (call === 2) {
      return {
        get: async () => ({
          exists: true,
          data: () => ({
            status: 'pending',
            expiresAt: futureDate(),
            invitedEmailNormalized: 'family@example.com',
            createdBy: 'caregiver-uid',
            careRecipientId: 'rec-1',
          }),
        }),
      };
    }
    return { get: async () => ({ exists: true, data: () => ({ displayName: 'Lola Rosa' }) }) };
  });
  t.mock.method(firebase.auth, 'getUser', async () => ({ displayName: 'Siti' }));

  const res = await request(app).get('/invites/some-token');

  assert.equal(res.status, 200);
  assert.equal(res.body.inviterName, 'Siti');
  assert.equal(res.body.patientId, 'rec-1');
  assert.equal(res.body.patientName, 'Lola Rosa');
  assert.equal(res.body.email, 'family@example.com');
});

test('POST /invites/:token/accept rejects requests with no auth token', async () => {
  const res = await request(app).post('/invites/some-token/accept').send({});
  assert.equal(res.status, 401);
});

test('POST /invites/:token/accept 404s on an invalid invite', async (t) => {
  mockAuthedUser(t, 'family-uid');
  t.mock.method(firebase.db, 'doc', () => ({ get: async () => ({ exists: false }) }));

  const res = await request(app)
    .post('/invites/bad-token/accept')
    .set('Authorization', 'Bearer token');

  assert.equal(res.status, 404);
});

test('POST /invites/:token/accept adds a family member without creating an assignment', async (t) => {
  mockAuthedUser(t, 'family-uid');
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.startsWith('inviteTokens/')) {
      return { path, get: async () => ({ exists: true, data: () => ({ householdId: 'h1', invitationId: 'inv-1' }) }) };
    }
    if (path.includes('/invitations/')) {
      return {
        path,
        get: async () => ({
          exists: true,
          data: () => ({
            status: 'pending',
            expiresAt: futureDate(),
            intendedRole: 'family',
            careRecipientId: 'rec-1',
            createdBy: 'caregiver-uid',
          }),
        }),
      };
    }
    if (path.startsWith('householdMemberships/')) {
      // brand new family member — no prior household
      return { path, get: async () => ({ exists: false }), set: async () => {} };
    }
    return { path, get: async () => ({ exists: false }) };
  });

  const sets = [];
  t.mock.method(firebase.db, 'batch', () => fakeBatch(sets));

  const res = await request(app)
    .post('/invites/some-token/accept')
    .set('Authorization', 'Bearer token');

  assert.equal(res.status, 200);
  assert.equal(res.body.householdId, 'h1');

  const memberSet = sets.find((s) => s.path === 'households/h1/members/family-uid');
  assert.equal(memberSet.data.role, 'family');

  const assignmentSet = sets.find((s) => s.path.includes('/assignments/'));
  assert.equal(assignmentSet, undefined); // family role never gets a caregiver assignment
});

test('POST /invites/:token/accept adds a caregiver assignment when intendedRole is caregiver', async (t) => {
  mockAuthedUser(t, 'caregiver-2-uid');
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.startsWith('inviteTokens/')) {
      return { path, get: async () => ({ exists: true, data: () => ({ householdId: 'h1', invitationId: 'inv-1' }) }) };
    }
    if (path.includes('/invitations/')) {
      return {
        path,
        get: async () => ({
          exists: true,
          data: () => ({
            status: 'pending',
            expiresAt: futureDate(),
            intendedRole: 'caregiver',
            careRecipientId: 'rec-1',
            createdBy: 'caregiver-uid',
          }),
        }),
      };
    }
    if (path.startsWith('householdMemberships/')) {
      return { path, get: async () => ({ exists: false }), set: async () => {} };
    }
    return { path, get: async () => ({ exists: false }) };
  });

  const sets = [];
  t.mock.method(firebase.db, 'batch', () => fakeBatch(sets));

  const res = await request(app)
    .post('/invites/some-token/accept')
    .set('Authorization', 'Bearer token');

  assert.equal(res.status, 200);

  const assignmentSet = sets.find((s) => s.path === 'households/h1/careRecipients/rec-1/assignments/caregiver-2-uid');
  assert.equal(assignmentSet.data.status, 'active');
  assert.equal(assignmentSet.data.caregiverUid, 'caregiver-2-uid');
});
