// Must be set BEFORE firebase-admin imports so the SDK picks them up on init.
// Manually pull from .env in case dotenv hasn't run yet when this module loads.
require('dotenv').config();

const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const isEmulator =
  !!process.env.FIREBASE_AUTH_EMULATOR_HOST ||
  !!process.env.FIRESTORE_EMULATOR_HOST;

console.log('[firebase] auth emulator  :', process.env.FIREBASE_AUTH_EMULATOR_HOST || 'NOT SET');
console.log('[firebase] firestore emul :', process.env.FIRESTORE_EMULATOR_HOST   || 'NOT SET');
console.log('[firebase] running mode   :', isEmulator ? 'EMULATOR' : 'PRODUCTION');

if (getApps().length === 0) {
  if (isEmulator) {
    // When targeting local emulators no real credentials are needed.
    // The SDK honours FIREBASE_AUTH_EMULATOR_HOST / FIRESTORE_EMULATOR_HOST automatically.
    initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID || 'kalinga-bc97f' });
  } else {
    // Production path — GOOGLE_APPLICATION_CREDENTIALS must point to a real key file.
    const { applicationDefault } = require('firebase-admin/app');
    try {
      initializeApp({ credential: applicationDefault() });
    } catch (error) {
      console.error('Failed to initialize Firebase Admin SDK:', error);
      process.exit(1);
    }
  }
}

const db = getFirestore();
db.settings({ ignoreUndefinedProperties: true });

module.exports = { db };
