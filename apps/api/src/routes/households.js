const { Router } = require('express');

const firebase = require('../firebase');
const { requireAuth } = require('../middleware/auth');
const { isHouseholdMember } = require('../lib/authorizeHousehold');

const router = Router();

// Finds the caller's household, or creates one on first use. There's no
// household/family onboarding flow built yet (invites, linking multiple
// caregivers to one household, etc — see CLAUDE.md MVP list), so "you get
// exactly one household, auto-created the first time you touch this" is
// the pragmatic stand-in.
router.post('/households/bootstrap', requireAuth, async (req, res) => {
  const membershipRef = firebase.db.doc(`householdMemberships/${req.uid}`);
  const membershipSnap = await membershipRef.get();

  if (membershipSnap.exists) {
    return res.json({ householdId: membershipSnap.data().householdId });
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
  batch.set(membershipRef, { householdId: householdRef.id });
  await batch.commit();

  res.json({ householdId: householdRef.id });
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

module.exports = router;
