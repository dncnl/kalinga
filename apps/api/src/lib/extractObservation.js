const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

// Free-tier model. OpenRouter's free model lineup shifts over time — if this
// one disappears, check https://openrouter.ai/models?max_price=0 for a
// current ":free" replacement with tool-calling support.
const MODEL = 'google/gemma-4-31b-it:free';

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

// Clamps to [0, 1] and drops anything that isn't actually a number — the
// free model occasionally returns out-of-range or non-numeric junk here.
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
            // 0-1 scores so the trend chart has something numeric to plot.
            // Omit (not 0) when the transcript didn't cover that aspect.
            sleepQuality: { type: 'number', description: '0 (very poor) to 1 (excellent). Omit if sleep was not mentioned.' },
            appetiteLevel: { type: 'number', description: '0 (refused to eat) to 1 (ate well). Omit if not mentioned.' },
            moodScore: { type: 'number', description: '0 (very distressed) to 1 (content/happy). Omit if not mentioned.' },
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

const SYSTEM_PROMPT = `You are a medical data extraction assistant.
A caregiver recorded a voice note about an elder. Extract the details and output a JSON object matching this exact schema. YOU MUST include all fields:
{
  "categories": ["appetite", "hydration", "sleep", "mood", "behavior", "mobility", "pain", "elimination", "medication", "vitalSigns", "skin", "breathing", "fall", "other"],
  "comparisonToUsual": "better" | "same" | "worse" | "unknown",
  "structuredObservation": {
    "summary": "Detailed 2-3 sentence summary covering ALL aspects mentioned in the transcript",
    "sleep": "Sleep details (if any)",
    "appetite": "Appetite details (if any)",
    "mood": "Mood details (if any)",
    "sleepQuality": 0.5,
    "appetiteLevel": 0.5,
    "moodScore": 0.5
  },
  "safetyAssessment": {
    "concernLevel": "none" | "low" | "medium" | "high",
    "concerns": ["list of concerns"],
    "recommendFollowUp": false
  }
}

CRITICAL INSTRUCTIONS:
1. You MUST analyze the entire transcript. Do not ignore any part of it.
2. You MUST output sleepQuality, appetiteLevel, and moodScore as numbers between 0.0 and 1.0 based on the text. 
   - Example: "slept wonderfully" -> sleepQuality: 0.9
   - Example: "ate everything" -> appetiteLevel: 0.9
   - Example: "great mood, very happy" -> moodScore: 0.9
3. If an aspect is NOT mentioned at all, you MUST set its score to exactly 0.5. Do not omit the field.
4. Return ONLY valid JSON without markdown formatting.`;

const MODELS = [
  'google/gemma-4-31b-it:free',
  'google/gemma-4-26b-a4b-it:free',
  'poolside/laguna-s-2.1:free',
  'inclusionai/ling-3.0-flash:free'
];

async function extractObservation({ transcript }) {
  let lastError;

  for (const model of MODELS) {
    try {
      const response = await fetch(OPENROUTER_URL, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          messages: [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: `Transcript:\n"""\n${transcript}\n"""` },
          ],
          response_format: { type: 'json_object' }
        }),
      });

      if (!response.ok) {
        throw new Error(`OpenRouter request failed (${response.status}): ${await response.text()}`);
      }

      const data = await response.json();
      let content = data.choices?.[0]?.message?.content;
      if (!content) {
        throw new Error('Model did not return content');
      }

      // Strip markdown formatting if the model still adds it despite instructions
      content = content.replace(/```json/g, '').replace(/```/g, '').trim();

      const parsed = JSON.parse(content);
      console.log(`LLM Result from ${model}:`, JSON.stringify(parsed, null, 2));

      return {
        ...parsed,
        categories: normalizeCategories(parsed.categories),
        structuredObservation: normalizeStructuredObservation(parsed.structuredObservation),
      };
    } catch (e) {
      console.warn(`Model ${model} failed:`, e.message);
      lastError = e;
      // Continue to the next model
    }
  }

  throw new Error(`All fallback models failed. Last error: ${lastError?.message}`);
}

module.exports = {
  extractObservation,
  OBSERVATION_CATEGORIES,
  MODEL,
  normalizeCategories,
  normalizeScore,
};
