const retrieve = require('./retrieve');
const llmClient = require('../lib/llmClient');

const SYSTEM_PROMPT = `You are a caregiving information assistant for migrant caregivers in Taiwan.
Answer ONLY using the numbered SOURCES provided below — do not use outside knowledge, and do not guess.
If the sources don't contain enough information to answer, say so plainly instead of making something up.
Cite sources inline like [1], [2] matching the numbers below. Keep answers short and practical.
This is informational only, not medical advice — if the question describes a possible emergency or urgent
medical concern, say so explicitly and recommend contacting a doctor or emergency services.`;

function buildPrompt(question, chunks) {
  const sourceList = chunks
    .map((c, i) => `[${i + 1}] (${c.sourcePublisher} — ${c.sourceTitle})\n${c.text}`)
    .join('\n\n');

  return `SOURCES:\n${sourceList}\n\nQUESTION: ${question}`;
}

// The whole point of this module: ground the answer in retrieved chunks
// rather than letting the model free-associate from training data (which is
// exactly the hallucination risk this feature exists to reduce).
async function answerQuestion(question) {
  const chunks = await retrieve.retrieveRelevantChunks(question, { topK: 4 });

  if (chunks.length === 0) {
    return {
      answer: "I don't have any information on that yet.",
      sources: [],
    };
  }

  const answer = await llmClient.generateText({
    system: SYSTEM_PROMPT,
    prompt: buildPrompt(question, chunks),
  });

  return {
    answer,
    sources: chunks.map((c, i) => ({
      n: i + 1,
      title: c.sourceTitle,
      publisher: c.sourcePublisher,
      url: c.sourceUrl,
      excerpt: c.text.slice(0, 200),
    })),
  };
}

const LOCALE_NAMES = {
  fil: 'Tagalog',
  ceb: 'Bisaya (Cebuano)',
  id: 'Bahasa Indonesia',
  vi: 'Vietnamese',
};

function symptomCheckSystemPrompt(locale) {
  const languageName = LOCALE_NAMES[locale];
  if (!languageName) {
    throw new Error(`No language mapping for locale "${locale}" — supported: ${Object.keys(LOCALE_NAMES).join(', ')}`);
  }
  return `You are a caregiving symptom-checker assistant for a migrant caregiver in Taiwan, talking directly
to her, not to the family. Answer ONLY using the numbered SOURCES provided below — do not use outside
knowledge, and do not guess. If the sources don't contain enough information, say so plainly instead of
making something up. Cite sources inline like [1], [2].

Respond entirely in ${languageName} — the caregiver does not read English or Mandarin. Keep the answer
short, practical, and calm.

You are NOT diagnosing and must never name a specific condition as certain, prescribe medication, or
infer a dose. This is informational only. If the message describes a possible emergency or urgent
medical concern, say so explicitly, in plain language, and tell her to contact a doctor or emergency
services (119) right away.`;
}

// Same RAG grounding as answerQuestion, but scoped to one care recipient's
// symptom-check chat: answers directly in the caregiver's own language
// (see PLAN.md — avoids an extra lossy translation hop) rather than English.
async function answerSymptomCheck({ message, locale }) {
  const chunks = await retrieve.retrieveRelevantChunks(message, { topK: 4 });

  if (chunks.length === 0) {
    return {
      answer:
        locale === 'fil'
          ? 'Wala akong sapat na impormasyon tungkol dito. Kung nag-aalala ka, makipag-ugnayan sa doktor.'
          : "I don't have enough information on that yet. If you're worried, please contact a doctor.",
      sources: [],
    };
  }

  const answer = await llmClient.generateText({
    system: symptomCheckSystemPrompt(locale),
    prompt: buildPrompt(message, chunks),
  });

  return {
    answer,
    sources: chunks.map((c, i) => ({
      n: i + 1,
      title: c.sourceTitle,
      publisher: c.sourcePublisher,
      url: c.sourceUrl,
      excerpt: c.text.slice(0, 200),
    })),
  };
}

module.exports = { answerQuestion, answerSymptomCheck, buildPrompt, SYSTEM_PROMPT, LOCALE_NAMES };
