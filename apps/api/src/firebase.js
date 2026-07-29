const { initializeApp, applicationDefault, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { getAuth } = require('firebase-admin/auth');

const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
const serviceAccount = serviceAccountJson ? JSON.parse(serviceAccountJson) : null;

// Plain @google-cloud/* clients (Speech, Translate) don't know about
// FIREBASE_SERVICE_ACCOUNT — that's a firebase-admin-only convention. Any
// client that needs to auth the same way should spread this in, e.g.
// `new SpeechClient(googleAuthOptions())`. Falls back to ADC (unset options)
// when no explicit service account is configured.
function googleAuthOptions() {
  return serviceAccount
    ? { credentials: serviceAccount, projectId: serviceAccount.project_id }
    : {};
}

const app = initializeApp({
  // Falls back to GOOGLE_APPLICATION_CREDENTIALS or ambient credentials
  // (e.g. Cloud Run's default service account) when unset.
  credential: serviceAccount ? cert(serviceAccount) : applicationDefault(),
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
});

const db = getFirestore(app);
const auth = getAuth(app);

// Lazy: only resolves (and requires FIREBASE_STORAGE_BUCKET) when a route
// actually needs Storage, so the server can still boot without it.
function getBucket() {
  return getStorage(app).bucket();
}

module.exports = { app, db, auth, getBucket, googleAuthOptions };
