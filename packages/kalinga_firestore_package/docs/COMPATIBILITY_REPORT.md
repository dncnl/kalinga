# Schema 1.1.0 compatibility report

This release is additive and database-package-only.

## Unchanged

- All 75 authoritative Firestore document paths.
- Every previously defined feature and collection.
- Existing field names and field contracts.
- Firebase Authentication, Firestore Native mode, Storage, FCM, and backend-controlled write architecture.

## Changed

- Supporting TypeScript definitions now cover the entire master schema.
- Path helpers now cover every collection and document path.
- Internal approved content requires an authenticated user.
- Public government-service reads require `verificationStatus == "verified"`.
- Package validation now fails when a schema path, type, helper, or required security boundary is missing.

## Development impact

No data relocation or deletion is required. Existing direct unauthenticated reads of internal content must authenticate. Public government-service queries must filter for verified records.
