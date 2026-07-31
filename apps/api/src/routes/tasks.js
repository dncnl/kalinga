const { Router } = require('express');

const firebase = require('../firebase');
const { requireAuth } = require('../middleware/auth');
const { requireAssignment } = require('./medications');
const { dayBoundsUtc } = require('../lib/rollupDailySummary');
const { slugId, timestampId } = require('../lib/readableId');
const { translateToMandarin } = require('../lib/translate');
const { buildObservationDocument } = require('../lib/buildObservationDocument');
const { buildCheckinSummary, CHECKIN_FORMS, scoresFor } = require('../lib/reminderCheckin');
const rollupDailySummary = require('../lib/rollupDailySummary');
const rollupWeeklySummary = require('../lib/rollupWeeklySummary');
const { currentWeekKey, currentWeekStartUtc, dateKeyOf } = require('../lib/weekKey');

const router = Router();

// F2 · Labeled reminders.
//
// Reuses the schema's existing tasks/taskEvents pair rather than modelling
// anything new — same definition + materialized-occurrence split the
// medication reminders already use, so "generate today's occurrences and
// list them" works identically here (see medications.js's
// medication-events/generate-today, which this mirrors deliberately).
//
// The caregiver's label maps onto the schema's TaskCategory enum: Eating →
// meal, Exercise → exercise, Medication → medication, anything else →
// other, with the typed label kept in `title`.
const TASK_CATEGORIES = ['meal', 'exercise', 'medication', 'hydration', 'hygiene', 'mobility', 'other'];

// Real clock times only. `\d{2}:\d{2}` would accept "25:99", and the
// generate-today loop's setUTCHours would roll that into the next day —
// a reminder at a time nobody set. Same guard as extractMedicationLabel.
const CLOCK_TIME = /^([01]\d|2[0-3]):([0-5]\d)$/;

router.post(
  '/households/:householdId/care-recipients/:careRecipientId/tasks',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;
    const { title, category, times, timezone } = req.body || {};

    if (!title || typeof title !== 'string' || !title.trim()) {
      return res.status(400).json({ error: 'title is required' });
    }
    if (!TASK_CATEGORIES.includes(category)) {
      return res.status(400).json({ error: `category must be one of: ${TASK_CATEGORIES.join(', ')}` });
    }
    const cleanTimes = Array.isArray(times)
      ? times.filter((t) => typeof t === 'string' && CLOCK_TIME.test(t))
      : [];
    if (cleanTimes.length === 0) {
      return res.status(400).json({ error: 'times must contain at least one "HH:MM" entry' });
    }

    const now = new Date();
    const ref = firebase.db
      .collection(`households/${householdId}/careRecipients/${careRecipientId}/tasks`)
      .doc(slugId(title));

    await ref.set({
      title: title.trim(),
      description: null,
      category,
      createdByUid: req.uid,
      assignedToUids: [req.uid],
      carePlanId: null,
      instructionId: null,
      timezone: timezone || 'UTC',
      schedule: { times: cleanTimes },
      nextDueAt: null,
      // Eating and exercise reminders open a short question set when they
      // fire (F3), which is a note in substance — but it is collected by
      // its own flow rather than enforced on the taskEvent, so this stays
      // false and the check-in remains skippable.
      completionRequiresNote: false,
      completionRequiresMeasurementType: null,
      status: 'active',
      startsAt: now,
      endsAt: null,
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

    res.json({ taskId: ref.id });
  },
);

router.get(
  '/households/:householdId/care-recipients/:careRecipientId/tasks',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;
    const snap = await firebase.db
      .collection(`households/${householdId}/careRecipients/${careRecipientId}/tasks`)
      .where('status', '==', 'active')
      .get();
    res.json({ tasks: snap.docs.map((doc) => ({ id: doc.id, ...doc.data() })) });
  },
);

router.delete(
  '/households/:householdId/care-recipients/:careRecipientId/tasks/:taskId',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId, taskId } = req.params;
    // Soft-cancel, matching how medications are retired: past taskEvents
    // stay meaningful history, so the definition must not vanish.
    await firebase.db
      .doc(`households/${householdId}/careRecipients/${careRecipientId}/tasks/${taskId}`)
      .update({ status: 'cancelled', updatedAt: new Date(), updatedBy: req.uid });
    res.json({ ok: true });
  },
);

// Generate today's occurrences and return the full list in one round trip —
// same shape and reasoning as medication-events/generate-today.
router.post(
  '/households/:householdId/care-recipients/:careRecipientId/task-events/generate-today',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;
    const { start, end } = dayBoundsUtc(new Date().toISOString().slice(0, 10));

    const eventsRef = firebase.db.collection(
      `households/${householdId}/careRecipients/${careRecipientId}/taskEvents`,
    );

    const [tasksSnap, existingSnap] = await Promise.all([
      firebase.db
        .collection(`households/${householdId}/careRecipients/${careRecipientId}/tasks`)
        .where('status', '==', 'active')
        .get(),
      eventsRef.where('scheduledAt', '>=', start).where('scheduledAt', '<', end).get(),
    ]);

    const existingKeys = new Set(
      existingSnap.docs.map((doc) => `${doc.data().taskId}|${doc.data().scheduledAt.toDate().toISOString()}`),
    );

    const now = new Date();
    const batch = firebase.db.batch();
    let created = 0;

    const serialize = (id, data) => ({
      id,
      ...data,
      scheduledAt: data.scheduledAt instanceof Date
        ? data.scheduledAt.toISOString()
        : data.scheduledAt.toDate().toISOString(),
    });

    const events = existingSnap.docs.map((doc) => serialize(doc.id, doc.data()));

    for (const taskDoc of tasksSnap.docs) {
      const task = taskDoc.data();
      for (const time of task.schedule?.times || []) {
        const [hh, mm] = time.split(':').map(Number);
        if (Number.isNaN(hh) || Number.isNaN(mm)) continue;

        const scheduledAt = new Date(start);
        scheduledAt.setUTCHours(hh, mm, 0, 0);
        const key = `${taskDoc.id}|${scheduledAt.toISOString()}`;
        if (existingKeys.has(key)) continue;

        const ref = eventsRef.doc(timestampId(scheduledAt));
        const eventData = {
          taskId: taskDoc.id,
          // Denormalized so the phone can render the reminder list without
          // a second read per event; the task doc stays the source of truth.
          taskTitle: task.title,
          taskCategory: task.category,
          scheduledAt,
          windowStart: scheduledAt,
          windowEnd: scheduledAt,
          assignedToUids: task.assignedToUids || [req.uid],
          status: 'pending',
          completedByUid: null,
          completedAt: null,
          caregiverNote: null,
          relatedObservationId: null,
          relatedMeasurementId: null,
          idempotencyKey: key,
          generatedBy: 'manual',
          createdAt: now,
          createdBy: req.uid,
          updatedAt: now,
          updatedBy: req.uid,
          deletedAt: null,
          deletedBy: null,
          deletionReason: null,
          retentionUntil: null,
          legalHold: false,
          clientGeneratedId: null,
          clientCreatedAt: null,
          lastModifiedByDeviceId: null,
          version: 1,
          syncState: 'server',
        };
        batch.set(ref, eventData);
        events.push(serialize(ref.id, eventData));
        created += 1;
      }
    }

    if (created > 0) await batch.commit();
    events.sort((a, b) => a.scheduledAt.localeCompare(b.scheduledAt));
    res.json({ created, events });
  },
);

// F3 · Completing a reminder, optionally with its structured check-in.
//
// Eating and exercise reminders collect a short category-specific answer
// set; anything else just completes (with an optional free note). When
// answers are present they become an observation via the SAME builder and
// rollups the voice log uses, so `appetiteLevel` / `mobility` land in the
// existing trend charts rather than in a parallel analytics system. The
// schema's `relatedObservationId` on taskEvent is what links the two.
router.post(
  '/households/:householdId/care-recipients/:careRecipientId/task-events/:eventId/complete',
  requireAuth,
  requireAssignment,
  async (req, res) => {
    const { householdId, careRecipientId, eventId } = req.params;
    const { status, answers, note, locale } = req.body || {};

    if (!['completed', 'skipped'].includes(status || 'completed')) {
      return res.status(400).json({ error: "status must be 'completed' or 'skipped'" });
    }

    const eventRef = firebase.db.doc(
      `households/${householdId}/careRecipients/${careRecipientId}/taskEvents/${eventId}`,
    );
    const eventSnap = await eventRef.get();
    if (!eventSnap.exists) {
      return res.status(404).json({ error: 'Reminder not found' });
    }
    const event = eventSnap.data();

    let observationId = null;
    const form = CHECKIN_FORMS[event.taskCategory];
    const hasAnswers = form && answers && typeof answers === 'object' && Object.keys(answers).length > 0;

    if (hasAnswers || (note && note.trim())) {
      const summaryText = buildCheckinSummary({
        category: event.taskCategory,
        taskTitle: event.taskTitle,
        answers: answers || {},
        note,
      });

      // Same trade as the symptom check-in: a translation outage must not
      // cost us the observation itself.
      let translatedText = null;
      try {
        ({ text: translatedText } = await translateToMandarin({
          text: summaryText,
          sourceLocale: locale || 'fil',
          projectId: firebase.projectId,
        }));
      } catch (err) {
        console.error('task check-in: translation failed, storing untranslated:', err);
      }

      observationId = timestampId();
      await firebase.db
        .doc(`households/${householdId}/careRecipients/${careRecipientId}/observations/${observationId}`)
        .set(
          buildObservationDocument({
            uid: req.uid,
            locale: locale || 'fil',
            transcript: summaryText,
            translatedText: translatedText ?? summaryText,
            inputMode: 'structuredForm',
            extraction: {
              categories: [form ? form.observationCategory : 'other'],
              comparisonToUsual: 'unknown',
              structuredObservation: {
                summary: summaryText,
                taskEventId: eventId,
                ...scoresFor({ category: event.taskCategory, answers: answers || {} }),
              },
              safetyAssessment: {
                concernLevel: 'none',
                concerns: [],
                recommendFollowUp: false,
              },
            },
          }),
        );
    }

    await eventRef.update({
      status: status || 'completed',
      completedByUid: req.uid,
      completedAt: new Date(),
      caregiverNote: note?.trim() || null,
      relatedObservationId: observationId,
      updatedAt: new Date(),
      updatedBy: req.uid,
    });

    if (observationId) {
      await Promise.all([
        rollupDailySummary.computeAndSaveDailySummary({
          householdId,
          careRecipientId,
          dateKey: dateKeyOf(new Date()),
        }),
        rollupWeeklySummary.computeAndSaveWeeklySummary({
          householdId,
          careRecipientId,
          weekKey: currentWeekKey(),
          periodStart: currentWeekStartUtc().toISOString(),
        }),
      ]);
    }

    res.json({ ok: true, observationId });
  },
);

module.exports = router;
module.exports.TASK_CATEGORIES = TASK_CATEGORIES;
