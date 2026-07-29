const { FieldValue } = require('firebase-admin/firestore');

// Assembles an ObservationDocument (see kalinga-firestore-schema.json) from
// the pipeline's outputs. Pure aside from FieldValue sentinels, so it's
// cheap to unit test without touching Firestore.
function buildObservationDocument({ uid, locale, transcript, translatedText, extraction }) {
  const now = FieldValue.serverTimestamp();

  return {
    authorUid: uid,
    inputMode: 'voice',
    originalLanguage: locale,
    originalText: transcript,
    originalAudioAssetId: null,
    translations: {
      'zh-TW': {
        text: translatedText,
        provider: 'google-cloud-translate',
        model: null,
        generatedAt: now,
        reviewedByUser: false,
        reviewedByUid: null,
        reviewedAt: null,
        sourceHash: null,
      },
    },
    structuredObservation: extraction.structuredObservation,
    categories: extraction.categories,
    comparisonToUsual: extraction.comparisonToUsual,
    observedAt: now,
    safetyAssessment: extraction.safetyAssessment,
    visibility: 'household',
    allowedUserIds: [],
    allowedOrganizationIds: [],
    status: 'ready',
    reviewedByAuthor: false,
    reviewedAt: null,
    threadId: null,

    // AuditFields
    createdAt: now,
    createdBy: uid,
    updatedAt: now,
    updatedBy: uid,

    // SoftDeleteFields
    deletedAt: null,
    deletedBy: null,
    deletionReason: null,

    // RetentionFields
    retentionUntil: null,
    legalHold: false,

    // SyncFields
    clientGeneratedId: null,
    clientCreatedAt: null,
    lastModifiedByDeviceId: null,
    version: 1,
    syncState: 'server',
  };
}

module.exports = { buildObservationDocument };
