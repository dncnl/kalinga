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
  const sourceLanguageCode = TRANSLATE_LANGUAGE_CODES[sourceLocale];
  if (!sourceLanguageCode) {
    throw new Error(`No Translation language mapping for locale "${sourceLocale}"`);
  }

  const [response] = await client.translateText({
    parent: `projects/${projectId}/locations/global`,
    contents: [text],
    mimeType: 'text/plain',
    sourceLanguageCode,
    targetLanguageCode: 'zh-TW',
  });

  return { text: response.translations?.[0]?.translatedText || '' };
}

module.exports = { translateToMandarin, TRANSLATE_LANGUAGE_CODES, client };
