#!/usr/bin/env node
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');

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

async function main() {
  const schema = await readJson('schema/kalinga-firestore-schema.json');
  const reference = await readJson('data/reference-seed.json');
  const demo = await readJson('data/demo-seed.json');
  const indexes = await readJson('firestore.indexes.json');
  const firebaseConfig = await readJson('firebase.json');
  const rules = await readText('firestore.rules');
  const storageRules = await readText('storage.rules');

  assert.equal(schema.version, '1.0.0');
  assert.equal(schema.database.engine, 'Google Cloud Firestore (Native mode)');
  assert.ok(Array.isArray(schema.collections) && schema.collections.length >= 60, 'Expected a comprehensive collection catalog.');

  const paths = schema.collections.map((collection) => collection.path);
  assert.equal(new Set(paths).size, paths.length, 'Collection paths must be unique.');
  for (const collectionPath of paths) assert.ok(documentPathIsValid(collectionPath), `Invalid collection document pattern: ${collectionPath}`);

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
  assert.ok(storageRules.startsWith("rules_version = '2';"), 'Storage rules must use version 2.');
  assert.ok(storageRules.includes('allow read, write: if false;'), 'Sensitive Storage access must fail closed.');

  const requiredPaths = [
    'users/{uid}/privateSupportRequests/{requestId}',
    'households/{householdId}/careRecipients/{careRecipientId}/carePlans/{carePlanId}',
    'households/{householdId}/careRecipients/{careRecipientId}/observations/{observationId}',
    'households/{householdId}/careRecipients/{careRecipientId}/instructions/{instructionId}',
    'households/{householdId}/careRecipients/{careRecipientId}/instructions/{instructionId}/confirmations/{confirmationId}',
    'households/{householdId}/careRecipients/{careRecipientId}/medications/{medicationId}',
    'households/{householdId}/careRecipients/{careRecipientId}/reports/{reportId}',
    'processingJobs/{jobId}',
    'aiRuns/{runId}',
    'auditEvents/{auditId}',
    'pilotStudies/{studyId}/metricSnapshots/{snapshotId}'
  ];
  for (const required of requiredPaths) assert.ok(paths.includes(required), `Required collection missing: ${required}`);

  const report = {
    validatedAt: new Date().toISOString(),
    schemaVersion: schema.version,
    collectionPatterns: paths.length,
    referenceDocuments: reference.documents.length,
    demoDocuments: demo.documents.length,
    compositeIndexes: indexes.indexes.length,
    fieldIndexOverrides: indexes.fieldOverrides.length,
    checks: 'PASS'
  };
  await fs.writeFile(path.join(root, 'docs', 'validation-report.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack : error);
  process.exitCode = 1;
});
