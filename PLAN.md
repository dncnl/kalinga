# Fix: medicine label upload error leaks stack trace + slow meds loading

Branch: `fix/meds-label-upload-and-slow-load`, cut from `main`.

## Bug reports (from Ralph, on Adrian's machine)

1. Medicine label photo upload fails: `Could not read label: Exception:
   Failed to get upload URL: <!DOCTYPE html>...Error: Cannot sign data
   without \`client_email\`...at GoogleAuth.sign...`
2. Meds page takes a very long time to load even with zero medications.

## Root cause (#1) — confirmed, fixed

`getSignedUrl()` in both `medications.js`'s and `observations.js`'s
`/upload-url` routes was called with no try/catch. `getSignedUrl` needs an
actual service-account private key to sign with; `gcloud auth
application-default login` credentials (what `firebase.js` falls back to
when `FIREBASE_SERVICE_ACCOUNT` is unset) have none, so it throws. With no
try/catch, that unhandled rejection fell through to Express's default
error handler, which serves an HTML page — that's the raw stack trace the
caregiver-facing app displayed as an "error" string.

Fix:
- `apps/api/src/lib/signedUploadUrl.js` — new shared
  `getSignedUploadUrl()`, used by both routes (previously duplicated
  inline). Catches the specific "Cannot sign data without `client_email`"
  failure and rewrites it into an actionable message pointing at
  `FIREBASE_SERVICE_ACCOUNT`, instead of leaking the raw
  google-auth-library stack trace.
- Both routes now wrap the call in try/catch and return a clean 502 JSON
  error.
- `.env.example` now explicitly documents that ambient/ADC credentials
  don't work for signed Storage URLs, only for everything else
  (Firestore/Auth/Translate/Speech/Vertex) — this is very likely exactly
  what's misconfigured on Adrian's machine.

## #2 — not root-caused

Read `meds_page.dart`, `medication_service.dart`, and the
`medications`/`medication-events/generate-today` server routes: nothing
scales with medication count in a way that would be slow at zero (both
Firestore queries are scoped + parallelized, no N+1). Best working theory,
not yet confirmed: same root cause as #1 — without
`FIREBASE_SERVICE_ACCOUNT`, every Google API call (not just signing) may
be going through slow ADC credential probing on a non-GCP machine. Ask
Adrian to set `FIREBASE_SERVICE_ACCOUNT` (see above) and re-check before
digging further.

## Status

- [x] #1 fixed: `signedUploadUrl.js` + both routes + `.env.example`
- [x] Tests: `signedUploadUrl.test.js` (3), regression tests on both
      upload-url routes (2) — full backend suite 191/191
- [ ] #2: needs Adrian to confirm/deny after setting
      `FIREBASE_SERVICE_ACCOUNT` — reopen with real timing data if it
      persists
- [ ] PR, merge to `main`
