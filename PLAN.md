# Feature 4: Basic Med-Reminder + Dosage Photo-Recognition

Caregiver can log a caregiver's medications (manually or by photographing
the label), get reminded when doses are due, and mark them taken. Directly
targets the training gap: 22% of caregivers arrive with no elder-care
training (Wu et al., 2022) — medication errors are one of the most
dangerous consequences of that gap.

## What already exists

- Firestore schema already models this fully:
  `households/{id}/careRecipients/{id}/medications/{id}` (verified
  medication instruction — name, dosageText, schedule, route,
  `sourceType`: `familyEntry`/`clinicianDocument`/`labelOcrDraft`,
  `verificationStatus`: `unverified`/`familyConfirmed`/`clinicianConfirmed`,
  `ocrDraft` map) and `.../medicationEvents/{id}` (a scheduled reminder +
  caregiver-recorded outcome). The schema's own stated purpose for
  `medications` is blunt about the safety constraint: **"never inferred
  solely from pill appearance"** — a photo scan must always produce an
  unverified draft a human confirms, never something auto-trusted.
- `apps/mobile/lib/pages/meds_page.dart` already has matching prototype UI:
  a "Scan label" camera box and a fake med list with "Mark taken" buttons —
  unwired, same situation every other feature started in.
- Household/care-recipient auth model (`isCaregiverAssigned`,
  `isHouseholdMember`) already built and reusable as-is.

## Decision made before starting

OCR/vision: **OpenRouter free-tier vision model**, consistent with the
rest of the project (RAG/extraction already use OpenRouter). Known risk,
explicitly acknowledged before starting: free-tier text quality has been
rough elsewhere this session (garbled words in the voice-log extraction,
an inverted 0-1 score). For a medication dose that's a real safety
concern — which is exactly why the schema already forces human
confirmation before anything from a photo scan is trusted. That
confirmation step is not optional in this implementation.

## Steps

1. **Backend: medication CRUD** — create (manual entry), list, update,
   soft-delete. Same shape as Feature 5's care-recipient CRUD.
2. **Backend: photo-scan pipeline** — signed upload URL for the label
   photo (same pattern as voice-log audio), a process endpoint that sends
   the image to a vision LLM and extracts a structured draft, saved as a
   medication doc with `verificationStatus: 'unverified'` /
   `sourceType: 'labelOcrDraft'` — never auto-confirmed.
3. **Backend: confirm endpoint** — caregiver reviews/edits the draft and
   confirms it, flipping `verificationStatus` to `familyConfirmed`. Until
   this happens the medication is clearly a draft, not a real schedule.
4. **Backend: medication events** — generate today's/upcoming reminder
   events for a medication (on-demand, no scheduler — same pragmatic
   choice as the voice-log rollup), and mark an event taken/skipped.
5. **Mobile: MedicationService** — wraps all of the above.
6. **Mobile: wire `meds_page.dart`** — scan → upload → show draft for
   confirmation (not silently accepted) → real med list → real mark-taken.
7. **Test live** against real Firebase, same rigor as every prior feature.

## Progress

- [x] Backend medication CRUD — `apps/api/src/routes/medications.js`:
      POST/GET/PATCH/DELETE (soft, `status: 'cancelled'`) on
      `.../medications`. Manual entries save `sourceType: 'familyEntry'`,
      `verificationStatus: 'familyConfirmed'` immediately (a human typed it).
- [x] Backend photo-scan pipeline — `upload-url` (signed write URL, same
      pattern as voice-log audio) + `:medicationId/process` (signed *read*
      URL so OpenRouter can fetch the image, sends to a vision model via new
      `apps/api/src/lib/extractMedicationLabel.js`, saves the result as
      `verificationStatus: 'unverified'` / `sourceType: 'labelOcrDraft'` —
      never auto-confirmed). 3 free vision models tried in fallback order
      (`google/gemma-4-31b-it:free`, `google/gemma-4-26b-a4b-it:free`,
      `nvidia/nemotron-nano-12b-v2-vl:free`), same fallback-chain pattern as
      `extractObservation.js`.
- [x] Backend confirm endpoint — `POST :medicationId/confirm`, lets the
      caregiver edit any field before flipping `verificationStatus` to
      `familyConfirmed`. Not calling it leaves the medication permanently
      `unverified` — the safe default.
- [x] Backend medication events — `POST /medication-events/generate-today`
      (idempotent: only creates events for `(medicationId, time)` pairs that
      don't already have one today, so it can't reset an already-recorded
      'completed' back to 'scheduled'), `GET /medication-events` (today's
      events), `PATCH /medication-events/:id` (mark
      completed/skipped/refused/notAvailable/needsClarification). Only
      confirmed medications (`verificationStatus != 'unverified'`) generate
      events.
- [x] Unit tests — `apps/api/test/routes/medications.test.js`, 18 tests, all
      passing (mocked Firestore + mocked `fetch` for the vision call, same
      pattern as `observations-process.test.js`). Full suite: 124/127 pass;
      the 3 failures are pre-existing OpenRouter rate-limit flakes in
      `extractObservation` tests, unrelated to this branch.
- [x] Mobile MedicationService — `apps/mobile/lib/services/medication_service.dart`,
      wraps CRUD + upload-url/process/confirm + events (generate-today,
      list, mark). Fixed a bug found while wiring this up: Firestore
      `Timestamp` was serializing as `{_seconds, _nanoseconds}` in the
      events GET response instead of an ISO string — fixed in
      `medications.js` by converting explicitly with `.toDate().toISOString()`
      before `res.json()`.
- [x] Mobile meds_page.dart wired — real scan (image_picker camera) →
      upload → process → review/edit bottom sheet (draft is never silently
      accepted — caregiver sees every extracted field and must tap Confirm)
      → real medication + event list → real mark-taken. Added `image_picker`
      dependency, `CAMERA` permission (Android manifest) and
      `NSCameraUsageDescription` (iOS Info.plist).
- [x] Live test — backend CRUD + medication-events flow run against the
      real `kalinga-bc97f` Firestore project (auth mocked in-process since
      no client SDK was available in this environment to mint a real ID
      token; all Firestore reads/writes were real, using the
      `demo-household` bypass). Full flow verified: create → list → patch →
      generate-today (created exactly 1 event) → idempotency (re-running
      generate-today created 0 more) → mark completed → regenerate again
      (confirmed a completed event is never reset back to 'scheduled') →
      soft-delete. Test data cleaned up afterward.
      **Bug found and fixed**: `generate-today`'s Firestore query
      (`status == 'active'` combined with `verificationStatus != 'unverified'`)
      needed a composite index and failed with `FAILED_PRECONDITION` in
      production — the mocked unit tests didn't catch this since they don't
      exercise real Firestore query planning. Fixed by dropping the second
      `where` and filtering `verificationStatus` in memory instead (medication
      counts per elder are small; not worth provisioning an index for).
      **Not exercised live**: the photo-scan `/process` endpoint (real
      vision-model call) — skipped to avoid burning OpenRouter's rate-limited
      free-tier quota on a throwaway run; the mocked unit test covers success
      and all-models-fail paths. Mobile UI (camera capture → confirm sheet →
      real list) has not been run on an actual device/emulator in this
      environment — needs a manual pass before calling Feature 4 done.
