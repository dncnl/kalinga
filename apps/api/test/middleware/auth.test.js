const { test } = require('node:test');
const assert = require('node:assert/strict');

const { auth } = require('../../src/firebase');
const { requireAuth } = require('../../src/middleware/auth');

function fakeRes() {
  const res = {};
  res.statusCode = 200;
  res.body = undefined;
  res.status = (code) => {
    res.statusCode = code;
    return res;
  };
  res.json = (body) => {
    res.body = body;
    return res;
  };
  return res;
}

test('requireAuth rejects requests with no Authorization header', async () => {
  const req = { headers: {} };
  const res = fakeRes();
  let nextCalled = false;

  await requireAuth(req, res, () => {
    nextCalled = true;
  });

  assert.equal(nextCalled, false);
  assert.equal(res.statusCode, 401);
  assert.deepEqual(res.body, { error: 'Missing bearer token' });
});

test('requireAuth rejects a malformed Authorization header', async () => {
  const req = { headers: { authorization: 'Token abc123' } };
  const res = fakeRes();
  let nextCalled = false;

  await requireAuth(req, res, () => {
    nextCalled = true;
  });

  assert.equal(nextCalled, false);
  assert.equal(res.statusCode, 401);
});

test('requireAuth rejects an invalid/expired token', async (t) => {
  t.mock.method(auth, 'verifyIdToken', async () => {
    throw new Error('token expired');
  });

  const req = { headers: { authorization: 'Bearer bad-token' } };
  const res = fakeRes();
  let nextCalled = false;

  await requireAuth(req, res, () => {
    nextCalled = true;
  });

  assert.equal(nextCalled, false);
  assert.equal(res.statusCode, 401);
  assert.deepEqual(res.body, { error: 'Invalid or expired token' });
});

test('requireAuth attaches uid and calls next on a valid token', async (t) => {
  t.mock.method(auth, 'verifyIdToken', async (token) => {
    assert.equal(token, 'good-token');
    return { uid: 'caregiver-123' };
  });

  const req = { headers: { authorization: 'Bearer good-token' } };
  const res = fakeRes();
  let nextCalled = false;

  await requireAuth(req, res, () => {
    nextCalled = true;
  });

  assert.equal(nextCalled, true);
  assert.equal(req.uid, 'caregiver-123');
});
