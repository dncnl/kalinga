const { test } = require('node:test');
const assert = require('node:assert/strict');

const { classifyUrgency } = require('../../src/rag/classifyUrgency');

function mockModelResponse(t, body) {
  t.mock.method(global, 'fetch', async () => ({
    ok: true,
    json: async () => ({ choices: [{ message: { content: JSON.stringify(body) } }] }),
  }));
}

test('returns the model-classified urgency when it is well-formed', async (t) => {
  mockModelResponse(t, { urgency: 'attention', reason: 'Mild appetite change.' });

  const result = await classifyUrgency({ message: 'She ate less than usual today.', answer: 'Keep an eye on it.' });

  assert.equal(result.urgency, 'attention');
});

test('falls back to "attention" when the model returns an invalid urgency value', async (t) => {
  mockModelResponse(t, { urgency: 'super-bad', reason: 'nonsense' });

  const result = await classifyUrgency({ message: 'She seems tired.', answer: 'Rest is normal.' });

  assert.equal(result.urgency, 'attention');
});

test('never returns below "urgent" when the message contains an emergency keyword, even if the model under-calls it', async (t) => {
  mockModelResponse(t, { urgency: 'information', reason: 'model got it wrong' });

  const result = await classifyUrgency({
    message: 'She says she has chest pain and can\'t breathe well.',
    answer: 'This could be serious.',
  });

  assert.equal(result.urgency, 'urgent');
});

test('keyword floor does not override a higher model-classified urgency', async (t) => {
  mockModelResponse(t, { urgency: 'emergency', reason: 'possible stroke signs' });

  const result = await classifyUrgency({
    message: 'She has chest pain and her face looks droopy.',
    answer: 'This needs immediate attention.',
  });

  assert.equal(result.urgency, 'emergency');
});

test('falls back to a conservative default (not "none") when every model call fails', async (t) => {
  t.mock.method(global, 'fetch', async () => ({ ok: false, status: 429, text: async () => 'rate limited' }));

  const result = await classifyUrgency({ message: 'Just checking in.', answer: 'Sounds fine.' });

  assert.equal(result.urgency, 'attention');
});

test('keyword floor still applies even when every model call fails', async (t) => {
  t.mock.method(global, 'fetch', async () => ({ ok: false, status: 429, text: async () => 'rate limited' }));

  const result = await classifyUrgency({ message: 'He is unresponsive right now.', answer: '' });

  assert.equal(result.urgency, 'urgent');
});
