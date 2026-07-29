# Feature 2: Daily Voice-Log

Caregiver records a short voice note about the elder's day. It gets
transcribed, translated, and turned into a 7-day trend chart both the
caregiver and family can see.

## What already exists

- `apps/mobile/lib/pages/prototype_log_page.dart` — the log screen UI (mic
  button + chart), but chart data is fake/hardcoded and mic doesn't record.
- `apps/mobile/lib/pages/viewer_page.dart` — same chart, family-facing view.
- `apps/api` — empty, just a `package.json`. Nothing built yet.
- Database schema is already designed (`packages/kalinga_firestore_package`),
  we just need to build against it.

## Steps

1. **Build the API server** (`apps/api`)
   Set up Express + Firebase Admin so it can talk to Firestore/Storage.

2. **Add an upload endpoint**
   Caregiver's phone asks the API for a secure upload link, uploads the
   voice recording there directly (not through Firestore).

3. **Process the recording**
   API transcribes the audio, translates it to Mandarin, and pulls out
   structured info (how they slept/ate/mood, any red flags) and saves it
   as one "observation" entry.

4. **Roll observations into trends**
   A daily/weekly job combines each day's observations into a 7-day trend
   (sleep, food, mood) — this is what the chart reads from.

5. **Wire up the mic button** (mobile)
   Make the mic on the log screen actually record and upload, instead of
   just being decorative.

6. **Connect the chart to real data** (mobile)
   Swap out the fake 7-day numbers for the real trend from step 4.

7. **Do the same for the family view**
   Same trend data, shown on the family-facing screen.

## Open question

- Which service transcribes/translates the audio? Leaning Google Cloud
  Speech-to-Text + Translate since the rest of the stack is Firebase — needs
  confirmation.

## Progress

- [x] API server set up (`apps/api/src/` — Express + lazy Firebase Admin,
      `GET /health`, boots without Firebase creds configured)
- [x] Upload endpoint (`POST /households/:householdId/care-recipients/:careRecipientId/observations/upload-url`
      — auth-gated, checks active caregiver assignment, returns a signed
      Storage PUT URL. Unit-tested with mocks, and smoke-tested live against
      the real `kalinga-bc97f` Firebase project (Firestore read/write +
      Storage signed URL generation both confirmed working). Nothing calls
      this from the mobile app yet.)
- [x] Transcribe + translate + save observation
      (`POST .../observations/:observationId/process` — Google Cloud
      Speech-to-Text → Cloud Translation (→ zh-TW) → Claude extracts
      structured fields (categories, comparisonToUsual, safetyAssessment) →
      writes a full `ObservationDocument`. **Cebuano (ceb) has no
      Speech-to-Text support** — rejected with a clear 400 until we pick a
      workaround or different STT vendor for that locale. Unit-tested only
      (23 tests, all mocked) — NOT yet smoke-tested live: needs Cloud
      Speech-to-Text + Cloud Translation APIs enabled on `kalinga-bc97f` and
      the service account granted access, plus an `ANTHROPIC_API_KEY` in
      `apps/api/.env`.)
- [ ] Daily/weekly trend rollup
- [ ] Mic button records & uploads
- [ ] Log screen shows real trend
- [ ] Family view shows real trend
