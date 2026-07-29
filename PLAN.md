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

- STT/translate: Google Cloud Speech-to-Text + Cloud Translation, confirmed.
  **Cebuano (ceb) has no Speech-to-Text support** — still unresolved, needs a
  different vendor or a text-only fallback for that locale.
- Structured extraction (categories/mood/safety flags from transcript):
  originally planned to use Claude, but no billing available. Switched to
  OpenRouter's free tier (`openai/gpt-oss-20b:free`). Works, but text-quality
  is rough at times (garbled words in free-text fields) — fine for
  prototyping, worth revisiting once there's budget for a better model.

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
      Speech-to-Text → Cloud Translation (→ zh-TW) → OpenRouter free-tier
      model extracts structured fields (categories, comparisonToUsual,
      safetyAssessment) → writes a full `ObservationDocument`. Cebuano is
      rejected with a clear 400 (see open question). 33 unit tests, all
      mocked. Live-smoke-tested the extraction step against the real
      OpenRouter API — works, output text quality is rough (see open
      question) but structurally correct. Cloud Translation and
      Speech-to-Text both confirmed live too (APIs enabled + IAM granted on
      `kalinga-bc97f`) — Translation returned a real result, STT correctly
      reached "file not found" on a fake path (i.e. got past auth). Only
      thing NOT yet tested live is a real audio file end to end.)
- [ ] Daily/weekly trend rollup
- [ ] Mic button records & uploads
- [ ] Log screen shows real trend
- [ ] Family view shows real trend
