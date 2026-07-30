const { test } = require('node:test');
const assert = require('node:assert/strict');

const { db } = require('../../src/firebase');
const { isHouseholdMember } = require('../../src/lib/authorizeHousehold');

function mockDoc(t, data) {
  t.mock.method(db, 'doc', (path) => ({
    path,
    get: async () => ({ exists: data !== null, data: () => data }),
  }));
}

test('isHouseholdMember returns false when no membership doc exists', async (t) => {
  mockDoc(t, null);
  assert.equal(await isHouseholdMember({ householdId: 'h1', uid: 'u1' }), false);
});

test('isHouseholdMember returns false when membership is not active', async (t) => {
  mockDoc(t, { status: 'removed' });
  assert.equal(await isHouseholdMember({ householdId: 'h1', uid: 'u1' }), false);
});

test('isHouseholdMember returns true when membership is active', async (t) => {
  mockDoc(t, { status: 'active' });
  assert.equal(await isHouseholdMember({ householdId: 'h1', uid: 'u1' }), true);
});

test('isHouseholdMember queries the right document path', async (t) => {
  let queriedPath;
  t.mock.method(db, 'doc', (path) => {
    queriedPath = path;
    return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
  });

  await isHouseholdMember({ householdId: 'h1', uid: 'u1' });

  assert.equal(queriedPath, 'households/h1/members/u1');
});
