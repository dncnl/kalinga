const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

// Free-tier model. OpenRouter's free model lineup shifts over time — if this
// one disappears, check https://openrouter.ai/models?max_price=0 for a
// current ":free" replacement with tool-calling support.
const MODEL = 'openai/gpt-oss-20b:free';

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

const EXTRACT_TOOL = {
  type: 'function',
  function: {
    name: 'record_observation',
    description: 'Record structured details extracted from a caregiver\'s voice log about an elder.',
    parameters: {
      type: 'object',
      properties: {
        categories: {
          type: 'array',
          // No enum constraint here on purpose: the free model this runs
          // against fails tool-call validation entirely (provider rejects
          // the whole call, not just the field) if it picks a word outside
          // a large enum. Free text in, normalizeCategories() maps it to
          // OBSERVATION_CATEGORIES afterward.
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
    },
  },
};

// Takes the caregiver's original-language transcript (not the translation —
// extraction should work off what they actually said) and pulls out the
// fields ObservationDocument needs. Uses OpenRouter's free tier; the
// provider doesn't support forcing tool_choice to a specific function, so
// this prompts the model to call it and treats "didn't call it" as a
// (retryable, by the caller) failure rather than silently returning nothing.
async function extractObservation({ transcript }) {
  const response = await fetch(OPENROUTER_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: MODEL,
      tools: [EXTRACT_TOOL],
      messages: [
        {
          role: 'user',
          content: `A migrant caregiver recorded this voice note about the elder they care for. Call record_observation with the extracted details. Flag any safety concerns (e.g. falls, refusing food/water, medication issues, sudden behavior change) even if the caregiver didn't call them out explicitly.\n\nTranscript:\n"""\n${transcript}\n"""`,
        },
      ],
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`OpenRouter request failed (${response.status}): ${body}`);
  }

  const data = await response.json();
  const toolCall = data.choices?.[0]?.message?.tool_calls?.[0];
  if (!toolCall) {
    throw new Error('Model did not return structured observation data');
  }

  const parsed = JSON.parse(toolCall.function.arguments);
  return { ...parsed, categories: normalizeCategories(parsed.categories) };
}

module.exports = { extractObservation, OBSERVATION_CATEGORIES, MODEL, normalizeCategories };
