const { test } = require('node:test');
const assert = require('node:assert/strict');

const firebase = require('../../src/firebase');
const { getSignedUploadUrl } = require('../../src/lib/signedUploadUrl');

test('returns the signed URL on success', async (t) => {
  t.mock.method(firebase, 'getBucket', () => ({
    file: () => ({ getSignedUrl: async () => ['https://signed.example.com/write'] }),
  }));

  const url = await getSignedUploadUrl({
    storagePath: 'x/y.jpg',
    contentType: 'image/jpeg',
    expiresAt: Date.now() + 1000,
  });

  assert.equal(url, 'https://signed.example.com/write');
});

test('replaces a missing-signing-key error with an actionable message', async (t) => {
  t.mock.method(firebase, 'getBucket', () => ({
    file: () => ({
      getSignedUrl: async () => {
        throw new Error('Cannot sign data without `client_email`.');
      },
    }),
  }));

  await assert.rejects(
    getSignedUploadUrl({ storagePath: 'x/y.jpg', contentType: 'image/jpeg', expiresAt: Date.now() }),
    (err) => {
      assert.match(err.message, /FIREBASE_SERVICE_ACCOUNT/);
      assert.doesNotMatch(err.message, /googleauth\.js/i);
      return true;
    },
  );
});

test('passes through an unrelated signing error unchanged', async (t) => {
  t.mock.method(firebase, 'getBucket', () => ({
    file: () => ({
      getSignedUrl: async () => {
        throw new Error('some other storage failure');
      },
    }),
  }));

  await assert.rejects(
    getSignedUploadUrl({ storagePath: 'x/y.jpg', contentType: 'image/jpeg', expiresAt: Date.now() }),
    /some other storage failure/,
  );
});
