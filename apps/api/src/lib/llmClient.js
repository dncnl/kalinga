// Swappable LLM client — this is the "placeholder" for which model answers
// RAG questions (and, later, anything else that needs a general chat
// completion). Change which model runs by setting env vars, not by editing
// call sites:
//
//   LLM_PROVIDER=openrouter   (default; free-tier, no billing required)
//   LLM_PROVIDER=anthropic    (needs ANTHROPIC_API_KEY + billing)
//   LLM_PROVIDER=openai       (needs OPENAI_API_KEY + billing)
//   LLM_MODEL=<provider-specific model id>
//
// Only "openrouter" is actually implemented right now — see PLAN.md for
// why (no Anthropic/OpenAI billing available at time of writing). The
// other two are stubbed with a clear error so swapping providers later is
// "fill in the fetch call," not "redesign the interface."

const DEFAULT_PROVIDER = process.env.LLM_PROVIDER || 'openrouter';
const DEFAULT_MODEL = process.env.LLM_MODEL || 'openai/gpt-oss-20b:free';

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

const PROVIDERS = {
  openrouter: callOpenRouter,
  anthropic: callAnthropic,
  openai: callOpenAI,
};

// Plain chat completion: system prompt + user prompt in, text out. No
// tool-calling here — see extractObservation.js for that pattern if a
// future caller needs structured output.
async function generateText({ system, prompt, provider = DEFAULT_PROVIDER, model = DEFAULT_MODEL }) {
  const call = PROVIDERS[provider];
  if (!call) {
    throw new Error(`Unknown LLM_PROVIDER "${provider}". Valid: ${Object.keys(PROVIDERS).join(', ')}`);
  }
  return call({ system, prompt, model });
}

module.exports = { generateText, DEFAULT_PROVIDER, DEFAULT_MODEL };
