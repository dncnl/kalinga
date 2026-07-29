const { initializeApp, applicationDefault, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { getAuth } = require('firebase-admin/auth');

function buildCredential() {
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (serviceAccountJson) {
    return cert(JSON.parse(serviceAccountJson));
  }
  // Falls back to GOOGLE_APPLICATION_CREDENTIALS or ambient credentials
  // (e.g. Cloud Run's default service account).
  return applicationDefault();
}

const app = initializeApp({
  credential: buildCredential(),
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
});

const db = getFirestore(app);
const auth = getAuth(app);

// Lazy: only resolves (and requires FIREBASE_STORAGE_BUCKET) when a route
// actually needs Storage, so the server can still boot without it.
function getBucket() {
  return getStorage(app).bucket();
}

module.exports = { app, db, auth, getBucket };
