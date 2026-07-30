const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

// Vision-capable free models only — plain text free models (used by
// extractObservation.js) can't read an image at all. Ordered by informal
// preference; fall through the list on failure same as extractObservation.
const MODELS = [
  'google/gemma-4-31b-it:free',
  'google/gemma-4-26b-a4b-it:free',
  'nvidia/nemotron-nano-12b-v2-vl:free',
];

const SYSTEM_PROMPT = `You are reading a photo of a medication label/box for a caregiver.
Extract what you can actually see and output a JSON object matching this exact schema:
{
  "name": "medication name as printed, or null if unreadable",
  "strength": "e.g. '5 mg', or null",
  "dosageText": "e.g. '1 tablet twice daily', or null if not printed/visible",
  "route": "e.g. 'oral', or null",
  "specialInstructions": "e.g. 'take with food', or null",
  "times": ["HH:mm", ...],
  "confidence": "high" | "medium" | "low"
}

CRITICAL:
1. Only report what is actually printed on the label. Do NOT guess or infer a dose from pill appearance, color, or shape.
2. If a field is not visible or not printed, set it to null. Do not invent values.
3. "times" is a best-effort guess at dosing schedule ONLY if the label states a frequency you can convert to clock times (e.g. "twice daily" -> ["08:00", "20:00"]). Otherwise return an empty array.
4. Set "confidence": "low" if the photo is blurry, dark, or partially unreadable.
5. Return ONLY valid JSON without markdown formatting.`;

function normalizeDraft(parsed = {}) {
  return {
    name: typeof parsed.name === 'string' && parsed.name.trim() ? parsed.name.trim() : null,
    strength: typeof parsed.strength === 'string' && parsed.strength.trim() ? parsed.strength.trim() : null,
    dosageText: typeof parsed.dosageText === 'string' && parsed.dosageText.trim() ? parsed.dosageText.trim() : null,
    route: typeof parsed.route === 'string' && parsed.route.trim() ? parsed.route.trim() : null,
    specialInstructions:
      typeof parsed.specialInstructions === 'string' && parsed.specialInstructions.trim()
        ? parsed.specialInstructions.trim()
        : null,
    times: Array.isArray(parsed.times) ? parsed.times.filter((t) => /^\d{2}:\d{2}$/.test(t)) : [],
    confidence: ['high', 'medium', 'low'].includes(parsed.confidence) ? parsed.confidence : 'low',
  };
}

// imageUrl must be HTTPS-fetchable by OpenRouter's servers (a v4 signed GCS
// read URL works fine) — the bucket itself stays private.
async function extractMedicationLabel({ imageUrl }) {
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
            {
              role: 'user',
              content: [
                { type: 'text', text: 'Read this medication label photo and extract the fields.' },
                { type: 'image_url', image_url: { url: imageUrl } },
              ],
            },
          ],
          response_format: { type: 'json_object' },
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

      content = content.replace(/```json/g, '').replace(/```/g, '').trim();

      const parsed = JSON.parse(content);
      console.log(`Label OCR result from ${model}:`, JSON.stringify(parsed, null, 2));

      return normalizeDraft(parsed);
    } catch (e) {
      console.warn(`Vision model ${model} failed:`, e.message);
      lastError = e;
    }
  }

  throw new Error(`All fallback vision models failed. Last error: ${lastError?.message}`);
}

module.exports = { extractMedicationLabel, MODELS };
