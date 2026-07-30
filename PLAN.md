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

- [ ] Backend medication CRUD
- [ ] Backend photo-scan pipeline
- [ ] Backend confirm endpoint
- [ ] Backend medication events (generate + mark taken/skipped)
- [ ] Mobile MedicationService
- [ ] Mobile meds_page.dart wired
- [ ] Live test
