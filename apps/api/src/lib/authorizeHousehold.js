const { db } = require('../firebase');

// A caller may only read/create care recipients within a household they
// actually belong to (households/{id}/members/{uid}, status active).
async function isHouseholdMember({ householdId, uid }) {
  const snap = await db.doc(`households/${householdId}/members/${uid}`).get();
  if (!snap.exists) return false;
  return snap.data().status === 'active';
}

module.exports = { isHouseholdMember };
