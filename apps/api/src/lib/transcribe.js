const speech = require('@google-cloud/speech');

const { googleAuthOptions } = require('../firebase');

const client = new speech.SpeechClient(googleAuthOptions());

// Google Cloud Speech-to-Text language codes for the app's supported
// caregiver locales. Cebuano ('ceb') is NOT supported by Speech-to-Text as
// of this writing — calls with that locale will fail until Google adds
// support or we swap in a different STT vendor for it.
const STT_LANGUAGE_CODES = {
  fil: 'fil-PH',
  id: 'id-ID',
  vi: 'vi-VN',
  en: 'en-US',
  ceb: null,
};

async function transcribeAudio({ gcsUri, locale }) {
  const languageCode = STT_LANGUAGE_CODES[locale];
  if (!languageCode) {
    throw new Error(`No Speech-to-Text language mapping for locale "${locale}"`);
  }

  const [response] = await client.recognize({
    audio: { uri: gcsUri },
    config: {
      languageCode,
      enableAutomaticPunctuation: true,
    },
  });

  const text = (response.results || [])
    .map((result) => result.alternatives?.[0]?.transcript || '')
    .join(' ')
    .trim();

  return { text };
}

module.exports = { transcribeAudio, STT_LANGUAGE_CODES, client };
