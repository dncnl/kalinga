// F1 · Deterministic symptom triage.
//
// This file decides urgency. Nothing else does — in particular no LLM does.
// The caregiver taps fixed answers, and a fixed rule maps those answers to
// one of three actions. That is the whole point of the feature: a chatbot
// asked "is this an emergency?" can hallucinate a reassuring answer, and
// here that failure mode is somebody not calling 119. The schema anticipates
// this too (`safetyRuleSets`: "versioned deterministic routing and escalation
// rules; no autonomous diagnosis").
//
// The RAG layer is still used, but only for *what to do while you wait* —
// it cannot change the urgency computed here. See routes/observations.js.
//
// Scope: six red flags that actually change what a home caregiver should do
// in the next hour. Deliberately not a differential-diagnosis list. Anything
// outside these six belongs in the general voice log.

const URGENCY = {
  emergency: 'emergency', // call 119 now
  today: 'today', // tell family, seek care today
  watch: 'watch', // keep watching, log it
};

// concernLevel is the schema's existing SafetyAssessment vocabulary, so
// these observations roll up alongside voice logs without special-casing.
const URGENCY_TO_CONCERN_LEVEL = {
  [URGENCY.emergency]: 'high',
  [URGENCY.today]: 'medium',
  [URGENCY.watch]: 'low',
};

// Each symptom: the question set the caregiver taps through, plus the rule
// that turns those answers into an urgency. `redFlag: true` answers escalate
// straight to emergency — when in doubt these err upward, because the cost
// of an unnecessary ambulance call is far lower than the cost of a missed
// stroke or a head bleed.
//
// `statement` is what a "yes" MEANS, written as a fact. The summary is
// built from these rather than from the question text, because the summary
// gets machine-translated for the family: "Yes: did she hit her head?" is
// confusing in English and worse in Mandarin, while "She hit her head."
// survives translation intact.
const SYMPTOMS = {
  breathing: {
    label: 'Hard to breathe',
    category: 'breathing',
    questions: [
      { id: 'atRest', text: 'Is she struggling to breathe even while sitting still?', statement: 'She struggles to breathe even at rest.', redFlag: true },
      { id: 'blueLips', text: 'Are her lips, face, or fingertips turning blue or grey?', statement: 'Her lips, face, or fingertips are turning blue or grey.', redFlag: true },
      { id: 'cannotSpeak', text: 'Is she too breathless to finish a sentence?', statement: 'She is too breathless to finish a sentence.', redFlag: true },
    ],
    // Breathing difficulty that is new but only on exertion still needs
    // same-day care in an elder — never "watch".
    baseline: URGENCY.today,
  },

  chestPain: {
    label: 'Chest pain',
    category: 'pain',
    questions: [
      { id: 'now', text: 'Is the chest pain happening right now?', statement: 'The chest pain is happening right now.', redFlag: true },
      { id: 'spreading', text: 'Does the pain spread to the arm, neck, or jaw?', statement: 'The pain spreads to her arm, neck, or jaw.', redFlag: true },
      { id: 'sweatingPale', text: 'Is she sweating, very pale, or vomiting?', statement: 'She is sweating, very pale, or vomiting.', redFlag: true },
    ],
    // Chest pain that has already passed still gets seen today.
    baseline: URGENCY.today,
  },

  fall: {
    label: 'She fell down',
    category: 'fall',
    questions: [
      { id: 'hitHead', text: 'Did she hit her head?', statement: 'She hit her head.', redFlag: true },
      { id: 'cannotStand', text: 'Is she unable to stand or move an arm or leg?', statement: 'She cannot stand or move an arm or leg.', redFlag: true },
      { id: 'severePain', text: 'Is she in severe pain, or is a limb bent oddly?', statement: 'She is in severe pain, or a limb is bent oddly.', redFlag: true },
    ],
    // Every fall in an elder gets reported the same day even when she seems
    // fine — slow bleeds and hairline fractures show up hours later.
    baseline: URGENCY.today,
  },

  confusion: {
    label: 'More confused than usual',
    category: 'behavior',
    questions: [
      { id: 'suddenToday', text: 'Did this start suddenly, today?', statement: 'The confusion started suddenly, today.', redFlag: true },
      { id: 'faceArmSpeech', text: 'Is her face drooping, one arm weak, or her speech slurred?', statement: 'Her face is drooping, one arm is weak, or her speech is slurred.', redFlag: true },
      { id: 'hardToWake', text: 'Is she very sleepy or hard to wake?', statement: 'She is very sleepy or hard to wake.', redFlag: true },
    ],
    baseline: URGENCY.today,
  },

  fever: {
    label: 'Fever / very hot',
    category: 'vitalSigns',
    questions: [
      { id: 'hardToWake', text: 'Is she very sleepy or hard to wake?', statement: 'She is very sleepy or hard to wake.', redFlag: true },
      { id: 'breathingFast', text: 'Is she breathing much faster than usual?', statement: 'She is breathing much faster than usual.', redFlag: true },
      { id: 'moreThanTwoDays', text: 'Has the fever lasted more than two days?', statement: 'The fever has lasted more than two days.', redFlag: false },
    ],
    // Fever in an older adult is treated as same-day by default: they often
    // run little or no fever even with serious infection, so any fever is a
    // stronger signal than it would be in a younger person.
    baseline: URGENCY.today,
  },

  notEating: {
    label: 'Not eating or drinking',
    category: 'appetite',
    questions: [
      { id: 'noDrinkOneDay', text: 'Has she had almost nothing to drink for a whole day?', statement: 'She has had almost nothing to drink for a whole day.', redFlag: false },
      { id: 'weakDizzy', text: 'Is she very weak, dizzy, or confused with it?', statement: 'She is very weak, dizzy, or confused with it.', redFlag: true },
      { id: 'cannotSwallow', text: 'Does she cough or choke when swallowing?', statement: 'She coughs or chokes when swallowing.', redFlag: false },
    ],
    baseline: URGENCY.watch,
  },
};

// Deterministic: any red-flag "yes" ⇒ emergency. Otherwise any "yes" at all
// lifts the symptom's baseline one step (watch → today); a clean sheet stays
// at the baseline.
function assessSymptom({ symptomKey, answers }) {
  const symptom = SYMPTOMS[symptomKey];
  if (!symptom) {
    throw new Error(`Unknown symptom: ${symptomKey}`);
  }

  const normalized = answers && typeof answers === 'object' ? answers : {};
  const yes = (id) => normalized[id] === true;

  const redFlagged = symptom.questions.filter((q) => q.redFlag && yes(q.id));
  const anyYes = symptom.questions.some((q) => yes(q.id));

  let urgency;
  if (redFlagged.length > 0) {
    urgency = URGENCY.emergency;
  } else if (anyYes && symptom.baseline === URGENCY.watch) {
    urgency = URGENCY.today;
  } else {
    urgency = symptom.baseline;
  }

  // Statements, not questions — these end up in the family's translated
  // summary (see the `statement` note above).
  const concerns = symptom.questions.filter((q) => yes(q.id)).map((q) => q.statement);

  return {
    urgency,
    concernLevel: URGENCY_TO_CONCERN_LEVEL[urgency],
    category: symptom.category,
    label: symptom.label,
    concerns,
    recommendFollowUp: urgency !== URGENCY.watch,
  };
}

// Plain-language, action-first. The caregiver reads this while stressed, so
// it says what to DO, not what the condition might be — no diagnosis.
const ACTION_TEXT = {
  [URGENCY.emergency]: 'Call 119 now. Stay with her until help arrives.',
  [URGENCY.today]: 'Tell the family today and arrange to see a doctor today.',
  [URGENCY.watch]: 'Keep watching her. Log it again if it does not improve.',
};

// The note that gets stored and translated. Reads as something a caregiver
// actually said, so it sits naturally next to voice logs in the same feed.
function buildSummaryText({ symptomKey, answers, note }) {
  const symptom = SYMPTOMS[symptomKey];
  const assessment = assessSymptom({ symptomKey, answers });

  const lines = [`Check-in: ${symptom.label}.`];
  if (assessment.concerns.length > 0) {
    lines.push(assessment.concerns.join(' '));
  } else {
    lines.push('No warning signs reported.');
  }
  if (note && note.trim()) {
    lines.push(`Caregiver also said: ${note.trim()}`);
  }
  lines.push(ACTION_TEXT[assessment.urgency]);

  return lines.join(' ');
}

module.exports = {
  SYMPTOMS,
  URGENCY,
  URGENCY_TO_CONCERN_LEVEL,
  ACTION_TEXT,
  assessSymptom,
  buildSummaryText,
};
