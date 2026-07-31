const test = require('node:test');
const assert = require('node:assert');

const llmClient = require('../src/lib/llmClient');
const {
  extractMedicationLabel,
  normalizeDraft,
  LABEL_SCHEMA,
} = require('../src/lib/extractMedicationLabel');

test('goes through llmClient (paid Vertex path), not a hardcoded model list', async (t) => {
  let seen = null;
  t.mock.method(llmClient, 'generateStructuredFromImage', async (args) => {
    seen = args;
    return { name: 'Amlodipine', strength: '5 mg', dosageText: '1 tablet daily', route: 'oral', specialInstructions: null, times: ['08:00'], confidence: 'high' };
  });

  const draft = await extractMedicationLabel({
    gcsUri: 'gs://bucket/households/h/careRecipients/c/medications/m/label.jpg',
    mimeType: 'image/jpeg',
  });

  assert.strictEqual(seen.gcsUri, 'gs://bucket/households/h/careRecipients/c/medications/m/label.jpg');
  assert.strictEqual(seen.mimeType, 'image/jpeg');
  assert.strictEqual(seen.schema, LABEL_SCHEMA);
  assert.strictEqual(draft.name, 'Amlodipine');
  assert.strictEqual(draft.confidence, 'high');
});

test('the prompt forbids inferring a dose from pill appearance', async (t) => {
  let systemPrompt = null;
  t.mock.method(llmClient, 'generateStructuredFromImage', async ({ system }) => {
    systemPrompt = system;
    return { name: null, strength: null, dosageText: null, route: null, specialInstructions: null, times: [], confidence: 'low' };
  });

  await extractMedicationLabel({ gcsUri: 'gs://b/x.jpg', mimeType: 'image/jpeg' });

  // The schema is explicit that a medication is "never inferred solely from
  // pill appearance" — losing this instruction would be a safety regression,
  // so it is asserted rather than trusted to survive edits.
  assert.match(systemPrompt, /never guess or infer/i);
  assert.match(systemPrompt, /appearance/i);
});

test('missing fields stay null rather than becoming empty strings', () => {
  const draft = normalizeDraft({
    name: '   ',
    strength: null,
    dosageText: undefined,
    route: '',
    specialInstructions: 'take with food',
    times: [],
    confidence: 'high',
  });
  assert.strictEqual(draft.name, null);
  assert.strictEqual(draft.strength, null);
  assert.strictEqual(draft.dosageText, null);
  assert.strictEqual(draft.route, null);
  assert.strictEqual(draft.specialInstructions, 'take with food');
});

test('malformed times are dropped, not passed through as a schedule', () => {
  const draft = normalizeDraft({ times: ['08:00', 'morning', '25:99', '20:00', ''] });
  assert.deepStrictEqual(draft.times, ['08:00', '20:00']);
});

test('an unknown or missing confidence falls back to low, never high', () => {
  // Defaulting optimistically would suppress the "check this carefully"
  // signal on exactly the scans that need it.
  assert.strictEqual(normalizeDraft({}).confidence, 'low');
  assert.strictEqual(normalizeDraft({ confidence: 'certain' }).confidence, 'low');
  assert.strictEqual(normalizeDraft({ confidence: 'medium' }).confidence, 'medium');
});
