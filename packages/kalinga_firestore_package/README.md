# Kalinga Firestore Schema Package

Import-ready Cloud Firestore data model for **Kalinga: an AI Care Companion for Migrant Caregivers**.

This package is based on the current architecture shown in the project document:

- Flutter mobile application
- Node.js/Express API
- Firebase Authentication
- Cloud Firestore
- Cloud Storage for Firebase
- Firebase Cloud Messaging
- server-side speech, translation, OCR, LLM, and reviewed-knowledge services

## What is included

| File | Purpose |
|---|---|
| `schema/kalinga-firestore-schema.json` | Authoritative machine-readable catalog of 75 document-path patterns, field contracts, ownership, retention, and queries |
| `firestore.rules` | Read-only client access with role, assignment, visibility, and private-worker-support boundaries |
| `firestore.indexes.json` | Composite indexes and exemptions for large text/maps |
| `storage.rules` | Backend-only sensitive-file access using signed URLs |
| `data/reference-seed.json` | Importable reference/configuration documents |
| `data/demo-seed.json` | Optional fictional emulator data; never use in production |
| `scripts/seed-firestore.mjs` | Idempotent JSON-to-Firestore importer |
| `scripts/validate-package.mjs` | Structural and safety validation |
| `docs/` | Full data model, ERD, traceability, security, API boundaries, and validation report |

## Important Firestore limitation

Cloud Firestore is schemaless. There is no native SQL-style `CREATE TABLE` file that creates empty collections and enforces column types.

This package establishes the schema through:

1. a machine-readable collection and field catalog;
2. Firestore Security Rules;
3. composite indexes;
4. server-side validation expectations;
5. version and migration records; and
6. an importer that creates reference documents.

Operational collections such as observations, instructions, medications, and support requests are created automatically when the application writes its first validated document.

## Safety decisions already enforced in the model

- AI diagnosis is explicitly disabled.
- Kalinga stores **structured observations**, not autonomous diagnoses.
- Medication dosage is never inferred solely from pill appearance.
- OCR output is an unverified draft until confirmed by an authorized family member or clinician.
- Original caregiver text/audio is preserved separately from AI output.
- Confidential worker-support records are stored outside the household tree.
- Government hotlines are routing targets, not represented as app users or guaranteed integrations.
- All sensitive writes go through the Node.js API.
- Cloud Storage is closed to direct client access except public assets.

## Requirements

- Node.js 20 or newer
- npm
- A Firebase project with Firestore Native mode, Authentication, and Storage enabled
- Firebase CLI access
- Google Application Default Credentials or a service-account credential for production seeding

Never commit a service-account JSON file.

## 1. Install dependencies

```bash
npm install
```

## 2. Configure the Firebase project

Copy the example project configuration:

```bash
cp .firebaserc.example .firebaserc
```

Replace `YOUR_FIREBASE_PROJECT_ID` with the correct project ID.

Then authenticate and select the project:

```bash
npx firebase-tools login
npx firebase-tools use YOUR_FIREBASE_PROJECT_ID
```

## 3. Validate the package

```bash
npm run validate
```

This checks collection-path structure, duplicate documents, seed/schema alignment, required safety records, index coverage, fail-closed rules, and required domain collections.

## 4. Deploy rules and indexes

```bash
npm run deploy:firebase
```

Firebase may take time to build the composite indexes. Do not launch production queries until required indexes show as ready.

## 5. Dry-run the reference import

```bash
npm run seed:reference -- --project YOUR_FIREBASE_PROJECT_ID --dry-run
```

## 6. Import the reference documents

Set Application Default Credentials. One supported approach is:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/absolute/path/to/service-account.json"
```

Then run:

```bash
npm run seed:reference -- --project YOUR_FIREBASE_PROJECT_ID
```

The importer overwrites only the explicitly listed reference document paths. It does not delete other data.

Use `--merge` to merge instead of replace:

```bash
npm run seed:reference -- --project YOUR_FIREBASE_PROJECT_ID --merge
```

## Local emulator workflow

Start the Firebase emulators:

```bash
npm run emulators
```

In another terminal:

```bash
export FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
npm run seed:reference -- --project kalinga-local
npm run seed:demo -- --project kalinga-local
```

The demo seed uses fictional records and invalid `.example.invalid` email addresses. It must not be imported into production.

## Server authorization requirement

Firebase Admin SDK calls bypass Cloud Firestore Security Rules. The Node.js API must therefore perform all authorization before every Admin SDK operation, including:

- Firebase ID-token verification;
- account status;
- active household membership;
- role and permission;
- active care-recipient assignment;
- consent and visibility;
- private-versus-household boundary;
- expected document version;
- idempotency key;
- retention/deletion state; and
- audit event creation.

See `docs/SECURITY_MODEL.md` and `docs/API_BOUNDARIES.md`.

## Reference data is intentionally marked as draft

The seeded government directory, emergency phrases, terminology glossary, and routing rule set contain usable structural examples, but entries are marked `draft` or `requiresPreLaunchVerification` where appropriate.

Before production:

1. verify service scope, languages, hours, links, and numbers against official Taiwan sources;
2. obtain native-language review;
3. obtain clinical review for care and emergency wording;
4. approve the phrasebook, glossary, and rule-set records; and
5. record reviewer identities and approval timestamps.

The current Security Rules expose approved phrasebooks, glossaries, training content, and safety rule sets only. Platform administrators may inspect drafts.

## Recommended backend validation

Use `schema/kalinga-firestore-schema.json` as the source contract and implement Zod schemas in the Express API. Reject unknown fields for sensitive records and create all `createdAt`, `updatedAt`, ownership, and audit fields on the server.

## Package review status

The package includes a generated validation report at `docs/validation-report.json` after running `npm run validate`.

No schema can permanently guarantee that future product requirements will never require a migration. This package therefore includes `_schema`, `migrations`, versioned prompts, glossaries, rules, care plans, and content so changes can be introduced safely without silently rewriting historical records.
