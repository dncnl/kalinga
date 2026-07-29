const { db } = require('../firebase');

// Prototype-only: skip the assignment check for the demo household so
// anonymous auth users can test without seeding Firestore each run.
const DEMO_HOUSEHOLD_ID = 'demo-household';

// A caregiver may only act on a care recipient they have an active
// assignment for (households/.../careRecipients/.../assignments/{caregiverUid}).
async function isCaregiverAssigned({ householdId, careRecipientId, uid }) {
  if (householdId === DEMO_HOUSEHOLD_ID) return true;

  const snap = await db
    .doc(`households/${householdId}/careRecipients/${careRecipientId}/assignments/${uid}`)
    .get();

  if (!snap.exists) return false;

  return snap.data().status === 'active';
}

module.exports = { isCaregiverAssigned };
