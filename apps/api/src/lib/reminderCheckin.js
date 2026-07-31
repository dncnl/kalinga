// F3 · Reminder-triggered structured check-ins.
//
// When an Eating or Exercise reminder fires, the caregiver gets a short
// category-specific question set instead of a blank box. The answers feed
// the SAME rollup/trend system the voice log already fills — `appetiteLevel`
// and `mobility` are existing observation concepts, so this is new input UI
// over existing backend behaviour, not a second analytics path.
//
// Any other label (Medication, or a custom one) gets no question set: it
// just completes, with an optional free note. Inventing questions for a
// label we know nothing about would produce meaningless trend data.

// `value` is what a tap means numerically, on the same 0..1 scale the LLM
// extractor already emits for voice logs, so the two sources are directly
// comparable in a chart. `label` is what the caregiver actually reads.
const CHECKIN_FORMS = {
  meal: {
    observationCategory: 'appetite',
    questions: [
      {
        id: 'howMuch',
        text: 'How much did she eat?',
        options: [
          { id: 'all', label: 'All of it', value: 1.0 },
          { id: 'most', label: 'Most', value: 0.75 },
          { id: 'half', label: 'About half', value: 0.5 },
          { id: 'little', label: 'A little', value: 0.25 },
          { id: 'none', label: 'Nothing', value: 0.0 },
        ],
      },
      {
        id: 'refused',
        text: 'Did she refuse or push the food away?',
        options: [
          { id: 'no', label: 'No', value: null },
          { id: 'yes', label: 'Yes', value: null },
        ],
      },
    ],
  },

  exercise: {
    observationCategory: 'mobility',
    questions: [
      {
        id: 'activity',
        text: 'What did she do?',
        options: [
          { id: 'walk', label: 'Walked', value: null },
          { id: 'chair', label: 'Chair exercises', value: null },
          { id: 'stand', label: 'Stood up and moved', value: null },
          { id: 'none', label: 'Nothing today', value: null },
        ],
      },
      {
        id: 'duration',
        text: 'For how long?',
        options: [
          { id: 'long', label: 'More than 30 minutes', value: 1.0 },
          { id: 'medium', label: '10 to 30 minutes', value: 0.7 },
          { id: 'short', label: 'Less than 10 minutes', value: 0.4 },
          { id: 'none', label: 'Did not move', value: 0.0 },
        ],
      },
      {
        id: 'difficulty',
        text: 'Was it harder for her than usual?',
        options: [
          { id: 'no', label: 'No, the same', value: null },
          { id: 'yes', label: 'Yes, harder', value: null },
        ],
      },
    ],
  },
};

function optionOf(form, questionId, answerId) {
  const question = form.questions.find((q) => q.id === questionId);
  if (!question) return null;
  return question.options.find((o) => o.id === answerId) || null;
}

/// The 0..1 scores this check-in contributes. Only the dimension the
/// caregiver was actually asked about is set; everything else stays at the
/// neutral 0.5 the extractor uses for "not mentioned", so answering about
/// lunch never fabricates a sleep score.
function scoresFor({ category, answers }) {
  const scores = { sleepQuality: 0.5, appetiteLevel: 0.5, moodScore: 0.5 };
  const form = CHECKIN_FORMS[category];
  if (!form) return scores;

  if (category === 'meal') {
    const option = optionOf(form, 'howMuch', answers.howMuch);
    if (option && option.value !== null) scores.appetiteLevel = option.value;
    // A refusal is a real appetite signal even when she ate something.
    if (answers.refused === 'yes') {
      scores.appetiteLevel = Math.min(scores.appetiteLevel, 0.25);
    }
  }

  if (category === 'exercise') {
    const option = optionOf(form, 'duration', answers.duration);
    // There is no mobility score in the extractor's schema, so this is
    // recorded as a plain field rather than forced into one of the three
    // existing scores — where it would be read as something it isn't.
    if (option && option.value !== null) scores.mobilityLevel = option.value;
    if (answers.difficulty === 'yes') scores.mobilityHarderThanUsual = true;
  }

  return scores;
}

/// Plain sentence, written the way a caregiver would say it, so it reads
/// naturally beside voice logs and survives machine translation.
function buildCheckinSummary({ category, taskTitle, answers, note }) {
  const form = CHECKIN_FORMS[category];
  const parts = [`${taskTitle}:`];

  if (form) {
    for (const question of form.questions) {
      const option = optionOf(form, question.id, answers[question.id]);
      if (!option) continue;

      if (category === 'meal' && question.id === 'howMuch') {
        parts.push(`she ate ${option.label.toLowerCase()}.`);
      } else if (category === 'meal' && question.id === 'refused') {
        if (option.id === 'yes') parts.push('She refused or pushed the food away.');
      } else if (category === 'exercise' && question.id === 'activity') {
        parts.push(`${option.label.toLowerCase()}.`);
      } else if (category === 'exercise' && question.id === 'duration') {
        parts.push(`${option.label}.`);
      } else if (category === 'exercise' && question.id === 'difficulty') {
        if (option.id === 'yes') parts.push('It was harder for her than usual.');
      }
    }
  }

  if (parts.length === 1) parts.push('done.');
  if (note && note.trim()) parts.push(`Caregiver also said: ${note.trim()}`);

  return parts.join(' ');
}

module.exports = { CHECKIN_FORMS, scoresFor, buildCheckinSummary, optionOf };
