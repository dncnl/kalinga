# Feature 1: Chat-Based Symptom Checker (RAG, multilingual, urgency-flagged)

Caregiver describes a symptom in her own language (Tagalog/Bisaya/Bahasa
Indonesia/Vietnamese). Kalinga answers grounded in real medical/health-authority
sources (RAG — no un-sourced medical claims), classifies urgency, and sends
the family/doctor a Mandarin summary — flagging them immediately if it looks
urgent. Directly targets the 77.9% language-barrier bottleneck (Wu et al.,
2022): the caregiver who noticed something wrong finally has a way to say so
clearly, in her own language, without waiting for someone who speaks Mandarin.

## What already exists

- **RAG is already built** (`apps/api/src/rag/`: `embeddings.js`, `retrieve.js`,
  `chunk.js`, `ingest.js`, `answer.js`, `sources/*`) and live behind
  `POST /rag/ask` (`apps/api/src/routes/rag.js`). Answers are grounded in a
  real corpus (WHO iCOPE, Taiwan MOHW/LTC policy docs, NCBI medication-safety
  and abdominal-emergency papers for older adults) via cosine-similarity
  retrieval over Firestore-stored chunk embeddings, cited inline like `[1]`.
  This is the RAG the user asked to make sure is implemented — it already is;
  this feature wires it into a real symptom-checker flow instead of a bare
  Q&A demo.
- **`apps/mobile/lib/pages/ask_page.dart`** is already the matching prototype
  UI — "Ask about a symptom," with copy that already says *"Kalinga answers,
  and sends the family a Mandarin summary"* — but it's wired to the bare
  `/rag/ask` endpoint: no locale, no urgency classification, no translation,
  no persistence, no family/doctor flagging. Same situation every other
  feature started in.
- **Translation** (`apps/api/src/lib/translate.js`, `translateToMandarin`)
  and **locale codes** (`fil`/`id`/`vi`/`ceb`) already exist and are proven
  in the voice-log pipeline (Feature 2) — reused as-is here.
- **`households/{id}/careRecipients/{id}/alerts/{id}`** already exists in the
  Firestore schema, with an `AlertType` enum that includes `emergency`, a
  `severity: Urgency` field (`none|information|attention|urgent|emergency`),
  and `recipientUids` — exactly the mechanism for "flagging urgency to family
  and doctor." `firestore.rules` already gates it to household
  admins/assigned caregivers with server-only writes. Nothing reads or
  writes it yet.
- **Language selection UI** (`/language`) exists but doesn't persist
  anything — `_selected` is local widget state, never saved. The whole app
  currently uses a hardcoded `demoLocale = 'fil'` placeholder
  (`api_config.dart`) for every locale-aware call. This feature needs a real
  selection to know which language to answer in and translate from, so it's
  in scope here (small — persist like `SelectedProfile` does).

## Decisions made before starting

- **Grounding is mandatory, not optional.** Reuse `answer.js`'s existing
  RAG-only system prompt discipline (cite `[1]`, refuse rather than guess if
  sources don't cover it) — extend it, don't bypass it. Matches the schema's
  own stated constraint: *"AI does not diagnose, prescribe, or infer dosage
  from pill appearance."* This is symptom triage, not diagnosis: the answer
  should say what the sources say and when to seek care, not name a
  condition.
- **Answer directly in the caregiver's language**, not English then
  translate down — the LLM is multilingual and the RAG sources are English
  reference docs either way, so asking it to answer in `fil`/`ceb`/`id`/`vi`
  directly (grounded in the retrieved English chunks) avoids an extra
  lossy translation hop for the caregiver-facing text. The **family/doctor
  summary** is the one thing that gets `translateToMandarin`'d, same as
  Feature 2's voice-log pipeline.
- **New Firestore collection**: `households/{id}/careRecipients/{id}/symptomChecks/{id}`
  — nothing existing models "one symptom-check turn." Added to the schema
  package properly (JSON schema + `firestore.rules` + regenerated TS
  contracts via `npm run generate:contracts`), not bolted on ad hoc.
  `clientReadPolicy: authorizedCareTeam` (same rule shape as
  `dailySummaries`), `clientWritePolicy: serverOnly`.
- **Urgent/emergency turns write a real `alerts` doc** (existing collection,
  no schema change needed) so the family is flagged — this endpoint is the
  first thing in the codebase to ever write to `alerts`.

## Steps

1. **Schema**: add `symptomChecks` collection to
   `packages/kalinga_firestore_package` (fields: `locale`, `messageText`,
   `messageTextEn` (translated for retrieval if needed), `answerText`,
   `sources` (array of the RAG citation info), `urgency: Urgency`,
   `familySummaryZh`, `alertId: string|null`, audit mixin). Update
   `firestore.rules`, regenerate contracts, run `npm run validate`.
2. **Backend: urgency classification** — small structured-extraction module
   (same tool-call/JSON pattern as `extractObservation.js`) that reads the
   caregiver's message + grounded answer and returns an `Urgency` value.
   Conservative by design: ambiguous or symptom-adjacent-to-emergency
   language (chest pain, can't breathe, fell, unresponsive) should bias
   toward `urgent`/`emergency`, not `none` — a missed alert is worse than a
   false one here.
3. **Backend: symptom-check endpoint** —
   `POST /households/:householdId/care-recipients/:careRecipientId/symptom-check`
   `{ message, locale }`: runs RAG (`answerQuestion`, extended to accept a
   target-language instruction), classifies urgency, translates a short
   family-facing summary to Mandarin, saves a `symptomChecks` doc, and — if
   `urgency` is `urgent` or `emergency` — writes an `alerts` doc
   (`type: 'emergency'`, `recipientUids` from the household's privileged
   members) so family/doctor get flagged. `requireAuth` + `isCaregiverAssigned`
   (same auth shape as `medications.js`/`observations.js`).
4. **Backend: history endpoint** — `GET .../symptom-check` (list past turns
   for a care recipient, most recent first) so family/doctor can review what
   was asked and answered, not just the live alert.
5. **Mobile: LocaleState** (mirrors `SelectedProfile`'s persisted-singleton
   pattern) — `/language` page writes a real selection via SharedPreferences;
   replaces the `demoLocale` placeholder everywhere it's used.
6. **Mobile: wire `ask_page.dart`** — send `{message, locale}` to the new
   household/care-recipient-scoped endpoint instead of bare `/rag/ask`, show
   the urgency level, and show a clear "sent to family in Mandarin" (or "not
   urgent, not sent") confirmation so the caregiver knows what happened.
7. **Test live** against real Firebase + a real LLM call, same rigor as
   every prior feature: verify grounded answers actually cite sources, verify
   an intentionally urgent test message (e.g. "chest pain, can't breathe")
   produces `urgency: emergency` and a real `alerts` doc, and verify a
   clearly non-urgent one does not.

## Out of scope for this pass

- A real-time family-facing alert inbox UI (`activity_page.dart` is still
  hardcoded prototype UI, same gap Feature 4 left for meds) — alerts get
  written to Firestore correctly; a live-updating UI to view them is a
  separate feature-sized piece of work.
- Push notifications (FCM) for the alert — `firebase_messaging` is already a
  mobile dependency but nothing subscribes/sends yet; out of scope here.

## Progress

- [ ] Schema: `symptomChecks` collection + regenerated contracts
- [ ] Backend urgency classification
- [ ] Backend symptom-check endpoint (RAG + translate + urgency + alert)
- [ ] Backend history endpoint
- [ ] Mobile LocaleState (real language persistence)
- [ ] Mobile ask_page.dart wired
- [ ] Live test
