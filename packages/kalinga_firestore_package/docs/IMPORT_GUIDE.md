# Import and Deployment Guide

## Import order

1. Create/choose the Firebase project.
2. Enable Firestore Native mode, Authentication, and Storage.
3. Deploy `firestore.rules`, `firestore.indexes.json`, and `storage.rules`.
4. Wait for index creation where practical.
5. Import `data/reference-seed.json` with `scripts/seed-firestore.mjs`.
6. Verify the seeded `_schema/1.0.0` and `appConfig/current` documents.
7. Review and approve draft public content before exposing it to ordinary users.
8. Connect the Node.js API and configure secrets outside Firestore.
9. Run emulator/API authorization tests before creating real household data.

## Import command

```bash
node scripts/seed-firestore.mjs data/reference-seed.json \
  --project YOUR_FIREBASE_PROJECT_ID
```

Options:

- `--dry-run`: validate and list paths without writing.
- `--merge`: merge seed fields into existing documents.
- `--allow-demo`: required before importing the fictional demo seed.
- `--project PROJECT_ID`: explicit Firebase/Google Cloud project ID.

## Supported special JSON values

The importer recognizes:

```json
{ "__type": "serverTimestamp" }
```

```json
{ "__type": "timestamp", "value": "2026-07-29T00:00:00+08:00" }
```

```json
{ "__type": "reference", "path": "governmentServices/1955" }
```

```json
{ "__type": "deleteField" }
```

## Why the import does not create every collection

Firestore collections do not exist independently from documents. Creating placeholder documents in every collection would pollute queries and require special filtering. The package instead imports the schema manifest and reference documents; operational collections are created through validated application workflows.

## Rollback

The seed importer does not currently delete documents. For rollback:

1. export the affected reference collections before an update;
2. use a new schema/config version rather than mutating approved historical records where possible;
3. mark old content `retired`;
4. deploy a migration script with a recorded `migrations/{migrationId}` document; and
5. avoid manual production deletion without an audit trail.
