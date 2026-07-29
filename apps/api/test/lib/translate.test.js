const { test } = require('node:test');
const assert = require('node:assert/strict');

const { translateToMandarin, client } = require('../../src/lib/translate');

test('translateToMandarin returns the translated text', async (t) => {
  t.mock.method(client, 'translateText', async (req) => {
    assert.equal(req.sourceLanguageCode, 'fil');
    assert.equal(req.targetLanguageCode, 'zh-TW');
    assert.equal(req.contents[0], 'Kumain siya ng maayos.');
    return [{ translations: [{ translatedText: '他吃得很好。' }] }];
  });

  const { text } = await translateToMandarin({
    text: 'Kumain siya ng maayos.',
    sourceLocale: 'fil',
    projectId: 'kalinga-bc97f',
  });

  assert.equal(text, '他吃得很好。');
});

test('translateToMandarin rejects an unmapped source locale', async () => {
  await assert.rejects(
    () => translateToMandarin({ text: 'hi', sourceLocale: 'xx', projectId: 'p' }),
    /No Translation language mapping/,
  );
});
