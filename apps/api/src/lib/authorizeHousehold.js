const { db } = require('../firebase');

// Roles allowed to mint invitations. Deliberately excludes 'family' (and the
// other privileged-but-not-inviting roles) — a family member who was
// themselves invited must not be able to mint further invites, especially a
// 'caregiver' invite with a care-recipient assignment attached.
const INVITE_CREATOR_ROLES = ['householdAdmin', 'caregiver'];

async function getActiveMembership({ householdId, uid }) {
  const snap = await db.doc(`households/${householdId}/members/${uid}`).get();
  if (!snap.exists) return null;
  const data = snap.data();
  return data.status === 'active' ? data : null;
}

// A caller may only read/create care recipients within a household they
// actually belong to (households/{id}/members/{uid}, status active).
async function isHouseholdMember({ householdId, uid }) {
  return (await getActiveMembership({ householdId, uid })) !== null;
}

async function canCreateInvites({ householdId, uid }) {
  const membership = await getActiveMembership({ householdId, uid });
  return !!membership && INVITE_CREATOR_ROLES.includes(membership.role);
}

module.exports = { isHouseholdMember, canCreateInvites };
