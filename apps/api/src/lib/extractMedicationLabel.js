const llmClient = require('./llmClient');

// Reads a photo of a medication LABEL or blister pack — never the pills
// themselves. The schema is explicit that a medication must not be inferred
// from pill appearance, and the prompt below repeats it, because getting
// this wrong means a wrong dose.
//
// Goes through llmClient like every other model call in this codebase, so
// it uses the same paid Vertex AI path as the text extraction rather than
// its own hand-rolled fetch against a list of free-tier vision models. That
// list was the last place a model choice was hardcoded at a call site;
// swapping providers is now an env var here too.

// Enforced structurally by Gemini via responseJsonSchema — the old prompt
// had to beg for "ONLY valid JSON without markdown formatting" and then
// strip ``` fences by hand.
const LABEL_SCHEMA = {
  type: 'object',
  properties: {
    name: { type: ['string', 'null'], description: 'Medication name exactly as printed, or null if unreadable.' },
    strength: { type: ['string', 'null'], description: "e.g. '5 mg'. Null if not printed." },
    dosageText: { type: ['string', 'null'], description: "e.g. '1 tablet twice daily'. Null if not printed." },
    route: { type: ['string', 'null'], description: "e.g. 'oral'. Null if not printed." },
    specialInstructions: { type: ['string', 'null'], description: "e.g. 'take with food'. Null if not printed." },
    times: {
      type: 'array',
      items: { type: 'string' },
      description:
        'Clock times in HH:mm ONLY when the label states a frequency that converts to them '
        + '(e.g. "twice daily" -> ["08:00", "20:00"]). Empty array otherwise.',
    },
    confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
  },
  required: ['name', 'strength', 'dosageText', 'route', 'specialInstructions', 'times', 'confidence'],
};

const SYSTEM_PROMPT = `You are reading a photo of a medication label, box, or blister pack for a caregiver.

CRITICAL SAFETY RULES:
1. Report ONLY what is actually printed on the label. Never guess or infer a
   medication or a dose from the pill's appearance, colour, shape, or markings.
2. If a field is not visible or not printed, return null. Never invent a value.
   A null is useful; a plausible guess is dangerous.
3. Set "confidence" to "low" if the photo is blurry, dark, angled, or partly
   unreadable — the caregiver has to confirm every scan, and low confidence
   is what tells her to look carefully.`;

// A real clock time, not just two digits and a colon: `\d{2}:\d{2}` happily
// accepts "25:99", and setUTCHours(25, 99) silently rolls over into the next
// day — so a garbled scan would schedule a dose at a time nobody chose.
const CLOCK_TIME = /^([01]\d|2[0-3]):([0-5]\d)$/;

function normalizeDraft(parsed = {}) {
  const text = (value) => (typeof value === 'string' && value.trim() ? value.trim() : null);
  return {
    name: text(parsed.name),
    strength: text(parsed.strength),
    dosageText: text(parsed.dosageText),
    route: text(parsed.route),
    specialInstructions: text(parsed.specialInstructions),
    times: Array.isArray(parsed.times) ? parsed.times.filter((t) => CLOCK_TIME.test(t)) : [],
    confidence: ['high', 'medium', 'low'].includes(parsed.confidence) ? parsed.confidence : 'low',
  };
}

/// [gcsUri] is a gs:// URI in this project's own bucket. Vertex reads it with
/// the service account directly, so the bucket stays private and no signed
/// URL is minted.
async function extractMedicationLabel({ gcsUri, mimeType }) {
  const parsed = await llmClient.generateStructuredFromImage({
    system: SYSTEM_PROMPT,
    prompt: 'Read this medication label photo and extract the fields.',
    schema: LABEL_SCHEMA,
    gcsUri,
    mimeType,
  });
  return normalizeDraft(parsed);
}

module.exports = { extractMedicationLabel, normalizeDraft, LABEL_SCHEMA };
