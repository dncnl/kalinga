# Feature 2: Daily Voice-Log

Living doc — update as work progresses on `feature_2`.

## Feature

Daily voice-log ("how did Grandma sleep, eat, mood today?"), transcribed and
turned into a simple trend chart for family/clinic visibility — addresses the
health-seeking gap where 85% of caregivers report sickness but under half
seek care (Weng et al., 2021). See `CLAUDE.md` for full project context.

## Existing groundwork

- Backend schema already defined in `packages/kalinga_firestore_package/schema/`:
  - `ObservationDocument` — `households/{id}/careRecipients/{id}/observations/{id}`.
    One log entry: `originalAudioAssetId`, `originalText`, `translations`,
    `structuredObservation`, `categories`, `comparisonToUsual`,
    `safetyAssessment`, `observedAt`. `clientWritePolicy: serverOnly`.
  - `DailySummaryDocument` / `WeeklySummaryDocument` — backend-generated
    rollups. `WeeklySummaryDocument.trendSeries` is the 7-day chart data.
  - `AIJobType` already lists `speechToText`, `translation`,
    `structuredObservation` as job types.
  - `storage.rules`: all audio uploads/downloads go through the Node API via
    signed URLs — client never touches Storage directly.
- `apps/api` is currently a bare `package.json` (express, firebase-admin
  declared, no source files yet).
- `apps/mobile/lib/pages/prototype_log_page.dart` — UI prototype for the log
  screen (mic button, 7-day bar chart) with hardcoded fake data, not wired.
- `apps/mobile/lib/pages/viewer_page.dart` — mirrors the same chart for the
  family-facing view, also hardcoded.

## Build order

1. **`apps/api`** — scaffold Express server, Firebase Admin init.
2. **Upload endpoint** — `POST /observations/audio` — issues a signed Storage
   upload URL; caregiver uploads audio client-side, then calls back with the
   asset id.
3. **Processing pipeline** — speech-to-text on the audio → translate to
   Mandarin → extract `structuredObservation` / `categories` /
   `comparisonToUsual` / `safetyAssessment` → write the `observations` doc
   via Admin SDK.
4. **Aggregation job** — rolls a day's `observations` into
   `dailySummaries/{dateKey}`, and a week's `dailySummaries` into
   `weeklySummaries/{weekKey}.trendSeries`.
5. **`apps/mobile`** — wire `/log`'s mic button to real recording (`record`
   package), request signed URL, upload, call the API.
6. **`apps/mobile`** — replace hardcoded chart data in `prototype_log_page.dart`
   with a Firestore stream on `weeklySummaries/{weekKey}`.
7. Mirror step 6 in `viewer_page.dart` for the family-facing chart.

## Open questions

- STT/translation vendor — default assumption: Google Cloud Speech-to-Text +
  Translate (fits the Firebase-centric stack). Needs confirmation.

## Status

- [ ] `apps/api` scaffold
- [ ] Upload endpoint
- [ ] Processing pipeline
- [ ] Aggregation job
- [ ] Mobile: record + upload wiring
- [ ] Mobile: `/log` real trend data
- [ ] Mobile: `/viewer` real trend data
