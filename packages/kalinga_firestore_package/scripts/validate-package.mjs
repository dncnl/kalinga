#!/usr/bin/env node
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');

const EXPECTED_SCHEMA_VERSION = '1.1.0';
const EXPECTED_DOCUMENT_PATHS = [
  "_schema/{version}",
  "appConfig/{configId}",
  "featureFlags/{flagId}",
  "supportedLocales/{localeCode}",
  "governmentServices/{serviceId}",
  "emergencyPhrasebooks/{phrasebookId}",
  "emergencyPhrasebooks/{phrasebookId}/phrases/{phraseId}",
  "terminologyGlossaries/{glossaryId}",
  "terminologyGlossaries/{glossaryId}/entries/{entryId}",
  "knowledgeArticles/{articleId}",
  "trainingModules/{moduleId}",
  "trainingModules/{moduleId}/lessons/{lessonId}",
  "safetyRuleSets/{ruleSetId}",
  "safetyRuleSets/{ruleSetId}/rules/{ruleId}",
  "promptTemplates/{templateId}",
  "modelPolicies/{policyId}",
  "organizations/{organizationId}",
  "organizations/{organizationId}/members/{uid}",
  "organizations/{organizationId}/sites/{siteId}",
  "users/{uid}",
  "users/{uid}/devices/{deviceId}",
  "users/{uid}/preferences/{preferenceId}",
  "users/{uid}/notifications/{notificationId}",
  "users/{uid}/trainingProgress/{moduleId}",
  "users/{uid}/wellbeingCheckIns/{checkInId}",
  "users/{uid}/privateSupportRequests/{requestId}",
  "users/{uid}/privateSupportRequests/{requestId}/messages/{messageId}",
  "users/{uid}/privateSupportRequests/{requestId}/referrals/{referralId}",
  "users/{uid}/privateMediaAssets/{assetId}",
  "users/{uid}/consents/{consentId}",
  "users/{uid}/dataSubjectRequests/{requestId}",
  "users/{uid}/emergencySessions/{sessionId}",
  "households/{householdId}",
  "households/{householdId}/members/{uid}",
  "households/{householdId}/invitations/{invitationId}",
  "households/{householdId}/settings/{settingsId}",
  "households/{householdId}/organizationLinks/{linkId}",
  "households/{householdId}/accessGrants/{grantId}",
  "households/{householdId}/threads/{threadId}",
  "households/{householdId}/threads/{threadId}/messages/{messageId}",
  "households/{householdId}/serviceReferrals/{referralId}",
  "households/{householdId}/mediaAssets/{assetId}",
  "households/{householdId}/careRecipients/{careRecipientId}",
  "households/{householdId}/careRecipients/{careRecipientId}/assignments/{caregiverUid}",
  "households/{householdId}/careRecipients/{careRecipientId}/carePlans/{carePlanId}",
  "households/{householdId}/careRecipients/{careRecipientId}/observations/{observationId}",
  "households/{householdId}/careRecipients/{careRecipientId}/instructions/{instructionId}",
  "households/{householdId}/careRecipients/{careRecipientId}/instructions/{instructionId}/steps/{stepId}",
  "households/{householdId}/careRecipients/{careRecipientId}/instructions/{instructionId}/confirmations/{confirmationId}",
  "households/{householdId}/careRecipients/{careRecipientId}/tasks/{taskId}",
  "households/{householdId}/careRecipients/{careRecipientId}/taskEvents/{taskEventId}",
  "households/{householdId}/careRecipients/{careRecipientId}/medications/{medicationId}",
  "households/{householdId}/careRecipients/{careRecipientId}/medicationEvents/{eventId}",
  "households/{householdId}/careRecipients/{careRecipientId}/measurements/{measurementId}",
  "households/{householdId}/careRecipients/{careRecipientId}/incidents/{incidentId}",
  "households/{householdId}/careRecipients/{careRecipientId}/handovers/{handoverId}",
  "households/{householdId}/careRecipients/{careRecipientId}/appointments/{appointmentId}",
  "households/{householdId}/careRecipients/{careRecipientId}/documents/{documentId}",
  "households/{householdId}/careRecipients/{careRecipientId}/reports/{reportId}",
  "households/{householdId}/careRecipients/{careRecipientId}/alerts/{alertId}",
  "households/{householdId}/careRecipients/{careRecipientId}/dailySummaries/{dateKey}",
  "households/{householdId}/careRecipients/{careRecipientId}/weeklySummaries/{weekKey}",
  "processingJobs/{jobId}",
  "aiRuns/{runId}",
  "notificationOutbox/{messageId}",
  "idempotencyKeys/{keyHash}",
  "auditEvents/{auditId}",
  "scheduledWork/{workId}",
  "migrations/{migrationId}",
  "pilotStudies/{studyId}",
  "pilotStudies/{studyId}/sites/{siteId}",
  "pilotStudies/{studyId}/participants/{participantId}",
  "pilotStudies/{studyId}/sessions/{sessionId}",
  "pilotStudies/{studyId}/feedback/{feedbackId}",
  "pilotStudies/{studyId}/metricSnapshots/{snapshotId}"
];

const readJson = async (relative) => JSON.parse(await fs.readFile(path.join(root, relative), 'utf8'));
const readText = async (relative) => fs.readFile(path.join(root, relative), 'utf8');

function documentPathIsValid(documentPath) {
  const segments = documentPath.split('/').filter(Boolean);
  return segments.length >= 2 && segments.length % 2 === 0;
}

function patternToRegex(pattern) {
  const escaped = pattern.split('/').map((segment) => segment.startsWith('{') && segment.endsWith('}')
    ? '[^/]+'
    : segment.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
  return new RegExp(`^${escaped.join('/')}$`);
}

function exactSetEqual(actual, expected, label) {
  const actualSet = new Set(actual);
  const expectedSet = new Set(expected);
  assert.equal(actualSet.size, actual.length, `${label} contains duplicates.`);
  assert.equal(expectedSet.size, expected.length, `Expected ${label} contains duplicates.`);
  const missing = [...expectedSet].filter((item) => !actualSet.has(item));
  const unexpected = [...actualSet].filter((item) => !expectedSet.has(item));
  assert.deepEqual({ missing, unexpected }, { missing: [], unexpected: [] }, `${label} differs from the locked complete contract.`);
}

async function main() {
  const schema = await readJson('schema/kalinga-firestore-schema.json');
  const manifest = await readJson('schema/contracts-manifest.json');
  const reference = await readJson('data/reference-seed.json');
  const demo = await readJson('data/demo-seed.json');
  const indexes = await readJson('firestore.indexes.json');
  const firebaseConfig = await readJson('firebase.json');
  const packageJson = await readJson('package.json');
  const rules = await readText('firestore.rules');
  const storageRules = await readText('storage.rules');

  assert.equal(schema.version, EXPECTED_SCHEMA_VERSION);
  assert.equal(manifest.version, EXPECTED_SCHEMA_VERSION);
  assert.equal(packageJson.version, EXPECTED_SCHEMA_VERSION);
  assert.equal(schema.database.engine, 'Google Cloud Firestore (Native mode)');
  assert.ok(Array.isArray(schema.collections), 'Schema collections must be an array.');

  const paths = schema.collections.map((collection) => collection.path);
  exactSetEqual(paths, EXPECTED_DOCUMENT_PATHS, 'Authoritative document paths');
  assert.equal(paths.length, 75, 'Kalinga 1.1.0 must retain all 75 document patterns.');
  for (const collectionPath of paths) {
    assert.ok(documentPathIsValid(collectionPath), `Invalid collection document pattern: ${collectionPath}`);
  }

  exactSetEqual(Object.keys(manifest.documents), EXPECTED_DOCUMENT_PATHS, 'Generated-contract manifest paths');
  const interfaceNames = Object.values(manifest.documents).map((entry) => entry.interface);
  const documentHelpers = Object.values(manifest.documents).map((entry) => entry.documentHelper);
  const collectionHelpers = Object.values(manifest.documents).map((entry) => entry.collectionHelper);
  assert.equal(new Set(interfaceNames).size, 75, 'Every document pattern must have a unique interface.');
  assert.equal(new Set(documentHelpers).size, 75, 'Every document pattern must have a unique document helper.');
  assert.equal(new Set(collectionHelpers).size, 75, 'Every document pattern must have a unique collection helper.');

  execFileSync(process.execPath, [path.join(root, 'scripts', 'generate-contracts.mjs'), '--check'], { stdio: 'pipe' });

  const regexes = paths.map((pattern) => ({ pattern, regex: patternToRegex(pattern) }));
  for (const envelope of [reference, demo]) {
    assert.equal(envelope.formatVersion, '1.0.0');
    assert.ok(envelope.documents.length > 0);
    const documentPaths = envelope.documents.map((doc) => doc.path);
    assert.equal(new Set(documentPaths).size, documentPaths.length, `Duplicate seed path in ${envelope.description}`);
    for (const document of envelope.documents) {
      assert.ok(documentPathIsValid(document.path), `Invalid seed path: ${document.path}`);
      assert.ok(regexes.some(({ regex }) => regex.test(document.path)), `Seed path is absent from schema manifest: ${document.path}`);
      assert.equal(typeof document.data, 'object');
    }
  }

  const schema10 = reference.documents.find((doc) => doc.path === '_schema/1.0.0');
  const schema11 = reference.documents.find((doc) => doc.path === '_schema/1.1.0');
  const migration = reference.documents.find((doc) => doc.path === 'migrations/schema-1.0.0-to-1.1.0');
  assert.ok(schema10 && schema11 && migration, 'Version history and 1.1.0 migration records are required.');
  assert.equal(schema10.data.active, false);
  assert.equal(schema11.data.active, true);
  assert.equal(schema11.data.collectionManifest.length, 75);
  assert.equal(migration.data.status, 'completed');
  assert.equal(migration.data.checkpoint.pathsRemoved, 0);
  assert.equal(migration.data.checkpoint.fieldsRemoved, 0);

  const aiDiagnosisFlag = reference.documents.find((doc) => doc.path === 'featureFlags/aiDiagnosis');
  assert.ok(aiDiagnosisFlag, 'Missing explicit AI diagnosis safety flag.');
  assert.equal(aiDiagnosisFlag.data.enabled, false, 'AI diagnosis must be disabled.');

  assert.ok(indexes.indexes.length >= 50, 'Expected comprehensive composite indexes.');
  assert.ok(indexes.fieldOverrides.length >= 20, 'Expected index exemptions for large/sensitive text maps.');
  for (const index of indexes.indexes) {
    assert.ok(index.collectionGroup && index.queryScope && index.fields.length > 0);
  }

  assert.equal(firebaseConfig.firestore.rules, 'firestore.rules');
  assert.equal(firebaseConfig.firestore.indexes, 'firestore.indexes.json');
  assert.equal(firebaseConfig.storage.rules, 'storage.rules');

  assert.ok(rules.startsWith("rules_version = '2';"), 'Firestore rules must use version 2.');
  assert.ok(rules.includes('allow read, write: if false;'), 'Firestore rules must fail closed.');
  assert.ok(rules.includes('privateSupportRequests'), 'Private worker-support boundary missing from rules.');
  assert.ok(rules.includes('isAssignedCaregiver'), 'Care-recipient assignment authorization missing.');
  assert.ok(rules.includes('function canReadApprovedContent(data)'), 'Authenticated approved-content helper missing.');
  assert.ok(rules.includes("signedIn() && data.get('status', '') == 'approved'"), 'Approved internal content must require authentication.');
  assert.ok(!rules.includes("resource.data.status == 'approved' || isPlatformAdmin()"), 'Legacy unauthenticated approved-content rule remains.');
  assert.ok(rules.includes('function canReadVerifiedGovernmentService(data)'), 'Verified government-service public-read helper missing.');
  assert.ok(rules.includes("data.get('verificationStatus', '') == 'verified'"), 'Public government-service reads must require verification.');
  assert.ok(rules.includes("data.get('enabled', false) == true"), 'Public government-service reads must require enabled records.');
  assert.ok(rules.includes('match /supportedLocales/{document=**}'), 'Supported locales must remain modeled as public reference data.');
  assert.ok(rules.includes('match /safetyRuleSets/{ruleSetId}/rules/{ruleId}') || rules.includes('match /rules/{ruleId}'), 'Individual safety rules must have an explicit rule block.');

  const expectedPolicyByPath = {
    'governmentServices/{serviceId}': 'verifiedPublicRead',
    'emergencyPhrasebooks/{phrasebookId}': 'authenticatedApprovedOnly',
    'emergencyPhrasebooks/{phrasebookId}/phrases/{phraseId}': 'authenticatedApprovedOnly',
    'terminologyGlossaries/{glossaryId}': 'authenticatedApprovedOnly',
    'terminologyGlossaries/{glossaryId}/entries/{entryId}': 'authenticatedApprovedOnly',
    'knowledgeArticles/{articleId}': 'authenticatedApprovedOnly',
    'trainingModules/{moduleId}': 'authenticatedApprovedOnly',
    'trainingModules/{moduleId}/lessons/{lessonId}': 'authenticatedApprovedOnly',
    'safetyRuleSets/{ruleSetId}': 'authenticatedApprovedOnly',
    'safetyRuleSets/{ruleSetId}/rules/{ruleId}': 'platformAdminOnly'
  };
  for (const [documentPath, expectedPolicy] of Object.entries(expectedPolicyByPath)) {
    const collection = schema.collections.find((entry) => entry.path === documentPath);
    assert.ok(collection, `Policy target missing: ${documentPath}`);
    assert.equal(collection.clientReadPolicy, expectedPolicy, `Incorrect read policy for ${documentPath}`);
  }

  assert.ok(storageRules.startsWith("rules_version = '2';"), 'Storage rules must use version 2.');
  assert.ok(storageRules.includes('allow read, write: if false;'), 'Sensitive Storage access must fail closed.');

  const report = {
    validatedAt: new Date().toISOString(),
    packageVersion: packageJson.version,
    schemaVersion: schema.version,
    collectionPatterns: paths.length,
    generatedInterfaces: interfaceNames.length,
    documentPathHelpers: documentHelpers.length,
    collectionPathHelpers: collectionHelpers.length,
    referenceDocuments: reference.documents.length,
    demoDocuments: demo.documents.length,
    compositeIndexes: indexes.indexes.length,
    fieldIndexOverrides: indexes.fieldOverrides.length,
    removedPaths: 0,
    removedFields: 0,
    checks: 'PASS'
  };
  await fs.writeFile(path.join(root, 'docs', 'validation-report.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack : error);
  process.exitCode = 1;
});
