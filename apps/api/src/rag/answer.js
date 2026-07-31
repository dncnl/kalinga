const retrieve = require('./retrieve');
const llmClient = require('../lib/llmClient');

const SYSTEM_PROMPT = `You are a caregiving information assistant for migrant caregivers in Taiwan —
mostly from the Philippines, Indonesia, and Vietnam, often with little or no formal
elder-care training and working in a language that isn't their first.

LANGUAGE: Answer in the same language the question was asked in (e.g. Tagalog,
Bisaya, Bahasa Indonesia, Vietnamese, English). The SOURCES below are in English —
translate and explain their content in the caregiver's language, don't just quote
English back at them.

GROUNDING: Answer ONLY using the numbered SOURCES provided below — do not use outside
knowledge, and do not guess. If the sources don't contain enough information to
answer, say so plainly instead of making something up. Cite sources inline like [1],
[2] matching the numbers below.

STYLE: Use simple, everyday words — avoid medical jargon, and briefly explain any
medical term you can't avoid. Keep answers short: a few sentences or a short bullet
list, written for reading on a phone, not a full article.

SAFETY: This is informational only, not medical advice — if the question describes a
possible emergency or urgent medical concern, say so explicitly, in plain words, and
recommend contacting a doctor or emergency services right away.`;

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

module.exports = { answerQuestion, buildPrompt, SYSTEM_PROMPT };
