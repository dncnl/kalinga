const { test } = require('node:test');
const assert = require('node:assert/strict');

const llmClient = require('../../src/lib/llmClient');
const { generateText, generateStructured } = llmClient;

function mockVertexClient(t, { text } = {}) {
  const calls = [];
  t.mock.method(llmClient, 'getVertexAIClient', () => ({
    models: {
      generateContent: async (params) => {
        calls.push(params);
        return { text };
      },
    },
  }));
  return calls;
}

test('generateText calls Vertex AI by default and returns the response text', async (t) => {
  const calls = mockVertexClient(t, { text: 'hi there' });

  const result = await generateText({ system: 'be nice', prompt: 'hello?' });

  assert.equal(result, 'hi there');
  assert.equal(calls.length, 1);
  assert.equal(calls[0].contents, 'hello?');
  assert.equal(calls[0].config.systemInstruction, 'be nice');
});

test('generateText returns an empty string when Vertex AI returns no text', async (t) => {
  mockVertexClient(t, { text: undefined });

  const result = await generateText({ prompt: 'hello?' });

  assert.equal(result, '');
});

test('generateText still supports openrouter explicitly', async (t) => {
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

  const result = await generateText({ system: 'be nice', prompt: 'hello?', provider: 'openrouter' });

  assert.equal(result, 'hi there');
});

test('generateText throws with response body on a non-ok openrouter HTTP response', async (t) => {
  t.mock.method(global, 'fetch', async () => ({
    ok: false,
    status: 500,
    text: async () => 'server exploded',
  }));

  await assert.rejects(
    () => generateText({ prompt: 'hello?', provider: 'openrouter' }),
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

test('generateStructured calls Vertex AI with responseJsonSchema and parses the result', async (t) => {
  const schema = { type: 'object', properties: { a: { type: 'string' } }, required: ['a'] };
  const calls = mockVertexClient(t, { text: JSON.stringify({ a: 'hello' }) });

  const result = await generateStructured({ system: 'extract', prompt: 'text', schema });

  assert.deepEqual(result, { a: 'hello' });
  assert.equal(calls[0].config.responseMimeType, 'application/json');
  assert.equal(calls[0].config.responseJsonSchema, schema);
  assert.equal(calls[0].config.systemInstruction, 'extract');
});

test('generateStructured throws for a provider without structured support', async () => {
  await assert.rejects(
    () => generateStructured({ prompt: 'hi', schema: {}, provider: 'openrouter' }),
    /Structured generation for LLM_PROVIDER=openrouter is not implemented/,
  );
});

test('generateStructured throws for an unknown provider name', async () => {
  await assert.rejects(
    () => generateStructured({ prompt: 'hi', schema: {}, provider: 'bogus' }),
    /Unknown LLM_PROVIDER "bogus"/,
  );
});
