#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

function parseArgs(argv) {
  const args = { file: null, projectId: process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || null, dryRun: false, allowDemo: false, merge: false };
  const tokens = [...argv];
  while (tokens.length) {
    const token = tokens.shift();
    if (!token) continue;
    if (!token.startsWith('--') && !args.file) args.file = token;
    else if (token === '--project') args.projectId = tokens.shift() || null;
    else if (token === '--dry-run') args.dryRun = true;
    else if (token === '--allow-demo') args.allowDemo = true;
    else if (token === '--merge') args.merge = true;
    else throw new Error(`Unknown argument: ${token}`);
  }
  if (!args.file) throw new Error('Usage: node scripts/seed-firestore.mjs <seed.json> [--project PROJECT_ID] [--dry-run] [--merge] [--allow-demo]');
  return args;
}

function assertDocumentPath(documentPath) {
  const segments = documentPath.split('/').filter(Boolean);
  if (segments.length < 2 || segments.length % 2 !== 0) {
    throw new Error(`Invalid Firestore document path (must have an even number of segments): ${documentPath}`);
  }
  if (segments.some((segment) => segment === '.' || segment === '..' || segment.includes('//'))) {
    throw new Error(`Unsafe Firestore document path: ${documentPath}`);
  }
}

function transformSpecialValues(value, db) {
  if (Array.isArray(value)) return value.map((item) => transformSpecialValues(item, db));
  if (value && typeof value === 'object') {
    if (value.__type === 'serverTimestamp') return transformSpecialValues.FieldValue.serverTimestamp();
    if (value.__type === 'timestamp') {
      const date = new Date(value.value);
      if (Number.isNaN(date.getTime())) throw new Error(`Invalid timestamp: ${value.value}`);
      return transformSpecialValues.Timestamp.fromDate(date);
    }
    if (value.__type === 'reference') {
      assertDocumentPath(value.path);
      return db.doc(value.path);
    }
    if (value.__type === 'deleteField') return transformSpecialValues.FieldValue.delete();
    return Object.fromEntries(Object.entries(value).map(([key, child]) => [key, transformSpecialValues(child, db)]));
  }
  return value;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const absoluteFile = path.resolve(args.file);
  const raw = JSON.parse(await fs.readFile(absoluteFile, 'utf8'));
  if (!raw || typeof raw !== 'object' || typeof raw.formatVersion !== 'string' || !Array.isArray(raw.documents) || raw.documents.length === 0) {
    throw new Error('Seed file must contain formatVersion and a non-empty documents array.');
  }
  for (const document of raw.documents) {
    if (!document || typeof document.path !== 'string' || !document.data || typeof document.data !== 'object' || Array.isArray(document.data)) {
      throw new Error('Each seed document must contain a string path and an object data value.');
    }
  }
  const parsed = raw;

  if (absoluteFile.includes('demo-seed') && !args.allowDemo) {
    throw new Error('Refusing to import demo data without --allow-demo. Demo records are fictional and must not be used in production.');
  }

  const duplicateCheck = new Set();
  for (const document of parsed.documents) {
    assertDocumentPath(document.path);
    if (duplicateCheck.has(document.path)) throw new Error(`Duplicate document path: ${document.path}`);
    duplicateCheck.add(document.path);
  }

  const emulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
  if (!args.projectId && !emulator) {
    throw new Error('Provide --project PROJECT_ID or set GCLOUD_PROJECT/GOOGLE_CLOUD_PROJECT. GOOGLE_APPLICATION_CREDENTIALS should point to a service-account file for production imports.');
  }
  const projectId = args.projectId || 'kalinga-local-emulator';

  if (args.dryRun) {
    console.log(`[dry-run] Valid seed file: ${absoluteFile}`);
    console.log(`[dry-run] Project: ${projectId}${emulator ? ' (emulator)' : ''}`);
    console.log(`[dry-run] Documents: ${parsed.documents.length}`);
    for (const document of parsed.documents.slice(0, 10)) console.log(`  - ${document.path}`);
    if (parsed.documents.length > 10) console.log(`  ... and ${parsed.documents.length - 10} more`);
    return;
  }

  const [{ initializeApp, applicationDefault, getApps }, { getFirestore, FieldValue, Timestamp }] = await Promise.all([
    import('firebase-admin/app'),
    import('firebase-admin/firestore')
  ]);

  // Bind special-value conversion after the Admin SDK is available.
  transformSpecialValues.FieldValue = FieldValue;
  transformSpecialValues.Timestamp = Timestamp;

  const app = getApps()[0] ?? initializeApp({
    projectId,
    ...(emulator ? {} : { credential: applicationDefault() })
  });
  const db = getFirestore(app);
  db.settings({ ignoreUndefinedProperties: true });

  const chunkSize = 400;
  let imported = 0;
  for (let start = 0; start < parsed.documents.length; start += chunkSize) {
    const batch = db.batch();
    const chunk = parsed.documents.slice(start, start + chunkSize);
    for (const document of chunk) {
      const data = transformSpecialValues(document.data, db);
      batch.set(db.doc(document.path), data, { merge: args.merge });
    }
    await batch.commit();
    imported += chunk.length;
    console.log(`Imported ${imported}/${parsed.documents.length} documents...`);
  }

  console.log(`Done. Imported ${imported} documents into project ${projectId}${emulator ? ' using the Firestore emulator' : ''}.`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack : error);
  process.exitCode = 1;
});
