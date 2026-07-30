const crypto = require('crypto');
const { Router } = require('express');
const { FieldValue } = require('firebase-admin/firestore');

const firebase = require('../firebase');
const { requireAuth } = require('../middleware/auth');
const { canCreateInvites } = require('../lib/authorizeHousehold');
const { timestampId } = require('../lib/readableId');

const router = Router();

const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

// Excludes 0/O and 1/I/L — meant to be read off a screen and typed by hand
// during onboarding, not copy-pasted from a link.
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 8;

function generateInviteCode() {
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i += 1) {
    code += CODE_ALPHABET[crypto.randomInt(CODE_ALPHABET.length)];
  }
  return code;
}

// Case/whitespace-forgiving — someone typing this off a screen shouldn't
// get rejected over Shift state.
function normalizeCode(raw) {
  return String(raw || '').trim().toUpperCase();
}

function hashCode(code) {
  return crypto.createHash('sha256').update(normalizeCode(code)).digest('hex');
}

// Caregiver generates a join code. Only householdAdmin/caregiver roles may
// mint one — a 'family' member (itself invited) minting a 'caregiver' code
// with a care-recipient assignment would be a privilege escalation.
//
// This is a pure shared-secret join code, not tied to any particular
// invitee identity (email/phone) — whoever the caregiver shares it with
// (verbally, text, any channel) and types it in claims the role. Security
// rests on the code being random, single-use (status flips to 'accepted'),
// and short-lived (7 days), not on verifying who's entering it.
router.post('/households/:householdId/invitations', requireAuth, async (req, res) => {
  const { householdId } = req.params;
  const { intendedRole, careRecipientId } = req.body || {};

  if (!['family', 'caregiver'].includes(intendedRole)) {
    return res.status(400).json({ error: "intendedRole must be 'family' or 'caregiver'" });
  }

  const canInvite = await canCreateInvites({ householdId, uid: req.uid });
  if (!canInvite) {
    return res.status(403).json({ error: 'Not authorized to invite members to this household' });
  }

  const code = generateInviteCode();
  const tokenHash = hashCode(code);
  const now = new Date();
  const expiresAt = new Date(Date.now() + INVITE_TTL_MS);

  // Readable id is fine — the invitationId itself is never secret (only the
  // raw code / its tokenHash are), and it's never exposed to or accepted by
  // the client directly (inviteTokens/{tokenHash} is the real lookup).
  const invitationRef = firebase.db.collection(`households/${householdId}/invitations`).doc(`${intendedRole}-${timestampId()}`);

  const batch = firebase.db.batch();
  batch.set(invitationRef, {
    intendedRole,
    invitedEmailNormalized: null,
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
  // Lookup keyed by the code's hash, never the raw code — the raw code only
  // ever exists in memory here and wherever the caregiver shares it.
  batch.set(firebase.db.doc(`inviteTokens/${tokenHash}`), {
    householdId,
    invitationId: invitationRef.id,
  });
  await batch.commit();

  res.json({ code });
});

async function resolveInvitation(rawCode) {
  const lookupSnap = await firebase.db.doc(`inviteTokens/${hashCode(rawCode)}`).get();
  if (!lookupSnap.exists) return null;

  const { householdId, invitationId } = lookupSnap.data();
  const invitationRef = firebase.db.doc(`households/${householdId}/invitations/${invitationId}`);
  const invitationSnap = await invitationRef.get();
  if (!invitationSnap.exists) return null;

  return { householdId, invitationId, invitationRef, invitation: invitationSnap.data() };
}

// Public — used to preview a code (who invited you, for whom) before/while
// entering it, so it deliberately doesn't require auth. Returns the same
// 404 shape for "doesn't exist," "expired," and "already used" — no reason
// to help someone guessing codes distinguish those.
router.get('/invites/:code', async (req, res) => {
  const resolved = await resolveInvitation(req.params.code);
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
    intendedRole: invitation.intendedRole,
    inviterName: inviter?.displayName || 'A caregiver',
    patientId,
    patientName,
  });
});

// Called after the invitee has already registered/signed in — this is the
// "are you a family member? enter your code" step in onboarding, not a
// pre-registration link click. requireAuth identifies who's claiming the
// code; nothing here checks *who* that is against the invitation, by design
// (see the join-code note above).
router.post('/invites/:code/accept', requireAuth, async (req, res) => {
  const resolved = await resolveInvitation(req.params.code);
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
