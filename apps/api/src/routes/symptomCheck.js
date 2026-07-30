const { Router } = require('express');

const firebase = require('../firebase');
const { requireAuth } = require('../middleware/auth');
const { isCaregiverAssigned } = require('../lib/authorizeCaregiver');
const { answerSymptomCheck, LOCALE_NAMES } = require('../rag/answer');
const { classifyUrgency } = require('../rag/classifyUrgency');
const { translateToMandarin, translateToEnglish } = require('../lib/translate');

const router = Router();

// Family/doctor get flagged, not every household member — matches
// HouseholdRole's family-facing/clinical roles.
const ALERT_RECIPIENT_ROLES = ['householdAdmin', 'family', 'clinician'];
const ALERT_URGENCY_LEVELS = ['urgent', 'emergency'];

function requireAssignment(req, res, next) {
  const { householdId, careRecipientId } = req.params;
  isCaregiverAssigned({ householdId, careRecipientId, uid: req.uid }).then((assigned) => {
    if (!assigned) {
      return res.status(403).json({ error: 'Not an active caregiver for this care recipient' });
    }
    next();
  });
}

async function alertRecipientUids(householdId) {
  const snap = await firebase.db
    .collection(`households/${householdId}/members`)
    .where('status', '==', 'active')
    .where('role', 'in', ALERT_RECIPIENT_ROLES)
    .get();
  return snap.docs.map((doc) => doc.id);
}

router.post(
  '/households/:householdId/care-recipients/:careRecipientId/symptom-check',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;
    const { message, locale } = req.body || {};

    if (!message || typeof message !== 'string' || !message.trim()) {
      return res.status(400).json({ error: 'message is required' });
    }
    if (!LOCALE_NAMES[locale]) {
      return res.status(400).json({
        error: `locale "${locale}" is not supported. Allowed: ${Object.keys(LOCALE_NAMES).join(', ')}`,
      });
    }

    try {
      const trimmedMessage = message.trim();

      // English translation feeds RAG retrieval (the corpus is
      // English-only — see answer.js's retrievalQuery note); Mandarin
      // translation feeds the family/doctor summary. Independent, so run
      // both up front in parallel.
      const [{ text: retrievalQuery }, { text: familySummaryZh }] = await Promise.all([
        translateToEnglish({ text: trimmedMessage, sourceLocale: locale, projectId: firebase.projectId }),
        translateToMandarin({ text: trimmedMessage, sourceLocale: locale, projectId: firebase.projectId }),
      ]);

      const { answer, sources } = await answerSymptomCheck({ message: trimmedMessage, locale, retrievalQuery });

      const { urgency } = await classifyUrgency({ message: trimmedMessage, answer });

      const now = new Date();
      const ref = firebase.db
        .collection(`households/${householdId}/careRecipients/${careRecipientId}/symptomChecks`)
        .doc();

      let alertId = null;
      if (ALERT_URGENCY_LEVELS.includes(urgency)) {
        const recipientUids = await alertRecipientUids(householdId);
        const alertRef = firebase.db
          .collection(`households/${householdId}/careRecipients/${careRecipientId}/alerts`)
          .doc();

        await alertRef.set({
          type: 'emergency',
          severity: urgency,
          sourceEntityPath: ref.path,
          recipientUids,
          title: urgency === 'emergency' ? 'Possible emergency reported' : 'Caregiver flagged a concern',
          message: familySummaryZh,
          recommendedServiceId: null,
          status: 'active',
          acknowledgedByUid: null,
          acknowledgedAt: null,
          resolvedByUid: null,
          resolvedAt: null,
          expiresAt: null,
          deduplicationKey: ref.id,
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
        alertId = alertRef.id;
      }

      await ref.set({
        locale,
        messageText: trimmedMessage,
        answerText: answer,
        sources,
        urgency,
        familySummaryZh,
        alertId,
        askedByUid: req.uid,
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

      res.json({
        symptomCheckId: ref.id,
        answer,
        sources,
        urgency,
        familySummaryZh,
        alertId,
        flaggedToFamily: alertId !== null,
      });
    } catch (err) {
      console.error('symptom check failed:', err);
      res.status(502).json({ error: 'Symptom check failed', detail: err.message });
    }
  },
);

router.get(
  '/households/:householdId/care-recipients/:careRecipientId/symptom-check',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;

    const snap = await firebase.db
      .collection(`households/${householdId}/careRecipients/${careRecipientId}/symptomChecks`)
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();

    const symptomChecks = snap.docs.map((doc) => {
      const data = doc.data();
      return { id: doc.id, ...data, createdAt: data.createdAt.toDate().toISOString() };
    });
    res.json({ symptomChecks });
  },
);

module.exports = router;
module.exports.requireAssignment = requireAssignment;
