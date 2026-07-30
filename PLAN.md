# Feature: Switch default LLM provider to Vertex AI/Gemini

Replaces OpenRouter's free-tier model as the default LLM provider with
Vertex AI (Gemini), now that the project has active GCP billing ($300
free-trial credit, hackathon) instead of the billing wall that motivated
OpenRouter originally. Covers both LLM call sites: `/rag/ask` (via
`answer.js`) and `extractObservation.js` (structured extraction from
caregiver voice-log transcripts) — the latter didn't go through the shared
`llmClient.js` abstraction at all before this change.

## Why

`llmClient.js` defaulted to OpenRouter because earlier attempts at Vertex
AI/Anthropic hit a "no billing set up" dead end (see git history). That's
no longer true. For a hackathon, deeper native Google Cloud integration is
also a plus on its own merits, not just a cost question.

## SDK note (verified against the live, installed package — not assumed
from training knowledge, since `@google-cloud/vertexai` was deprecated
June 2026)

`@google/genai@2.15.0` is the current correct package — supports both the
direct Gemini API and the Vertex AI backend from one client. Verified
directly against `node_modules/@google/genai/dist/genai.d.ts`:
`new GoogleGenAI({ vertexai: true, project, location, googleAuthOptions })`.
`googleAuthOptions` accepts the exact same shape as this codebase's
existing `googleAuthOptions()` helper in `firebase.js` (used for
Speech/Translate/the RAG bucket's Storage client) — same auth pattern,
reused, not a new one invented.

## Design decisions

1. **`generateStructured`, a new function alongside `generateText`** in
   `llmClient.js` — `answer.js`'s need (text out) and
   `extractObservation.js`'s need (JSON matching a schema) are different
   enough shapes to warrant separate functions rather than overloading one.
   Both dispatch through their own `PROVIDERS`/`STRUCTURED_PROVIDERS` maps,
   same pattern as before.
2. **`extractObservation.js` rewritten, not ported.** Its
   `EXTRACT_TOOL.function.parameters` schema (previously defined but never
   actually sent to OpenRouter — dead code) is now the real
   `responseJsonSchema` passed to Gemini's native structured-output mode.
   Deleted: the 4-model OpenRouter fallback array and markdown-fence-
   stripping hack, both specific to working around free-tier model
   flakiness — a non-problem on a single reliable paid model.
3. **Mocking gotcha found and fixed**: `extractObservation.js` originally
   destructured `const { generateStructured } = require('./llmClient')`,
   which captures a reference at import time that `t.mock.method(llmClient,
   'generateStructured', ...)` can't intercept later. Fixed by importing
   the whole `llmClient` namespace and calling `llmClient.generateStructured(...)`,
   matching `answer.js`'s existing (correct) pattern. Applied the same
   `module.exports.getVertexAIClient()` self-reference trick (already used
   elsewhere in this codebase, e.g. `uploadNewSources.js`'s PDF extraction)
   so the Vertex AI client construction itself is mockable too.
4. **OpenRouter kept as a working fallback** (`LLM_PROVIDER=openrouter`),
   just no longer the default — cheap insurance for a live hackathon demo.

## What's done vs. still needed

Done: `llmClient.js` (vertexai provider + `generateStructured`),
`extractObservation.js` rewrite, `.env.example`, both test files rewritten.
Full suite: 155/155 passing (this also fixed 2 pre-existing
`extractObservation` test failures that predate this branch — the old
test file expected a response shape the implementation had already moved
away from).

**Not done yet, needed before this actually works against real Gemini:**
- Local ADC (`gcloud auth application-default login`) still isn't
  configured on this machine — needed to exercise Vertex AI calls locally
  at all (established earlier this session; same gap that caused RAG
  bucket auth confusion on the previous branch).
- Enable `aiplatform.googleapis.com` on `kalinga-bc97f` if not already on,
  and grant `roles/aiplatform.user` to whichever identity calls it.
- Live end-to-end test not done in this environment: `POST /rag/ask` with
  a real question, and `extractObservation` with a real transcript,
  confirming Gemini actually returns usable answers/structured data (unit
  tests mock the SDK boundary, so schema/auth-shape correctness is
  verified, but not "does gemini-2.5-flash actually produce good output
  for this prompt").
