// Swappable LLM client — this is the "placeholder" for which model answers
// RAG questions (and, later, anything else that needs a general chat
// completion). Change which model runs by setting env vars, not by editing
// call sites:
//
//   LLM_PROVIDER=vertexai     (default; Google Cloud project's own billing,
//                              no separate API key — see googleAuthOptions()
//                              in ../firebase.js)
//   LLM_PROVIDER=openrouter   (fallback; free-tier, no billing required)
//   LLM_PROVIDER=anthropic    (needs ANTHROPIC_API_KEY + billing)
//   LLM_PROVIDER=openai       (needs OPENAI_API_KEY + billing)
//   LLM_MODEL=<provider-specific model id>
//   VERTEX_AI_LOCATION=<region>  (default: us-central1)
//
// anthropic/openai are stubbed with a clear error so swapping providers
// later is "fill in the fetch call," not "redesign the interface."

const DEFAULT_PROVIDER = process.env.LLM_PROVIDER || 'vertexai';
const DEFAULT_MODEL = process.env.LLM_MODEL || 'gemini-2.5-flash';
const VERTEX_AI_LOCATION = process.env.VERTEX_AI_LOCATION || 'us-central1';

// Same identity as every other Google Cloud client in this codebase
// (Speech, Translate, the RAG bucket's @google-cloud/storage client) —
// see googleAuthOptions()'s own comment in ../firebase.js for why plain
// @google/* clients need this instead of just relying on firebase-admin.
function getVertexAIClient() {
  const { GoogleGenAI } = require('@google/genai');
  const { googleAuthOptions, projectId } = require('../firebase');
  return new GoogleGenAI({
    vertexai: true,
    project: projectId,
    location: VERTEX_AI_LOCATION,
    googleAuthOptions: googleAuthOptions(),
  });
}

async function callVertexAI({ system, prompt, model }) {
  // Via module.exports (not the bare local name) so tests can mock the
  // client construction without exercising real @google/genai auth/network.
  const ai = module.exports.getVertexAIClient();
  const response = await ai.models.generateContent({
    model,
    contents: prompt,
    config: system ? { systemInstruction: system } : undefined,
  });
  return response.text ?? '';
}

async function callVertexAIStructured({ system, prompt, schema, model }) {
  const ai = module.exports.getVertexAIClient();
  const response = await ai.models.generateContent({
    model,
    contents: prompt,
    config: {
      ...(system ? { systemInstruction: system } : {}),
      responseMimeType: 'application/json',
      responseJsonSchema: schema,
    },
  });
  const text = response.text ?? '';
  return JSON.parse(text);
}

// Vision + schema-constrained JSON. Vertex reads the image straight out of
// the project's own bucket by gs:// URI, using the same service-account
// identity as every other Google Cloud client here — so unlike the
// OpenRouter path this needs no signed public-ish read URL at all.
async function callVertexAIVisionStructured({ system, prompt, schema, model, gcsUri, mimeType }) {
  const ai = module.exports.getVertexAIClient();
  const response = await ai.models.generateContent({
    model,
    contents: [
      {
        role: 'user',
        parts: [
          { text: prompt },
          { fileData: { fileUri: gcsUri, mimeType } },
        ],
      },
    ],
    config: {
      ...(system ? { systemInstruction: system } : {}),
      responseMimeType: 'application/json',
      responseJsonSchema: schema,
    },
  });
  const text = response.text ?? '';
  return JSON.parse(text);
}

async function callOpenRouter({ system, prompt, model }) {
  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: [
        ...(system ? [{ role: 'system', content: system }] : []),
        { role: 'user', content: prompt },
      ],
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`OpenRouter request failed (${response.status}): ${body}`);
  }

  const data = await response.json();
  return data.choices?.[0]?.message?.content ?? '';
}

async function callAnthropic() {
  throw new Error(
    'LLM_PROVIDER=anthropic is not implemented yet (needs ANTHROPIC_API_KEY + billing). ' +
      'See extractObservation.js git history for a working Anthropic SDK call to port over.',
  );
}

async function callOpenAI() {
  throw new Error('LLM_PROVIDER=openai is not implemented yet (needs OPENAI_API_KEY + billing).');
}

function notImplementedStructured(provider) {
  return async () => {
    throw new Error(`Structured generation for LLM_PROVIDER=${provider} is not implemented — use vertexai.`);
  };
}

const PROVIDERS = {
  vertexai: callVertexAI,
  openrouter: callOpenRouter,
  anthropic: callAnthropic,
  openai: callOpenAI,
};

const STRUCTURED_PROVIDERS = {
  vertexai: callVertexAIStructured,
  openrouter: notImplementedStructured('openrouter'),
  anthropic: notImplementedStructured('anthropic'),
  openai: notImplementedStructured('openai'),
};

const VISION_PROVIDERS = {
  vertexai: callVertexAIVisionStructured,
  openrouter: notImplementedStructured('openrouter'),
  anthropic: notImplementedStructured('anthropic'),
  openai: notImplementedStructured('openai'),
};

// Plain chat completion: system prompt + user prompt in, text out. No
// tool-calling here — see generateStructured for schema-constrained output.
async function generateText({ system, prompt, provider = DEFAULT_PROVIDER, model = DEFAULT_MODEL }) {
  const call = PROVIDERS[provider];
  if (!call) {
    throw new Error(`Unknown LLM_PROVIDER "${provider}". Valid: ${Object.keys(PROVIDERS).join(', ')}`);
  }
  return call({ system, prompt, model });
}

// Schema-constrained JSON output: system prompt + user prompt + JSON Schema
// in, parsed object out. For extracting structured data (see
// extractObservation.js) rather than free-form text.
async function generateStructured({ system, prompt, schema, provider = DEFAULT_PROVIDER, model = DEFAULT_MODEL }) {
  const call = STRUCTURED_PROVIDERS[provider];
  if (!call) {
    throw new Error(`Unknown LLM_PROVIDER "${provider}". Valid: ${Object.keys(STRUCTURED_PROVIDERS).join(', ')}`);
  }
  return call({ system, prompt, schema, model });
}

// Schema-constrained JSON output from an image in the project's own GCS
// bucket. Same contract as generateStructured, plus [gcsUri]/[mimeType].
// Used by the medication-label scan (see extractMedicationLabel.js).
async function generateStructuredFromImage({
  system,
  prompt,
  schema,
  gcsUri,
  mimeType,
  provider = DEFAULT_PROVIDER,
  model = DEFAULT_MODEL,
}) {
  const call = VISION_PROVIDERS[provider];
  if (!call) {
    throw new Error(`Unknown LLM_PROVIDER "${provider}". Valid: ${Object.keys(VISION_PROVIDERS).join(', ')}`);
  }
  return call({ system, prompt, schema, model, gcsUri, mimeType });
}

module.exports = {
  generateText,
  generateStructured,
  generateStructuredFromImage,
  getVertexAIClient,
  DEFAULT_PROVIDER,
  DEFAULT_MODEL,
};
