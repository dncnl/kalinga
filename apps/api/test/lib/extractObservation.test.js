const { test } = require('node:test');
const assert = require('node:assert/strict');

const { extractObservation, client } = require('../../src/lib/extractObservation');

test('extractObservation returns the tool_use input', async (t) => {
  const fakeExtraction = {
    categories: ['sleep', 'appetite'],
    comparisonToUsual: 'worse',
    structuredObservation: { summary: 'Slept poorly, ate less than usual.' },
    safetyAssessment: { concernLevel: 'low', concerns: [], recommendFollowUp: false },
  };

  t.mock.method(client.messages, 'create', async (req) => {
    assert.equal(req.tool_choice.name, 'record_observation');
    assert.match(req.messages[0].content, /Slept poorly/);
    return {
      content: [{ type: 'tool_use', id: 'toolu_1', name: 'record_observation', input: fakeExtraction }],
    };
  });

  const result = await extractObservation({ transcript: 'Slept poorly, ate less than usual.' });

  assert.deepEqual(result, fakeExtraction);
});

test('extractObservation throws when no tool_use block is returned', async (t) => {
  t.mock.method(client.messages, 'create', async () => ({
    content: [{ type: 'text', text: 'sorry, I cannot help with that' }],
  }));

  await assert.rejects(
    () => extractObservation({ transcript: 'anything' }),
    /did not return structured observation data/,
  );
});
