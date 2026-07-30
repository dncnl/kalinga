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
      reached "file not found" on a fake path (i.e. got past auth). Full
      real-audio end-to-end test done later, see the Step 5 update below —
      found and fixed 3 more real bugs in the process.)
- [x] Daily/weekly trend rollup
      (`POST .../rollup/daily` and `POST .../rollup/weekly`, same
      auth+assignment gating as the other routes. Daily summary counts
      categories/alerts/unresolved concerns from that day's observations.
      Weekly summary averages `sleepQuality`/`appetiteLevel`/`moodScore`
      per day into `trendSeries.{sleep,food,mood}` — added those 3 numeric
      0-1 fields to the extraction schema in Step 3 since the chart needs
      numbers, not prose. Days with no observations default to a neutral
      0.5 placeholder (not a real reading — worth revisiting, e.g.
      carry-forward the last known value, once there are real users). No
      scheduler wired up — these run on demand for now, not on a cron.
      52 unit tests total in `apps/api` now, all passing, plus a live
      smoke test against real Firestore.)
- [x] Mic button records & uploads
      (`prototype_log_page.dart` — hold-to-record using the `record`
      package (WAV/LINEAR16, 16kHz mono — see update below for why not
      AAC/m4a), then `ObservationService.submitVoiceLog()` runs the full
      pipeline: upload-url → PUT to signed URL → process. Shows a snackbar
      with the result categories, or the error, when done.
      **Stopgaps, not real infra:**
        - No sign-in screen exists anywhere in the app yet — uses Firebase
          anonymous auth just to get a real ID token for `requireAuth`.
        - `householdId`/`careRecipientId` are hardcoded to match the
          existing fake "Lola Rosa" prototype data, not read from any real
          profile-selection state (multi-patient profiles aren't wired up).
        - `locale` hardcoded to `fil` — language selection isn't connected
          to shared state either.
        - `apiBaseUrl` defaults to the Android-emulator-only
          `10.0.2.2:8081`; override via `--dart-define=API_BASE_URL=...`
          for a real device. Nothing is deployed — this only works against
          a locally-running `apps/api`.
      Added `RECORD_AUDIO`/`INTERNET` (Android) and
      `NSMicrophoneUsageDescription` (iOS) permissions.
      Along the way, fixed a pre-existing bug (unrelated to this feature)
      blocking ALL Android builds: `android/app/build.gradle.kts` used the
      `kotlin { compilerOptions {...} }` DSL without ever applying the
      `org.jetbrains.kotlin.android` plugin — added the missing
      `id("org.jetbrains.kotlin.android")`.
      Update: `google-services.json` + `lib/firebase_options.dart` now
      generated via `flutterfire configure` (both gitignored — client
      Firebase config, not secret, but following the repo's existing
      convention). `main.dart` now calls
      `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
      instead of the old bare/bypassed call. Enabled Anonymous auth in the
      Firebase console (required for the stopgap auth to work at all).

      **Ran a full live end-to-end test** (record → upload-url → PUT →
      process, using a real spoken WAV generated via Windows SAPI TTS
      standing in for a mic recording, and a real anonymous ID token) and
      found + fixed three real bugs along the way, not just config gaps:
        1. Google Speech-to-Text does not support AAC/M4A at all (only
           LINEAR16, FLAC, MULAW, AMR, OGG_OPUS, WEBM_OPUS, MP3) — would
           have failed on every real recording. Switched mobile recording
           from `AudioEncoder.aacLc` to `AudioEncoder.wav`
           (16kHz/mono, matching `transcribe.js`'s now-explicit
           `encoding`/`sampleRateHertz` — relying on auto-detection from
           the container header was unreliable).
        2. The `/process` route fed STT's transcript straight into Cloud
           Translation with no empty-string guard — a no-speech-detected
           recording (silence, or just noise) would 502 instead of
           failing cleanly. Added a check: empty transcript now returns
           422 "No speech detected in recording" before translate/extract
           ever run.
        3. `firebase.app.options.projectId` is `undefined` at runtime —
           the Admin SDK doesn't surface the project id back onto
           `.options` just because it was embedded in the service-account
           cert. `translateToMandarin()` was silently building
           `parent: "projects/undefined/locations/global"`, which Google
           rejected as `PERMISSION_DENIED` (not a clearer error). Added a
           `projectId` export to `firebase.js` (derived from the same
           service-account JSON already used for `googleAuthOptions()`)
           as the one source of truth; the route now uses that instead.

      After those fixes, the full pipeline ran correctly against real
      Firebase: real transcript in, correct Mandarin translation out,
      correct categories/comparisonToUsual, safety assessment appropriately
      flagged, `ObservationDocument` saved.

      **New data-quality issue found, not yet fixed:** in that live run,
      `sleepQuality`/`appetiteLevel` both came back `1` (best/max) despite
      the transcript describing poor sleep and low appetite — the free
      extraction model inverted the 0-1 scale direction. Since this feeds
      `trendSeries` directly (Step 4), a bad score here shows up on the
      chart as "great" when the caregiver said the opposite. Same root
      cause as the "text-quality is rough" open question above — needs a
      better model or much more constrained prompting to trust for
      anything beyond a prototype demo.

      Still not tested: Android on an actual device/emulator (Windows was
      the fastest path to prove the plumbing works at all); the mobile
      app's own `submitVoiceLog()` call path end-to-end (this test drove
      the API directly with a script, not through the Flutter UI).)
- [x] Log screen shows real trend
      (`prototype_log_page.dart` — `StreamBuilder` on
      `weeklySummaries/{weekKey}`, live-updating chart from
      `trendSeries.{sleep,food,mood}`. Falls back to a neutral 0.5×7
      placeholder while loading or before any data exists for the week.
      `week_key.dart` defines the shared week convention: starts most
      recent Sunday UTC, not a true ISO week label — simpler, avoids
      year-boundary edge cases, and nothing server-side enforces the
      schema's "ISOWeek" hint anyway (caller picks the `weekKey` string).
      Since no scheduler exists, `ObservationService.submitVoiceLog()` now
      triggers both rollup endpoints itself right after a successful
      `process` call, so the chart has something to show without a manual
      rollup step. Value/unit labels changed from the old fake
      "6 hours"/"0.5 of meal" to "{score}% quality"/"{score}% of usual" —
      we only ever measure a 0-1 quality score, not real hours/portions,
      so the old units were fabricated precision.
      NOT verified by actually pressing the mic in the running app (no
      GUI/mic-input automation available here) — verified indirectly: the
      exact same HTTP calls `ObservationService` makes were already proven
      live in the Step 5 update above.)
- [x] Family view shows real trend
      (`viewer_page.dart` — same `StreamBuilder` pattern, same neutral
      fallback. `viewerId` still isn't wired to a real household/recipient
      lookup — same hardcoded IDs as the log screen.)

---

# Backend: RAG Component (anti-hallucination grounding)

Not part of the voice-log feature above — a general-purpose backend
capability so any future LLM-facing feature (starting with the chat-based
symptom checker in `CLAUDE.md`'s MVP list, but not built yet) can ground
answers in real sources instead of the model free-associating from training
data.

## What it is

`apps/api/src/rag/` — retrieval-augmented generation: chunk documents →
embed → store → on a question, retrieve the most relevant chunks → force
the LLM to answer only from those chunks, with citations, and to say "I
don't know" rather than guess when nothing relevant is found.

## Document sources (`src/rag/sources/`)

4 real, cited public sources — not fabricated placeholder text. Fetched live
via web search/fetch on 2026-07-30:
- Taiwan MOHW — Department of Long-Term Care overview
  (mohw.gov.tw/cp-3779-44499-2.html)
- "Policies and Transformation of Long-Term Care System in Taiwan" — peer-
  reviewed paper, PMC (pmc.ncbi.nlm.nih.gov/articles/PMC7533198/)
- WHO ICOPE (Integrated Care for Older People) framework overview
  (who.int)
- NCBI Bookshelf — "Medication Management of the Community-Dwelling Older
  Adult" (ncbi.nlm.nih.gov/books/NBK2670/)

To add more: drop a new file in `src/rag/sources/` in the same shape
(`{ id, title, publisher, url, retrievedAt, category, text }`), list it in
`sources/index.js`, re-run `node src/rag/ingest.js`. A CDC page (medication
safety) 403'd on fetch and isn't included — worth another attempt later.

## Storage & retrieval

- Firestore, top-level `ragChunks` collection (shared reference knowledge,
  not household data — doesn't belong under the `households/{id}/...` tree
  the care-record schema uses).
- Embeddings: **local**, via `@xenova/transformers`
  (`Xenova/all-MiniLM-L6-v2`, runs on CPU, ~90MB model downloaded on first
  use, cached after). Deliberately not a hosted embeddings API — every
  paid/quota-limited option hit earlier in this project (Anthropic, Gemini)
  was a dead end without billing. Zero cost, zero external dependency for
  this step.
- Retrieval: cosine similarity, in-memory over the whole corpus (fine at
  this scale — a handful of documents). `MIN_RELEVANCE_SCORE = 0.2`,
  calibrated empirically: real relevant queries scored 0.53-0.69 cosine
  similarity against the actual corpus; a fully unrelated query ("what is
  the capital of France?") scored negative across every chunk. Below 0.2 a
  chunk is discarded rather than surfaced — without this, off-topic
  questions still returned 4 irrelevant "sources" even when the LLM
  correctly declined to answer from them.

## The LLM "placeholder" (`src/lib/llmClient.js`)

This is the swappable piece you asked for — which model answers is a
`LLM_PROVIDER`/`LLM_MODEL` env var, not a code change at call sites.
`LLM_PROVIDER=openrouter` (default, `openai/gpt-oss-20b:free`) is the only
one actually implemented — `anthropic` and `openai` are stubbed with clear
"not implemented, needs billing" errors so filling them in later is
mechanical, not a redesign.

## Anti-hallucination behavior (`src/rag/answer.js`)

System prompt forces: answer ONLY from the numbered sources given, cite
inline like `[1]`, say so plainly if the sources don't cover it, flag
possible emergencies and recommend a doctor/119 rather than advise on them.
Verified live: a relevant question about Taiwan LTC 2.0 coverage got a
correct, cited answer pulling the right two chunks (17 service types, 26%
foreign domestic worker reliance — matching the real source numbers
exactly); an unrelated question ("capital of France?") correctly returned
"I don't have any information on that yet." with zero sources, not a
hallucinated guess.

## API

`POST /rag/ask` — `requireAuth` only (no household/assignment check; this
is shared knowledge, not care-record data, so any authed user can query
it). Body `{ question }` → `{ answer, sources: [{ n, title, publisher,
url, excerpt }] }`.

## Testing

24 unit tests (chunk, cosine similarity + threshold filtering, answer
grounding/refusal, LLM client provider switching + error paths, route auth/
validation), all passing, all mocked. Live-tested end to end against real
Firebase + real embeddings + real OpenRouter: ingest (4 sources → 10
chunks), a grounded question (correct cited answer), and an off-topic
question (correct refusal, no irrelevant citations).

## Mobile: wired to the Ask screen

Update: turns out there's already an "Ask about a symptom" screen
(`apps/mobile/lib/pages/ask_page.dart`, the `/ask` route — 2nd bottom-nav
tab) that was previously just a static text field with suggested prompts
and no backend call. Wired it to `POST /rag/ask` via a new
`lib/services/rag_service.dart`. Answer + numbered sources render below the
input; loading and error states handled. Factored the anonymous-auth-token
logic (previously only in `ObservationService`) out into
`lib/services/auth_token.dart` so both services share it instead of
duplicating.

## Known gaps / open questions

- No dedicated new UI screen — used the existing Ask screen instead of
  building one, since it already matched this feature's purpose (originally
  no UI was thought necessary, then this fit was found).
- No scheduler/webhook re-runs ingest automatically — manual
  `node src/rag/ingest.js` after editing `sources/`.
- Corpus is small (4 documents) and hand-picked by web search, not a
  systematic literature review — fine as a proof of concept, not a
  substitute for actual clinical/legal review of what a caregiving app
  tells migrant workers before this goes near real users.
- CDC medication-safety page 403'd on fetch; only 3 of the 4 planned
  source types got a document (Taiwan authority, international guideline,
  research paper) — worth revisiting for more CDC/HPA-specific coverage.
- `OpenRouter`'s free-tier model hit a transient shared-pool rate limit
  during live testing (retried successfully 24s later) — same shared-pool
  risk already flagged for the voice-log extraction step.

---

# Feature 5: Multi-Patient Profiles

Caregiver picks who she's logging for (e.g. "Mr. Chen," "Lola Rosa") before
any log or check-in. Every insight, alert, and med-reminder is scoped to
the selected profile.

## What already exists

- Firestore schema already models this fully:
  `households/{id}` (shared care boundary), `households/{id}/members/{uid}`
  (who belongs to the household), `households/{id}/careRecipients/{id}`
  (the actual patient profile — `displayName`, `birthDate`,
  `preferredLanguages`, `careProfile` map, `emergencyContacts`, etc), and
  `.../careRecipients/{id}/assignments/{caregiverUid}` (which caregiver may
  act on which recipient — already built and used by the voice-log
  feature's `isCaregiverAssigned`).
- Prototype UI already exists, unwired: `prototype_patient_page.dart`
  ("who do you care for?" add-profile form), `prototype_patient_detail_page.dart`
  (single hardcoded "lola-rosa" profile), `prototype_patient_schedule_page.dart`.
- The entire voice-log feature (Feature 2) currently hardcodes
  `demoHouseholdId = 'demo-household'` and `demoCareRecipientId = 'lola-rosa'`
  in `apps/mobile/lib/api_config.dart` — this feature replaces those
  constants with a real selected-profile mechanism.
- Real email/password sign-in now exists (`auth_page.dart`, `/auth`,
  optional/skippable) — built after Feature 2's "no sign-in screen" note.
  Anonymous auth stopgap still works for skipped users.

## Steps

1. **Backend: household bootstrap + care-recipient CRUD** (`apps/api`)
   Find-or-create a household for the signed-in (or anonymous) caregiver,
   create/list care recipient profiles within it, auto-assign the creator
   as caregiver on any profile they add.
2. **Mobile: profile state + service**
   A place to hold "which profile is currently selected" that persists
   across app restarts, and a service to call the new backend endpoints.
3. **Wire the add-profile screen** (`prototype_patient_page.dart`)
   Real create call instead of just `context.go('/home')`.
4. **Build a profile picker / list**
   Currently no screen lists multiple profiles — only a single hardcoded
   detail page exists. Needs one so "picking who she's logging for" is
   actually possible once there's more than one.
5. **Thread the selected profile everywhere**
   Replace `demoHouseholdId`/`demoCareRecipientId` in `ObservationService`
   (voice-log), the log screen's chart stream, and the viewer screen with
   the real selected profile — this is the part that actually "scopes
   every insight, alert, and med-reminder."
6. **Test live** against real Firebase, same pattern as Feature 2.

## Open questions / design calls made along the way

(fill in as build proceeds)

## Progress

- [ ] Backend household bootstrap + care-recipient CRUD
- [ ] Mobile profile state + service
- [ ] Add-profile screen wired
- [ ] Profile picker screen
- [ ] Selected profile threaded through voice-log feature
- [ ] Live test
