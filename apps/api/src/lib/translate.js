const { TranslationServiceClient } = require('@google-cloud/translate');

const { googleAuthOptions } = require('../firebase');

const client = new TranslationServiceClient(googleAuthOptions());

// Cloud Translation uses ISO codes that mostly match our LocaleCode type,
// except Mandarin: our schema's 'zh-TW' vs Translation API's 'zh-TW' — same
// here, but Cebuano again has no dedicated code; Translation API does
// support 'ceb' though, unlike Speech-to-Text, so this map is separate
// from STT_LANGUAGE_CODES on purpose.
const TRANSLATE_LANGUAGE_CODES = {
  fil: 'fil',
  id: 'id',
  vi: 'vi',
  ceb: 'ceb',
  en: 'en',
  'zh-TW': 'zh-TW',
};

async function translateToMandarin({ text, sourceLocale, projectId }) {
  return translateText({ text, sourceLocale, targetLanguageCode: 'zh-TW', projectId });
}

// RAG retrieval embeds the query and compares it against an English-only
// chunk corpus — cross-lingual embedding similarity is weak enough that
// fil/ceb/id/vi queries were empirically retrieving zero chunks even for
// topically on-point questions (see PLAN.md's live-test notes). Translating
// to English first before embedding fixes retrieval; the answer itself
// still gets generated in the caregiver's own language.
async function translateToEnglish({ text, sourceLocale, projectId }) {
  return translateText({ text, sourceLocale, targetLanguageCode: 'en', projectId });
}

// sourceLocale is optional: omit it entirely to let the Translation API
// auto-detect the actual source language (used by symptom-check, where the
// app's stored language preference doesn't guarantee what language THIS
// message is typed in — forcing a wrong one previously produced
// garbled/mixed-language output). If sourceLocale IS given, it must be a
// real known code — an unmapped one is a programmer error, not a request
// for auto-detect, so that still fails fast.
async function translateText({ text, sourceLocale, targetLanguageCode, projectId }) {
  let sourceLanguageCode;
  if (sourceLocale !== undefined) {
    sourceLanguageCode = TRANSLATE_LANGUAGE_CODES[sourceLocale];
    if (!sourceLanguageCode) {
      throw new Error(`No Translation language mapping for locale "${sourceLocale}"`);
    }
  }

  const [response] = await client.translateText({
    parent: `projects/${projectId}/locations/global`,
    contents: [text],
    mimeType: 'text/plain',
    ...(sourceLanguageCode ? { sourceLanguageCode } : {}),
    targetLanguageCode,
  });

  return { text: response.translations?.[0]?.translatedText || '' };
}

module.exports = { translateToMandarin, translateToEnglish, TRANSLATE_LANGUAGE_CODES, client };
