const { Router } = require('express');

const firebase = require('../firebase');
const { requireAuth } = require('../middleware/auth');
const { isCaregiverAssigned } = require('../lib/authorizeCaregiver');
// Namespace require (not destructured) so tests can mock
// translate.translateToMandarin directly.
const translate = require('../lib/translate');
const { buildObservationDocument } = require('../lib/buildObservationDocument');
const { timestampId } = require('../lib/readableId');
const chatConcern = require('../lib/chatConcern');
const rollupDailySummary = require('../lib/rollupDailySummary');
const rollupWeeklySummary = require('../lib/rollupWeeklySummary');
const { currentWeekKey, currentWeekStartUtc, dateKeyOf } = require('../lib/weekKey');
const { answerQuestion } = require('../rag/answer');

const router = Router();

// Not household-scoped — this is shared reference knowledge (health
// authority guidelines), not care-record data — so just requireAuth (stop
// anonymous abuse of the LLM call), no assignment check.
router.post('/rag/ask', requireAuth, async (req, res) => {
  const { question } = req.body || {};

  if (!question || typeof question !== 'string' || !question.trim()) {
    return res.status(400).json({ error: 'question is required' });
  }

  try {
    const result = await answerQuestion(question.trim());
    res.json(result);
  } catch (err) {
    console.error('rag ask failed:', err);
    res.status(502).json({ error: 'Failed to answer question', detail: err.message });
  }
});

// F1 · Free-text chat symptom checker.
//
// Coexists with, does not replace, the tap-based triage in observations.js
// (`/observations/symptom-check`). That route stays the only thing that
// decides urgency, for the reasons in symptomTriage.js. This route answers
// open-ended questions the same way /rag/ask does (grounded, multilingual),
// but scoped to a care recipient so the exchange can be recorded for the
// family and translated to Mandarin — the "auto-translating and flagging
// urgency to family in Mandarin" MVP requirement /rag/ask never covered.
//
// `concern` is a soft, deterministic keyword nudge (lib/chatConcern.js), not
// a model guessing at urgency — it only ever suggests the tap-based flow or
// 119, it never itself asserts an urgency level.
router.post(
  '/households/:householdId/care-recipients/:careRecipientId/rag/ask',
  requireAuth,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;
    const { question, locale } = req.body || {};

    if (!question || typeof question !== 'string' || !question.trim()) {
      return res.status(400).json({ error: 'question is required' });
    }
    if (!locale || !translate.TRANSLATE_LANGUAGE_CODES[locale]) {
      return res.status(400).json({
        error: `locale is required and must be one of: ${Object.keys(translate.TRANSLATE_LANGUAGE_CODES).join(', ')}`,
      });
    }

    const assigned = await isCaregiverAssigned({ householdId, careRecipientId, uid: req.uid });
    if (!assigned) {
      return res.status(403).json({ error: 'Not an active caregiver for this care recipient' });
    }

    const trimmedQuestion = question.trim();

    let result;
    try {
      result = await answerQuestion(trimmedQuestion);
    } catch (err) {
      console.error('rag ask (scoped) failed:', err);
      return res.status(502).json({ error: 'Failed to answer question', detail: err.message });
    }

    const concern = chatConcern.detectConcern(trimmedQuestion);
    const summaryText = `Caregiver asked: ${trimmedQuestion}\n\nAnswer: ${result.answer}`;

    // As in symptom-check: translation failure must not lose the exchange —
    // it's still recorded, just untranslated, with the error surfaced.
    let translatedText = null;
    let translationError = null;
    try {
      ({ text: translatedText } = await translate.translateToMandarin({
        text: summaryText,
        sourceLocale: locale,
        projectId: firebase.projectId,
      }));
    } catch (err) {
      translationError = err.message;
      console.error('rag ask (scoped): translation failed, storing untranslated:', err);
    }

    const observationId = timestampId();
    const observationRef = firebase.db.doc(
      `households/${householdId}/careRecipients/${careRecipientId}/observations/${observationId}`,
    );

    const observationDoc = buildObservationDocument({
      uid: req.uid,
      locale,
      transcript: summaryText,
      translatedText: translatedText ?? summaryText,
      inputMode: 'text',
      extraction: {
        categories: [concern ? concern.category : 'other'],
        comparisonToUsual: 'unknown',
        structuredObservation: {
          summary: summaryText,
          // Neutral: a Q&A exchange doesn't observe sleep/appetite/mood, so
          // these stay at 0.5 rather than inventing a trend data point.
          sleepQuality: 0.5,
          appetiteLevel: 0.5,
          moodScore: 0.5,
        },
        safetyAssessment: {
          // Capped at 'medium': this route never asserts 'high' (emergency)
          // — that judgement stays exclusive to symptomTriage.js.
          concernLevel: concern ? 'medium' : 'low',
          concerns: concern ? [`Caregiver asked about: ${concern.label}`] : [],
          recommendFollowUp: !!concern,
        },
      },
    });
    if (translationError) observationDoc.processingError = translationError;

    await observationRef.set(observationDoc);

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

    res.json({
      observationId,
      answer: result.answer,
      sources: result.sources,
      translatedText,
      concern: concern && {
        symptomKey: concern.symptomKey,
        label: concern.label,
        // Deliberately not an urgency or an action ("call 119" / "watch") —
        // only symptomTriage.js's tap-based flow may say that. This just
        // routes the caregiver there.
        message: `This sounds like it could be "${concern.label}" — use the symptom check for a clear next step.`,
      },
    });
  },
);

module.exports = router;
