const { test } = require('node:test');
const assert = require('node:assert/strict');

const { db } = require('../../src/firebase');
const { isCaregiverAssigned } = require('../../src/lib/authorizeCaregiver');

function mockDoc(t, data) {
  t.mock.method(db, 'doc', (path) => ({
    path,
    get: async () => ({
      exists: data !== null,
      data: () => data,
    }),
  }));
}

test('isCaregiverAssigned returns false when no assignment doc exists', async (t) => {
  mockDoc(t, null);

  const result = await isCaregiverAssigned({
    householdId: 'h1',
    careRecipientId: 'r1',
    uid: 'u1',
  });

  assert.equal(result, false);
});

test('isCaregiverAssigned returns false when assignment is not active', async (t) => {
  mockDoc(t, { status: 'ended' });

  const result = await isCaregiverAssigned({
    householdId: 'h1',
    careRecipientId: 'r1',
    uid: 'u1',
  });

  assert.equal(result, false);
});

test('isCaregiverAssigned returns true when assignment is active', async (t) => {
  mockDoc(t, { status: 'active' });

  const result = await isCaregiverAssigned({
    householdId: 'h1',
    careRecipientId: 'r1',
    uid: 'u1',
  });

  assert.equal(result, true);
});

test('isCaregiverAssigned queries the right document path', async (t) => {
  let queriedPath;
  t.mock.method(db, 'doc', (path) => {
    queriedPath = path;
    return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
  });

  await isCaregiverAssigned({ householdId: 'h1', careRecipientId: 'r1', uid: 'u1' });

  assert.equal(
    queriedPath,
    'households/h1/careRecipients/r1/assignments/u1',
  );
});
