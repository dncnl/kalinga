const { test } = require('node:test');
const assert = require('node:assert/strict');

const { transcribeAudio, client } = require('../../src/lib/transcribe');

test('transcribeAudio joins alternatives from all results', async (t) => {
  t.mock.method(client, 'recognize', async (req) => {
    assert.equal(req.audio.uri, 'gs://bucket/audio.m4a');
    assert.equal(req.config.languageCode, 'fil-PH');
    return [
      {
        results: [
          { alternatives: [{ transcript: 'Kumain siya ng maayos.' }] },
          { alternatives: [{ transcript: 'Natulog siya nang mahimbing.' }] },
        ],
      },
    ];
  });

  const { text } = await transcribeAudio({ gcsUri: 'gs://bucket/audio.m4a', locale: 'fil' });

  assert.equal(text, 'Kumain siya ng maayos. Natulog siya nang mahimbing.');
});

test('transcribeAudio rejects an unsupported locale (ceb)', async () => {
  await assert.rejects(
    () => transcribeAudio({ gcsUri: 'gs://bucket/audio.m4a', locale: 'ceb' }),
    /No Speech-to-Text language mapping/,
  );
});

test('transcribeAudio returns empty string when no results', async (t) => {
  t.mock.method(client, 'recognize', async () => [{ results: [] }]);

  const { text } = await transcribeAudio({ gcsUri: 'gs://bucket/audio.m4a', locale: 'en' });

  assert.equal(text, '');
});
