const { test } = require('node:test');
const assert = require('node:assert/strict');

const { buildObservationDocument } = require('../../src/lib/buildObservationDocument');

test('buildObservationDocument assembles a full ObservationDocument', () => {
  const extraction = {
    categories: ['sleep', 'mood'],
    comparisonToUsual: 'same',
    structuredObservation: { summary: 'Stable day overall.' },
    safetyAssessment: { concernLevel: 'none', concerns: [], recommendFollowUp: false },
  };

  const doc = buildObservationDocument({
    uid: 'caregiver-1',
    locale: 'fil',
    transcript: 'Original Tagalog transcript.',
    translatedText: '穩定的一天。',
    extraction,
  });

  assert.equal(doc.authorUid, 'caregiver-1');
  assert.equal(doc.inputMode, 'voice');
  assert.equal(doc.originalLanguage, 'fil');
  assert.equal(doc.originalText, 'Original Tagalog transcript.');
  assert.equal(doc.translations['zh-TW'].text, '穩定的一天。');
  assert.deepEqual(doc.categories, ['sleep', 'mood']);
  assert.equal(doc.comparisonToUsual, 'same');
  assert.deepEqual(doc.structuredObservation, extraction.structuredObservation);
  assert.deepEqual(doc.safetyAssessment, extraction.safetyAssessment);
  assert.equal(doc.status, 'ready');
  assert.equal(doc.visibility, 'household');
  assert.equal(doc.version, 1);
  assert.equal(doc.syncState, 'server');

  // createdAt/updatedAt/observedAt should be the same FieldValue sentinel.
  assert.equal(doc.createdAt, doc.updatedAt);
  assert.equal(doc.createdAt, doc.observedAt);
});
