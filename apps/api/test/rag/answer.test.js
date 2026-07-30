const { test } = require('node:test');
const assert = require('node:assert/strict');

const retrieve = require('../../src/rag/retrieve');
const llmClient = require('../../src/lib/llmClient');
const { answerQuestion, buildPrompt } = require('../../src/rag/answer');

test('buildPrompt numbers sources and includes the question', () => {
  const chunks = [
    { sourcePublisher: 'WHO', sourceTitle: 'ICOPE', text: 'chunk one text' },
    { sourcePublisher: 'MOHW', sourceTitle: 'LTC', text: 'chunk two text' },
  ];

  const prompt = buildPrompt('How often should I check medication?', chunks);

  assert.match(prompt, /\[1\] \(WHO — ICOPE\)/);
  assert.match(prompt, /\[2\] \(MOHW — LTC\)/);
  assert.match(prompt, /QUESTION: How often should I check medication\?/);
});

test('answerQuestion returns a graceful message when nothing is retrieved', async (t) => {
  t.mock.method(retrieve, 'retrieveRelevantChunks', async () => []);
  let llmCalled = false;
  t.mock.method(llmClient, 'generateText', async () => {
    llmCalled = true;
    return 'should not be called';
  });

  const result = await answerQuestion('something totally unrelated');

  assert.equal(result.answer, "I don't have any information on that yet.");
  assert.deepEqual(result.sources, []);
  assert.equal(llmCalled, false);
});

test('answerQuestion grounds the LLM call in retrieved chunks and returns numbered sources', async (t) => {
  t.mock.method(retrieve, 'retrieveRelevantChunks', async (question) => {
    assert.equal(question, 'how do I manage medication for an elderly parent?');
    return [
      {
        text: 'Use pill organizers and reminders.',
        sourceTitle: 'Medication Management',
        sourcePublisher: 'NCBI',
        sourceUrl: 'https://ncbi.example/med',
        sourceCategory: 'internationalGuideline',
      },
    ];
  });

  t.mock.method(llmClient, 'generateText', async ({ system, prompt }) => {
    assert.match(system, /Answer ONLY using the numbered SOURCES/);
    assert.match(prompt, /Use pill organizers and reminders\./);
    return 'Use a pill organizer [1].';
  });

  const result = await answerQuestion('how do I manage medication for an elderly parent?');

  assert.equal(result.answer, 'Use a pill organizer [1].');
  assert.equal(result.sources.length, 1);
  assert.equal(result.sources[0].n, 1);
  assert.equal(result.sources[0].url, 'https://ncbi.example/med');
});
