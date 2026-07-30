const crypto = require('crypto');
const { Router } = require('express');
const { FieldValue } = require('firebase-admin/firestore');

const firebase = require('../firebase');
const { requireAuth } = require('../middleware/auth');
const { isHouseholdMember } = require('../lib/authorizeHousehold');

const router = Router();

const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

// Caregiver creates an invite. Doesn't send an email — no email
// infrastructure exists — just returns the token; the caller builds the
// shareable link (kalinga://invite/{token} or similar) and shares it
// manually. See mobile "invite family/caregiver" UI.
router.post('/households/:householdId/invitations', requireAuth, async (req, res) => {
  const { householdId } = req.params;
  const { intendedRole, invitedEmail, careRecipientId } = req.body || {};

  if (!['family', 'caregiver'].includes(intendedRole)) {
    return res.status(400).json({ error: "intendedRole must be 'family' or 'caregiver'" });
  }
  if (!invitedEmail || typeof invitedEmail !== 'string') {
    return res.status(400).json({ error: 'invitedEmail is required' });
  }

  const isMember = await isHouseholdMember({ householdId, uid: req.uid });
  if (!isMember) {
    return res.status(403).json({ error: 'Not a member of this household' });
  }

  const token = crypto.randomBytes(24).toString('hex');
  const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
  const now = new Date();
  const expiresAt = new Date(Date.now() + INVITE_TTL_MS);

  const invitationRef = firebase.db.collection(`households/${householdId}/invitations`).doc();

  const batch = firebase.db.batch();
  batch.set(invitationRef, {
    intendedRole,
    invitedEmailNormalized: invitedEmail.trim().toLowerCase(),
    invitedPhoneE164: null,
    tokenHash,
    expiresAt,
    status: 'pending',
    acceptedByUid: null,
    acceptedAt: null,
    permissionsTemplate: {},
    careRecipientId: careRecipientId || null,
    createdAt: now,
    createdBy: req.uid,
    updatedAt: now,
    updatedBy: req.uid,
  });
  // Lookup by raw token — the invitation doc itself only stores a hash
  // (per schema), so this is what GET/accept below actually query.
  batch.set(firebase.db.doc(`inviteTokens/${token}`), {
    householdId,
    invitationId: invitationRef.id,
  });
  await batch.commit();

  res.json({ token });
});

async function resolveInvitation(token) {
  const lookupSnap = await firebase.db.doc(`inviteTokens/${token}`).get();
  if (!lookupSnap.exists) return null;

  const { householdId, invitationId } = lookupSnap.data();
  const invitationRef = firebase.db.doc(`households/${householdId}/invitations/${invitationId}`);
  const invitationSnap = await invitationRef.get();
  if (!invitationSnap.exists) return null;

  return { householdId, invitationId, invitationRef, invitation: invitationSnap.data() };
}

// Public — the invitee has no Firebase account yet at this point, so this
// cannot require auth. Deliberately returns the same 404 shape for
// "doesn't exist," "expired," and "already used" — no reason to help an
// attacker distinguish those.
router.get('/invites/:token', async (req, res) => {
  const resolved = await resolveInvitation(req.params.token);
  if (!resolved) {
    return res.status(404).json({ error: 'Invite not found' });
  }

  const { householdId, invitation } = resolved;
  if (invitation.status !== 'pending' || invitation.expiresAt.toDate() < new Date()) {
    return res.status(404).json({ error: 'Invite not found' });
  }

  const inviter = await firebase.auth.getUser(invitation.createdBy).catch(() => null);

  let patientId = null;
  let patientName = null;
  if (invitation.careRecipientId) {
    const recipientSnap = await firebase.db
      .doc(`households/${householdId}/careRecipients/${invitation.careRecipientId}`)
      .get();
    if (recipientSnap.exists) {
      patientId = invitation.careRecipientId;
      patientName = recipientSnap.data().displayName;
    }
  }

  res.json({
    token: req.params.token,
    inviterName: inviter?.displayName || 'A caregiver',
    patientId,
    patientName,
    email: invitation.invitedEmailNormalized,
  });
});

router.post('/invites/:token/accept', requireAuth, async (req, res) => {
  const resolved = await resolveInvitation(req.params.token);
  if (!resolved) {
    return res.status(404).json({ error: 'Invite not found' });
  }

  const { householdId, invitation, invitationRef } = resolved;
  if (invitation.status !== 'pending' || invitation.expiresAt.toDate() < new Date()) {
    return res.status(404).json({ error: 'Invite not found' });
  }

  const now = new Date();
  const batch = firebase.db.batch();

  batch.set(firebase.db.doc(`households/${householdId}/members/${req.uid}`), {
    uid: req.uid,
    role: invitation.intendedRole,
    status: 'active',
    permissions: {},
    careRecipientIds: invitation.careRecipientId ? [invitation.careRecipientId] : [],
    joinedAt: now,
    invitedByUid: invitation.createdBy,
    removedAt: null,
    displayNameSnapshot: '',
    preferredLanguageSnapshot: 'en',
  });

  if (invitation.intendedRole === 'caregiver' && invitation.careRecipientId) {
    batch.set(
      firebase.db.doc(
        `households/${householdId}/careRecipients/${invitation.careRecipientId}/assignments/${req.uid}`,
      ),
      {
        caregiverUid: req.uid,
        startsAt: now,
        endsAt: null,
        status: 'active',
        scopes: [],
        scheduleNotes: null,
        assignedByUid: invitation.createdBy,
        temporary: false,
        createdAt: now,
        createdBy: req.uid,
        updatedAt: now,
        updatedBy: req.uid,
      },
    );
  }

  batch.update(invitationRef, {
    status: 'accepted',
    acceptedByUid: req.uid,
    acceptedAt: now,
    updatedAt: now,
    updatedBy: req.uid,
  });

  await batch.commit();

  // Separate from the batch above: needs a read first to decide whether
  // this is the invitee's first household (brand new membership doc) or
  // an additional one (existing caregiver accepting someone else's invite).
  const membershipRef = firebase.db.doc(`householdMemberships/${req.uid}`);
  const membershipSnap = await membershipRef.get();
  if (!membershipSnap.exists) {
    await membershipRef.set({ householdIds: [householdId], activeHouseholdId: householdId });
  } else {
    await membershipRef.update({ householdIds: FieldValue.arrayUnion(householdId) });
  }

  res.json({ householdId, careRecipientId: invitation.careRecipientId });
});

module.exports = router;
