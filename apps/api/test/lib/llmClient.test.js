const { test } = require('node:test');
const assert = require('node:assert/strict');

const { generateText } = require('../../src/lib/llmClient');

test('generateText calls OpenRouter by default and returns the message content', async (t) => {
  t.mock.method(global, 'fetch', async (url, options) => {
    assert.equal(url, 'https://openrouter.ai/api/v1/chat/completions');
    const body = JSON.parse(options.body);
    assert.equal(body.messages[0].role, 'system');
    assert.equal(body.messages[1].content, 'hello?');

    return {
      ok: true,
      json: async () => ({ choices: [{ message: { content: 'hi there' } }] }),
    };
  });

  const result = await generateText({ system: 'be nice', prompt: 'hello?' });

  assert.equal(result, 'hi there');
});

test('generateText throws with response body on a non-ok HTTP response', async (t) => {
  t.mock.method(global, 'fetch', async () => ({
    ok: false,
    status: 500,
    text: async () => 'server exploded',
  }));

  await assert.rejects(
    () => generateText({ prompt: 'hello?' }),
    /OpenRouter request failed \(500\): server exploded/,
  );
});

test('generateText throws a clear error for an unimplemented provider', async () => {
  await assert.rejects(
    () => generateText({ prompt: 'hi', provider: 'anthropic' }),
    /not implemented yet/,
  );
});

test('generateText throws for an unknown provider name', async () => {
  await assert.rejects(
    () => generateText({ prompt: 'hi', provider: 'bogus' }),
    /Unknown LLM_PROVIDER "bogus"/,
  );
});
