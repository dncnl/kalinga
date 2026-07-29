# Changelog

## 1.1.0 — 2026-07-29

Database-package-only update. No operational collection, document path, feature, or field was removed or renamed.

### Added

- Complete TypeScript document interfaces for all 75 authoritative Firestore document patterns.
- Complete collection and document path helpers for all 75 patterns.
- Generated-contract manifest and deterministic contract generator/checker.
- Validation coverage for every authoritative path, generated type, helper, reference seed, index file, and security classification.
- Historical `_schema/1.0.0`, active `_schema/1.1.0`, and a no-op migration record.

### Security

- Approved phrasebooks, terminology, knowledge articles, training modules, lessons, and safety-rule-set metadata now require authentication.
- Individual safety rules remain platform-admin-only.
- Public government-service reads are limited to records whose `verificationStatus` is `verified`.
- Supported-locale metadata remains public.

### Compatibility

- Existing canonical paths are unchanged.
- Existing fields are unchanged.
- New development should use the generated complete types and path helpers.
