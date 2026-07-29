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
- [ ] Upload endpoint
- [ ] Transcribe + translate + save observation
- [ ] Daily/weekly trend rollup
- [ ] Mic button records & uploads
- [ ] Log screen shows real trend
- [ ] Family view shows real trend
