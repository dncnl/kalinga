const { Router } = require('express');

const firebase = require('../firebase');
const { requireAuth } = require('../middleware/auth');
const { isHouseholdMember } = require('../lib/authorizeHousehold');

const router = Router();

// Finds the caller's active household, or creates one on first use. There's
// no household onboarding flow (creating a household from scratch, naming
// it, etc) — "you get exactly one auto-created household the first time you
// touch this, and can later join others via invite" is the pragmatic stand-in.
//
// householdMemberships/{uid} shape: { householdIds: string[], activeHouseholdId }.
// A caregiver starts with exactly one; accepting someone else's invite adds
// to the list (see routes/invites.js) without changing which is active.
router.post('/households/bootstrap', requireAuth, async (req, res) => {
  const membershipRef = firebase.db.doc(`householdMemberships/${req.uid}`);
  const membershipSnap = await membershipRef.get();

  if (membershipSnap.exists) {
    return res.json({ householdId: membershipSnap.data().activeHouseholdId });
  }

  const householdRef = firebase.db.collection('households').doc();
  const now = new Date();

  const batch = firebase.db.batch();
  batch.set(householdRef, {
    name: "Caregiver's household",
    timezone: 'UTC',
    defaultLocale: 'en',
    status: 'active',
    createdByUid: req.uid,
    primaryFamilyContactUid: null,
    organizationLinkIds: [],
    privacyPolicyVersion: '0',
    consentModel: 'individual',
    dataRegion: null,
    archivedAt: null,
    createdAt: now,
    updatedAt: now,
  });
  batch.set(householdRef.collection('members').doc(req.uid), {
    uid: req.uid,
    role: 'caregiver',
    status: 'active',
    permissions: {},
    careRecipientIds: [],
    joinedAt: now,
    invitedByUid: null,
    removedAt: null,
    displayNameSnapshot: '',
    preferredLanguageSnapshot: 'en',
  });
  batch.set(membershipRef, { householdIds: [householdRef.id], activeHouseholdId: householdRef.id });
  await batch.commit();

  res.json({ householdId: householdRef.id });
});

// Lists every household the caller belongs to (for a household switcher UI)
// plus which one is currently active.
router.get('/households/mine', requireAuth, async (req, res) => {
  const membershipSnap = await firebase.db.doc(`householdMemberships/${req.uid}`).get();
  if (!membershipSnap.exists) {
    return res.json({ activeHouseholdId: null, households: [] });
  }

  const { householdIds, activeHouseholdId } = membershipSnap.data();
  const households = await Promise.all(
    householdIds.map(async (id) => {
      const snap = await firebase.db.doc(`households/${id}`).get();
      return { id, name: snap.data()?.name || 'Household' };
    }),
  );

  res.json({ activeHouseholdId, households });
});

// Switches which household is "active" — every other household-scoped call
// (care recipients, voice-log, etc) uses whichever one this points at.
// Caller must already be an active member of the target household (via
// bootstrap or a prior invite accept).
router.post('/households/switch', requireAuth, async (req, res) => {
  const { householdId } = req.body || {};
  if (!householdId) {
    return res.status(400).json({ error: 'householdId is required' });
  }

  const isMember = await isHouseholdMember({ householdId, uid: req.uid });
  if (!isMember) {
    return res.status(403).json({ error: 'Not a member of this household' });
  }

  await firebase.db.doc(`householdMemberships/${req.uid}`).set(
    { activeHouseholdId: householdId },
    { merge: true },
  );

  res.json({ householdId });
});

// Only the fields the mobile add-profile form actually collects
// (prototype_patient_page.dart: name, age, language, conditions).
// careProfile.conditions and .age aren't in the schema's typed fields —
// schema's careProfile field is a free-form "map" for exactly this kind of
// prototype-stage flexibility.
router.post('/households/:householdId/care-recipients', requireAuth, async (req, res) => {
  const { householdId } = req.params;
  const { displayName, age, preferredLanguages, conditions } = req.body || {};

  if (!displayName || typeof displayName !== 'string' || !displayName.trim()) {
    return res.status(400).json({ error: 'displayName is required' });
  }

  const isMember = await isHouseholdMember({ householdId, uid: req.uid });
  if (!isMember) {
    return res.status(403).json({ error: 'Not a member of this household' });
  }

  const now = new Date();
  const recipientRef = firebase.db
    .collection(`households/${householdId}/careRecipients`)
    .doc();

  const batch = firebase.db.batch();
  batch.set(recipientRef, {
    displayName: displayName.trim(),
    preferredName: null,
    birthDate: null,
    sex: 'undisclosed',
    photoAssetId: null,
    preferredLanguages: Array.isArray(preferredLanguages) ? preferredLanguages : [],
    communicationNotes: null,
    careProfile: {
      age: typeof age === 'number' ? age : null,
      conditions: Array.isArray(conditions) ? conditions : [],
    },
    emergencyContacts: [],
    primaryCaregiverUid: req.uid,
    primaryFamilyContactUid: null,
    status: 'active',
    externalIdentifiers: {},
    clinicalDisclaimerAcknowledged: false,
    createdAt: now,
    createdBy: req.uid,
    updatedAt: now,
    updatedBy: req.uid,
    deletedAt: null,
    deletedBy: null,
    deletionReason: null,
    retentionUntil: null,
    legalHold: false,
  });
  // Whoever creates a profile is immediately an active caregiver for it —
  // otherwise every voice-log/rollup call on their own new profile would
  // 403 from isCaregiverAssigned.
  batch.set(recipientRef.collection('assignments').doc(req.uid), {
    caregiverUid: req.uid,
    startsAt: now,
    endsAt: null,
    status: 'active',
    scopes: [],
    scheduleNotes: null,
    assignedByUid: req.uid,
    temporary: false,
    createdAt: now,
    createdBy: req.uid,
    updatedAt: now,
    updatedBy: req.uid,
  });
  // Pragmatic lookup (not in the original schema, same spirit as
  // householdMemberships) so a family viewer who only has a
  // careRecipientId (from an invite link) can resolve which household
  // it's in — see GET /care-recipients/:id/household below.
  batch.set(firebase.db.doc(`careRecipientLocations/${recipientRef.id}`), { householdId });
  await batch.commit();

  res.json({ careRecipientId: recipientRef.id });
});

router.get('/households/:householdId/care-recipients', requireAuth, async (req, res) => {
  const { householdId } = req.params;

  const isMember = await isHouseholdMember({ householdId, uid: req.uid });
  if (!isMember) {
    return res.status(403).json({ error: 'Not a member of this household' });
  }

  const snap = await firebase.db
    .collection(`households/${householdId}/careRecipients`)
    .where('status', '==', 'active')
    .get();

  const careRecipients = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  res.json({ careRecipients });
});

router.patch('/households/:householdId/care-recipients/:careRecipientId', requireAuth, async (req, res) => {
  const { householdId, careRecipientId } = req.params;
  const { displayName, age, preferredLanguages, conditions } = req.body || {};

  const isMember = await isHouseholdMember({ householdId, uid: req.uid });
  if (!isMember) {
    return res.status(403).json({ error: 'Not a member of this household' });
  }

  const ref = firebase.db.doc(`households/${householdId}/careRecipients/${careRecipientId}`);
  const snap = await ref.get();
  if (!snap.exists) {
    return res.status(404).json({ error: 'Care recipient not found' });
  }

  const existing = snap.data();
  const update = {
    updatedAt: new Date(),
    updatedBy: req.uid,
  };
  if (typeof displayName === 'string' && displayName.trim()) {
    update.displayName = displayName.trim();
  }
  if (Array.isArray(preferredLanguages)) {
    update.preferredLanguages = preferredLanguages;
  }
  if (typeof age === 'number' || Array.isArray(conditions)) {
    update.careProfile = {
      ...existing.careProfile,
      ...(typeof age === 'number' ? { age } : {}),
      ...(Array.isArray(conditions) ? { conditions } : {}),
    };
  }

  await ref.update(update);
  res.json({ ok: true });
});

// Soft delete only — status: 'archived', per the schema's own soft-delete
// mixin. GET .../care-recipients already filters to status == 'active', so
// an archived profile just stops showing up there.
router.delete('/households/:householdId/care-recipients/:careRecipientId', requireAuth, async (req, res) => {
  const { householdId, careRecipientId } = req.params;

  const isMember = await isHouseholdMember({ householdId, uid: req.uid });
  if (!isMember) {
    return res.status(403).json({ error: 'Not a member of this household' });
  }

  const ref = firebase.db.doc(`households/${householdId}/careRecipients/${careRecipientId}`);
  const snap = await ref.get();
  if (!snap.exists) {
    return res.status(404).json({ error: 'Care recipient not found' });
  }

  await ref.update({
    status: 'archived',
    deletedAt: new Date(),
    deletedBy: req.uid,
  });
  res.json({ ok: true });
});

// Resolves which household a care recipient belongs to, for a caller who
// only has the recipient id (e.g. a family member who just followed an
// invite link to /viewer/:careRecipientId). Returns 403 if the caller
// isn't actually a member of that household — this endpoint is the only
// thing standing between "I have a recipient id" and "I can read that
// recipient's data," so it must check membership itself rather than trust
// the caller.
router.get('/care-recipients/:careRecipientId/household', requireAuth, async (req, res) => {
  const { careRecipientId } = req.params;

  const locationSnap = await firebase.db.doc(`careRecipientLocations/${careRecipientId}`).get();
  if (!locationSnap.exists) {
    return res.status(404).json({ error: 'Care recipient not found' });
  }

  const { householdId } = locationSnap.data();
  const isMember = await isHouseholdMember({ householdId, uid: req.uid });
  if (!isMember) {
    return res.status(403).json({ error: 'Not authorized for this care recipient' });
  }

  res.json({ householdId });
});

module.exports = router;
