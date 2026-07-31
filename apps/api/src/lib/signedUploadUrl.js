const firebase = require('../firebase');

// v4 signed URLs need an actual private key to sign with (a service
// account JSON key) — a user's `gcloud auth application-default login`
// credentials have no key material to sign with at all, which is exactly
// the "Cannot sign data without `client_email`" error this produces. Cloud
// Run's own service account identity works fine (it can sign via IAM), so
// this only bites local dev when FIREBASE_SERVICE_ACCOUNT (see firebase.js)
// isn't set.
const MISSING_SIGNING_KEY_HINT =
  'Could not create an upload URL — the server has no service account key to ' +
  "sign it with. Set FIREBASE_SERVICE_ACCOUNT in apps/api's .env (see .env.example).";

// Both upload-url routes (observations, medications) had this call bare and
// unhandled: any failure fell through to Express's default error handler,
// which serves an HTML page — that's why a signing failure showed up to the
// caregiver as a raw stack-trace dump instead of a real error message.
async function getSignedUploadUrl({ storagePath, contentType, expiresAt }) {
  try {
    const [uploadUrl] = await firebase
      .getBucket()
      .file(storagePath)
      .getSignedUrl({ version: 'v4', action: 'write', expires: expiresAt, contentType });
    return uploadUrl;
  } catch (err) {
    const friendly = /cannot sign data without/i.test(err.message) ? MISSING_SIGNING_KEY_HINT : err.message;
    const wrapped = new Error(friendly);
    wrapped.cause = err;
    throw wrapped;
  }
}

module.exports = { getSignedUploadUrl };
