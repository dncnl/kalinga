const llmClient = require('./llmClient');

const OBSERVATION_CATEGORIES = [
  'appetite', 'hydration', 'sleep', 'mood', 'behavior', 'mobility', 'pain',
  'elimination', 'medication', 'vitalSigns', 'skin', 'breathing', 'fall', 'other',
];

// Common words the model reaches for that aren't literally in
// OBSERVATION_CATEGORIES but map cleanly onto one.
const CATEGORY_SYNONYMS = {
  energy: 'mobility',
  fatigue: 'mobility',
  tired: 'mobility',
  tiredness: 'mobility',
  eating: 'appetite',
  food: 'appetite',
  nutrition: 'appetite',
  water: 'hydration',
  drinking: 'hydration',
  emotion: 'mood',
  emotional: 'mood',
  wellbeing: 'mood',
  'well-being': 'mood',
  movement: 'mobility',
  falls: 'fall',
  medicine: 'medication',
  meds: 'medication',
  toilet: 'elimination',
  bathroom: 'elimination',
};

function normalizeCategories(rawCategories) {
  if (!Array.isArray(rawCategories)) return [];

  const normalized = rawCategories.map((raw) => {
    const key = String(raw).trim().toLowerCase();
    if (OBSERVATION_CATEGORIES.includes(key)) return key;
    if (CATEGORY_SYNONYMS[key]) return CATEGORY_SYNONYMS[key];
    return 'other';
  });

  return [...new Set(normalized)];
}

// Clamps to [0, 1] and drops anything that isn't actually a number.
function normalizeScore(value) {
  if (typeof value === 'string') value = parseFloat(value);
  if (typeof value !== 'number' || Number.isNaN(value)) return null;
  return Math.max(0, Math.min(1, value));
}

function normalizeStructuredObservation(structuredObservation = {}) {
  return {
    ...structuredObservation,
    sleepQuality: normalizeScore(structuredObservation.sleepQuality),
    appetiteLevel: normalizeScore(structuredObservation.appetiteLevel),
    moodScore: normalizeScore(structuredObservation.moodScore),
  };
}

// JSON Schema passed as responseJsonSchema — Gemini enforces this
// structurally (via generateStructured), so this schema is doing real
// work now, not just documentation.
const EXTRACT_SCHEMA = {
  type: 'object',
  properties: {
    categories: {
      type: 'array',
      items: { type: 'string' },
      description: `Which aspects of care this note touches on. Use these words when they fit: ${OBSERVATION_CATEGORIES.join(', ')}.`,
    },
    comparisonToUsual: {
      type: 'string',
      enum: ['better', 'same', 'worse', 'unknown'],
      description: "How the elder's condition compares to their usual baseline.",
    },
    structuredObservation: {
      type: 'object',
      properties: {
        summary: { type: 'string' },
        sleep: { type: 'string' },
        appetite: { type: 'string' },
        mood: { type: 'string' },
        sleepQuality: { type: 'number', description: '0 (very poor) to 1 (excellent).' },
        appetiteLevel: { type: 'number', description: '0 (refused to eat) to 1 (ate well).' },
        moodScore: { type: 'number', description: '0 (very distressed) to 1 (content/happy).' },
      },
      required: ['summary'],
    },
    safetyAssessment: {
      type: 'object',
      properties: {
        concernLevel: { type: 'string', enum: ['none', 'low', 'medium', 'high'] },
        concerns: { type: 'array', items: { type: 'string' } },
        recommendFollowUp: { type: 'boolean' },
      },
      required: ['concernLevel', 'concerns', 'recommendFollowUp'],
    },
  },
  required: ['categories', 'comparisonToUsual', 'structuredObservation', 'safetyAssessment'],
};

const SYSTEM_PROMPT = `You are a medical data extraction assistant.
A caregiver recorded a voice note about an elder. Extract the details described in the transcript.

CRITICAL INSTRUCTIONS:
1. You MUST analyze the entire transcript. Do not ignore any part of it.
2. You MUST output sleepQuality, appetiteLevel, and moodScore as numbers between 0.0 and 1.0 based on the text.
   - Example: "slept wonderfully" -> sleepQuality: 0.9
   - Example: "ate everything" -> appetiteLevel: 0.9
   - Example: "great mood, very happy" -> moodScore: 0.9
3. If an aspect is NOT mentioned at all, you MUST set its score to exactly 0.5. Do not omit the field.`;

async function extractObservation({ transcript }) {
  const parsed = await llmClient.generateStructured({
    system: SYSTEM_PROMPT,
    prompt: `Transcript:\n"""\n${transcript}\n"""`,
    schema: EXTRACT_SCHEMA,
  });

  return {
    ...parsed,
    categories: normalizeCategories(parsed.categories),
    structuredObservation: normalizeStructuredObservation(parsed.structuredObservation),
  };
}

module.exports = {
  extractObservation,
  OBSERVATION_CATEGORIES,
  normalizeCategories,
  normalizeScore,
};
