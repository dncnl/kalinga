const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

// Same fallback-chain pattern as extractObservation.js / extractMedicationLabel.js.
const MODELS = [
  'google/gemma-4-31b-it:free',
  'google/gemma-4-26b-a4b-it:free',
  'openai/gpt-oss-20b:free',
];

const URGENCY_LEVELS = ['none', 'information', 'attention', 'urgent', 'emergency'];

// A missed alert is worse than a false one here — this list is deliberately
// generous, not an exhaustive medical list. Backstops the LLM: if the
// caregiver's own words contain one of these, never let the classification
// fall below 'urgent' even if the model under-calls it.
const EMERGENCY_KEYWORDS = [
  'chest pain', 'can\'t breathe', 'cannot breathe', 'not breathing', 'unresponsive',
  'unconscious', 'won\'t wake up', 'seizure', 'stroke', 'severe bleeding',
  'suicide', 'choking',
];

const SYSTEM_PROMPT = `You are a triage-urgency classifier for a caregiving assistant used by migrant
caregivers for elderly care recipients in Taiwan. You are NOT diagnosing — you are only judging how
urgently a human (family or a doctor) needs to be told about what the caregiver just described.

Output ONLY a JSON object: { "urgency": "<level>", "reason": "<one short sentence>" }

Levels, in increasing order of urgency:
- "none": no health concern described (e.g. a general question).
- "information": a minor, non-worrying observation.
- "attention": worth noting and watching, not urgent (e.g. mild appetite loss, slightly disturbed sleep).
- "urgent": a concerning symptom that should be checked by a doctor soon (today), e.g. a fall without
  obvious injury, new confusion, persistent vomiting, moderate pain.
- "emergency": a possible medical emergency needing immediate care — chest pain, difficulty breathing,
  unresponsiveness, signs of stroke, severe bleeding, suicidal statements, choking.

Bias toward the higher level when uncertain — a missed emergency is far worse than a false alarm.`;

function buildPrompt(message, answer) {
  return `CAREGIVER'S MESSAGE:\n"""\n${message}\n"""\n\nGROUNDED ANSWER GIVEN TO THE CAREGIVER:\n"""\n${answer}\n"""\n\nClassify the urgency.`;
}

function keywordFloor(message) {
  const lower = message.toLowerCase();
  return EMERGENCY_KEYWORDS.some((kw) => lower.includes(kw)) ? 'urgent' : 'none';
}

function maxUrgency(a, b) {
  return URGENCY_LEVELS.indexOf(a) >= URGENCY_LEVELS.indexOf(b) ? a : b;
}

async function classifyUrgency({ message, answer }) {
  const floor = keywordFloor(message);
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
            { role: 'user', content: buildPrompt(message, answer) },
          ],
          response_format: { type: 'json_object' },
        }),
      });

      if (!response.ok) {
        throw new Error(`OpenRouter request failed (${response.status}): ${await response.text()}`);
      }

      const data = await response.json();
      let content = data.choices?.[0]?.message?.content;
      if (!content) throw new Error('Model did not return content');
      content = content.replace(/```json/g, '').replace(/```/g, '').trim();

      const parsed = JSON.parse(content);
      const urgency = URGENCY_LEVELS.includes(parsed.urgency) ? parsed.urgency : 'attention';

      return {
        urgency: maxUrgency(urgency, floor),
        reason: typeof parsed.reason === 'string' ? parsed.reason : null,
      };
    } catch (e) {
      console.warn(`Urgency model ${model} failed:`, e.message);
      lastError = e;
    }
  }

  // Every model failed: never silently drop to "none" — fall back to the
  // keyword floor (or 'attention' if no keyword matched) so a real
  // infrastructure failure can't also mean a missed emergency.
  console.error(`All urgency-classification models failed, using keyword floor. Last error: ${lastError?.message}`);
  return { urgency: floor === 'none' ? 'attention' : floor, reason: 'Automatic classification unavailable; defaulted conservatively.' };
}

module.exports = { classifyUrgency, URGENCY_LEVELS, EMERGENCY_KEYWORDS };
