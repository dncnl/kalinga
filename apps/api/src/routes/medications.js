const { Router } = require('express');

const firebase = require('../firebase');
const { requireAuth } = require('../middleware/auth');
const { isCaregiverAssigned } = require('../lib/authorizeCaregiver');
const { dayBoundsUtc } = require('../lib/rollupDailySummary');
const { extractMedicationLabel } = require('../lib/extractMedicationLabel');

const router = Router();

const UPLOAD_URL_TTL_MS = 15 * 60 * 1000;
const READ_URL_TTL_MS = 15 * 60 * 1000;
const ALLOWED_PHOTO_TYPES = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

function requireAssignment(req, res, next) {
  const { householdId, careRecipientId } = req.params;
  isCaregiverAssigned({ householdId, careRecipientId, uid: req.uid }).then((assigned) => {
    if (!assigned) {
      return res.status(403).json({ error: 'Not an active caregiver for this care recipient' });
    }
    next();
  });
}

// ── Manual entry CRUD ───────────────────────────────────────────────────────

// Manually entered by a real person, so it's already human-verified —
// unlike a photo scan (see /medications/upload-url + /process below), which
// per the schema must never be trusted without an explicit confirm step.
router.post(
  '/households/:householdId/care-recipients/:careRecipientId/medications',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;
    const { name, dosageText, strength, route, schedule, specialInstructions, reason } = req.body || {};

    if (!name || typeof name !== 'string' || !name.trim()) {
      return res.status(400).json({ error: 'name is required' });
    }
    if (!dosageText || typeof dosageText !== 'string' || !dosageText.trim()) {
      return res.status(400).json({ error: 'dosageText is required' });
    }

    const now = new Date();
    const ref = firebase.db
      .collection(`households/${householdId}/careRecipients/${careRecipientId}/medications`)
      .doc();

    await ref.set({
      name: name.trim(),
      genericName: null,
      strength: strength || null,
      dosageText: dosageText.trim(),
      route: route || null,
      schedule: schedule && typeof schedule === 'object' ? schedule : { times: [] },
      specialInstructions: specialInstructions || null,
      reason: reason || null,
      enteredByUid: req.uid,
      verifiedByUid: req.uid,
      verificationStatus: 'familyConfirmed',
      sourceType: 'familyEntry',
      sourceDocumentAssetId: null,
      ocrDraft: null,
      startsAt: now,
      endsAt: null,
      nextDoseAt: null,
      status: 'active',
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

    res.json({ medicationId: ref.id });
  },
);

router.get(
  '/households/:householdId/care-recipients/:careRecipientId/medications',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;

    const snap = await firebase.db
      .collection(`households/${householdId}/careRecipients/${careRecipientId}/medications`)
      .where('status', '==', 'active')
      .get();

    const medications = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    res.json({ medications });
  },
);

router.patch(
  '/households/:householdId/care-recipients/:careRecipientId/medications/:medicationId',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId, medicationId } = req.params;
    const { name, dosageText, strength, route, schedule, specialInstructions, reason } = req.body || {};

    const ref = firebase.db.doc(
      `households/${householdId}/careRecipients/${careRecipientId}/medications/${medicationId}`,
    );
    const snap = await ref.get();
    if (!snap.exists) {
      return res.status(404).json({ error: 'Medication not found' });
    }

    const update = { updatedAt: new Date(), updatedBy: req.uid };
    if (typeof name === 'string' && name.trim()) update.name = name.trim();
    if (typeof dosageText === 'string' && dosageText.trim()) update.dosageText = dosageText.trim();
    if (strength !== undefined) update.strength = strength;
    if (route !== undefined) update.route = route;
    if (schedule && typeof schedule === 'object') update.schedule = schedule;
    if (specialInstructions !== undefined) update.specialInstructions = specialInstructions;
    if (reason !== undefined) update.reason = reason;

    await ref.update(update);
    res.json({ ok: true });
  },
);

// Soft delete only — status: 'cancelled' (medications don't have an
// "archived" status in the schema's enum like careRecipients do;
// 'cancelled' is the closest fit) plus the softDelete mixin fields.
router.delete(
  '/households/:householdId/care-recipients/:careRecipientId/medications/:medicationId',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId, medicationId } = req.params;
    const ref = firebase.db.doc(
      `households/${householdId}/careRecipients/${careRecipientId}/medications/${medicationId}`,
    );
    const snap = await ref.get();
    if (!snap.exists) {
      return res.status(404).json({ error: 'Medication not found' });
    }

    await ref.update({
      status: 'cancelled',
      deletedAt: new Date(),
      deletedBy: req.uid,
    });
    res.json({ ok: true });
  },
);

// ── Photo scan ───────────────────────────────────────────────────────────────

router.post(
  '/households/:householdId/care-recipients/:careRecipientId/medications/upload-url',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;
    const { contentType } = req.body || {};

    const extension = ALLOWED_PHOTO_TYPES[contentType];
    if (!extension) {
      return res.status(400).json({
        error: `Unsupported contentType. Allowed: ${Object.keys(ALLOWED_PHOTO_TYPES).join(', ')}`,
      });
    }

    const medicationId = firebase.db
      .collection(`households/${householdId}/careRecipients/${careRecipientId}/medications`)
      .doc().id;

    const storagePath = `households/${householdId}/careRecipients/${careRecipientId}/medications/${medicationId}/label.${extension}`;

    const expiresAt = Date.now() + UPLOAD_URL_TTL_MS;
    const [uploadUrl] = await firebase
      .getBucket()
      .file(storagePath)
      .getSignedUrl({ version: 'v4', action: 'write', expires: expiresAt, contentType });

    res.json({ medicationId, uploadUrl, storagePath, expiresAt });
  },
);

// Caregiver's phone calls this once the raw PUT to the signed upload URL
// finishes. Generates a short-lived signed *read* URL (bucket stays private;
// OpenRouter needs an HTTPS-fetchable image), runs the vision model, and
// saves the result as a draft medication doc. Per the schema's own safety
// constraint ("never inferred solely from pill appearance"), this ALWAYS
// lands as verificationStatus: 'unverified' — /confirm below is the only
// way a scanned medication becomes active.
router.post(
  '/households/:householdId/care-recipients/:careRecipientId/medications/:medicationId/process',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId, medicationId } = req.params;
    const { storagePath } = req.body || {};

    if (!storagePath) {
      return res.status(400).json({ error: 'storagePath is required' });
    }

    try {
      const expiresAt = Date.now() + READ_URL_TTL_MS;
      const [imageUrl] = await firebase
        .getBucket()
        .file(storagePath)
        .getSignedUrl({ version: 'v4', action: 'read', expires: expiresAt });

      const draft = await extractMedicationLabel({ imageUrl });

      const now = new Date();
      const ref = firebase.db.doc(
        `households/${householdId}/careRecipients/${careRecipientId}/medications/${medicationId}`,
      );

      await ref.set({
        name: draft.name || 'Unlabeled medication',
        genericName: null,
        strength: draft.strength,
        dosageText: draft.dosageText || 'Not yet confirmed — review photo scan',
        route: draft.route,
        schedule: { times: draft.times },
        specialInstructions: draft.specialInstructions,
        reason: null,
        enteredByUid: req.uid,
        verifiedByUid: null,
        verificationStatus: 'unverified',
        sourceType: 'labelOcrDraft',
        sourceDocumentAssetId: storagePath,
        ocrDraft: draft,
        startsAt: now,
        endsAt: null,
        nextDoseAt: null,
        status: 'active',
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

      res.json({ medicationId, draft });
    } catch (err) {
      console.error('medication label scan failed:', err);
      res.status(502).json({ error: 'Label scan failed', detail: err.message });
    }
  },
);

// ── Confirm draft ────────────────────────────────────────────────────────────

// Caregiver reviews the OCR draft (editing any field first if needed) and
// confirms it — this is the human-in-the-loop step the schema requires
// before a scanned medication is trusted. Not called => stays 'unverified'
// forever, which is the safe default.
router.post(
  '/households/:householdId/care-recipients/:careRecipientId/medications/:medicationId/confirm',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId, medicationId } = req.params;
    const { name, dosageText, strength, route, schedule, specialInstructions, reason } = req.body || {};

    const ref = firebase.db.doc(
      `households/${householdId}/careRecipients/${careRecipientId}/medications/${medicationId}`,
    );
    const snap = await ref.get();
    if (!snap.exists) {
      return res.status(404).json({ error: 'Medication not found' });
    }

    const update = {
      verificationStatus: 'familyConfirmed',
      verifiedByUid: req.uid,
      updatedAt: new Date(),
      updatedBy: req.uid,
    };
    if (typeof name === 'string' && name.trim()) update.name = name.trim();
    if (typeof dosageText === 'string' && dosageText.trim()) update.dosageText = dosageText.trim();
    if (strength !== undefined) update.strength = strength;
    if (route !== undefined) update.route = route;
    if (schedule && typeof schedule === 'object') update.schedule = schedule;
    if (specialInstructions !== undefined) update.specialInstructions = specialInstructions;
    if (reason !== undefined) update.reason = reason;

    await ref.update(update);
    res.json({ ok: true });
  },
);

// ── Medication events (reminders) ───────────────────────────────────────────

// On-demand generation, no scheduler (same pragmatic call as the voice-log
// rollup). Idempotent: only creates events for (medicationId, time) pairs
// that don't already have one today — never overwrites an existing event,
// so a caregiver's already-recorded 'completed'/'skipped' can't be reset
// back to 'scheduled' by calling this again later in the day.
router.post(
  '/households/:householdId/care-recipients/:careRecipientId/medication-events/generate-today',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;
    const { start, end } = dayBoundsUtc(new Date().toISOString().slice(0, 10));

    // Filtering verificationStatus in memory rather than with a second
    // Firestore `where` — combining it with the `status` equality filter
    // needs a composite index, and per-recipient medication counts are
    // small enough that this isn't worth provisioning one for.
    const medsSnap = await firebase.db
      .collection(`households/${householdId}/careRecipients/${careRecipientId}/medications`)
      .where('status', '==', 'active')
      .get();
    const confirmedMedsDocs = medsSnap.docs.filter((doc) => doc.data().verificationStatus !== 'unverified');

    const eventsRef = firebase.db.collection(
      `households/${householdId}/careRecipients/${careRecipientId}/medicationEvents`,
    );
    const existingSnap = await eventsRef
      .where('scheduledAt', '>=', start)
      .where('scheduledAt', '<', end)
      .get();
    const existingKeys = new Set(
      existingSnap.docs.map((doc) => `${doc.data().medicationId}|${doc.data().scheduledAt.toDate().toISOString()}`),
    );

    const now = new Date();
    const batch = firebase.db.batch();
    let created = 0;

    for (const medDoc of confirmedMedsDocs) {
      const times = medDoc.data().schedule?.times || [];
      for (const time of times) {
        const [hh, mm] = time.split(':').map(Number);
        if (Number.isNaN(hh) || Number.isNaN(mm)) continue;

        const scheduledAt = new Date(start);
        scheduledAt.setUTCHours(hh, mm, 0, 0);
        const key = `${medDoc.id}|${scheduledAt.toISOString()}`;
        if (existingKeys.has(key)) continue;

        const ref = eventsRef.doc();
        batch.set(ref, {
          medicationId: medDoc.id,
          scheduledAt,
          windowStart: scheduledAt,
          windowEnd: scheduledAt,
          status: 'scheduled',
          completedByUid: null,
          completedAt: null,
          caregiverNote: null,
          refusalReason: null,
          idempotencyKey: key,
          generatedBy: 'manual',
          createdAt: now,
          createdBy: req.uid,
          updatedAt: now,
          updatedBy: req.uid,
        });
        created += 1;
      }
    }

    if (created > 0) await batch.commit();
    res.json({ created });
  },
);

router.get(
  '/households/:householdId/care-recipients/:careRecipientId/medication-events',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;
    const { start, end } = dayBoundsUtc(new Date().toISOString().slice(0, 10));

    const snap = await firebase.db
      .collection(`households/${householdId}/careRecipients/${careRecipientId}/medicationEvents`)
      .where('scheduledAt', '>=', start)
      .where('scheduledAt', '<', end)
      .get();

    // Firestore Timestamp's default toJSON() is {_seconds, _nanoseconds},
    // not an ISO string the client can DateTime.parse() — convert explicitly.
    const events = snap.docs.map((doc) => {
      const data = doc.data();
      return { id: doc.id, ...data, scheduledAt: data.scheduledAt.toDate().toISOString() };
    });
    res.json({ events });
  },
);

const EVENT_STATUSES = ['completed', 'skipped', 'refused', 'notAvailable', 'needsClarification'];

router.patch(
  '/households/:householdId/care-recipients/:careRecipientId/medication-events/:eventId',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId, eventId } = req.params;
    const { status, caregiverNote, refusalReason } = req.body || {};

    if (!EVENT_STATUSES.includes(status)) {
      return res.status(400).json({ error: `status must be one of: ${EVENT_STATUSES.join(', ')}` });
    }

    const ref = firebase.db.doc(
      `households/${householdId}/careRecipients/${careRecipientId}/medicationEvents/${eventId}`,
    );
    const snap = await ref.get();
    if (!snap.exists) {
      return res.status(404).json({ error: 'Medication event not found' });
    }

    await ref.update({
      status,
      completedByUid: req.uid,
      completedAt: new Date(),
      caregiverNote: caregiverNote || null,
      refusalReason: refusalReason || null,
      updatedAt: new Date(),
      updatedBy: req.uid,
    });
    res.json({ ok: true });
  },
);

module.exports = router;
module.exports.requireAssignment = requireAssignment;
