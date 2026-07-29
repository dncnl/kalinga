const { db } = require('../firebase');

// A caregiver may only act on a care recipient they have an active
// assignment for (households/.../careRecipients/.../assignments/{caregiverUid}).
async function isCaregiverAssigned({ householdId, careRecipientId, uid }) {
  const snap = await db
    .doc(`households/${householdId}/careRecipients/${careRecipientId}/assignments/${uid}`)
    .get();

  if (!snap.exists) return false;

  return snap.data().status === 'active';
}

module.exports = { isCaregiverAssigned };
