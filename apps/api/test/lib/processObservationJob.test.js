const { test } = require('node:test');
const assert = require('node:assert/strict');

const firebase = require('../../src/firebase');
const { client: speechClient } = require('../../src/lib/transcribe');
const { client: translateClient } = require('../../src/lib/translate');
const llmClient = require('../../src/lib/llmClient');
const { processObservationJob } = require('../../src/lib/processObservationJob');

const ARGS = {
  householdId: 'h1',
  careRecipientId: 'r1',
  observationId: 'obs-1',
  uid: 'caregiver-1',
  locale: 'fil',
  storagePath: 'households/h1/careRecipients/r1/observations/obs-1/audio.m4a',
};

function mockPipelineSuccess(t) {
  t.mock.method(firebase, 'getBucket', () => ({ name: 'kalinga-bc97f.firebasestorage.app' }));
  t.mock.method(speechClient, 'recognize', async () => [
    { results: [{ alternatives: [{ transcript: 'Natulog siya nang mahusay.' }] }] },
  ]);
  t.mock.method(translateClient, 'translateText', async () => [
    { translations: [{ translatedText: '他睡得很好。' }] },
  ]);
  t.mock.method(llmClient, 'generateStructured', async () => ({
    categories: ['sleep'],
    comparisonToUsual: 'same',
    structuredObservation: { summary: 'Slept well.' },
    safetyAssessment: { concernLevel: 'none', concerns: [], recommendFollowUp: false },
  }));
}

test('runs the full pipeline, saves the observation, and triggers rollup', async (t) => {
  mockPipelineSuccess(t);

  let savedDoc;
  let dailyCalled = false;
  let weeklyCalled = false;
  t.mock.method(firebase.db, 'doc', () => ({
    path: 'households/h1/careRecipients/r1/observations/obs-1',
    set: async (doc) => { savedDoc = doc; },
    update: async () => {},
  }));
  t.mock.method(firebase.db, 'collection', () => ({
    where: () => ({ get: async () => ({ docs: [] }) }),
  }));
  const rollupDaily = require('../../src/lib/rollupDailySummary');
  const rollupWeekly = require('../../src/lib/rollupWeeklySummary');
  t.mock.method(rollupDaily, 'computeAndSaveDailySummary', async () => { dailyCalled = true; return {}; });
  t.mock.method(rollupWeekly, 'computeAndSaveWeeklySummary', async () => { weeklyCalled = true; return {}; });

  await processObservationJob(ARGS);

  assert.equal(savedDoc.authorUid, 'caregiver-1');
  assert.equal(savedDoc.originalText, 'Natulog siya nang mahusay.');
  assert.equal(savedDoc.translations['zh-TW'].text, '他睡得很好。');
  assert.equal(savedDoc.originalAudioAssetId, ARGS.storagePath);
  assert.equal(savedDoc.status, 'ready');
  assert.equal(savedDoc.processingError, null);
  assert.equal(dailyCalled, true);
  assert.equal(weeklyCalled, true);
});

test('marks the observation cancelled (with a processingError) when no speech is detected, and never rolls up', async (t) => {
  t.mock.method(firebase, 'getBucket', () => ({ name: 'bucket' }));
  t.mock.method(speechClient, 'recognize', async () => [{ results: [] }]);

  let updatedDoc;
  let translateCalled = false;
  let rollupCalled = false;
  t.mock.method(firebase.db, 'doc', () => ({
    update: async (data) => { updatedDoc = data; },
  }));
  t.mock.method(translateClient, 'translateText', async () => {
    translateCalled = true;
    return [{ translations: [{ translatedText: '' }] }];
  });
  const rollupDaily = require('../../src/lib/rollupDailySummary');
  t.mock.method(rollupDaily, 'computeAndSaveDailySummary', async () => { rollupCalled = true; return {}; });

  await processObservationJob(ARGS);

  assert.equal(updatedDoc.status, 'cancelled');
  assert.match(updatedDoc.processingError, /No speech detected/);
  assert.equal(translateCalled, false);
  assert.equal(rollupCalled, false);
});

test('marks the observation cancelled (with the real error) when the pipeline throws, and never crashes', async (t) => {
  t.mock.method(firebase, 'getBucket', () => ({ name: 'bucket' }));
  t.mock.method(speechClient, 'recognize', async () => {
    throw new Error('STT quota exceeded');
  });

  let updatedDoc;
  t.mock.method(firebase.db, 'doc', () => ({
    update: async (data) => { updatedDoc = data; },
  }));

  await processObservationJob(ARGS); // must not throw

  assert.equal(updatedDoc.status, 'cancelled');
  assert.match(updatedDoc.processingError, /STT quota exceeded/);
});
