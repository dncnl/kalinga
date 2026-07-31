# Integration: frontend-ui → main + MVP completion

Branch: `integration/frontend-ui`, cut from `origin/main` @ `fb2bdc2`.
**Fallback point:** `main` @ `fb2bdc2` is known-good and stays untouched, as
does `origin/frontend-ui` (`62f6b64`). Nothing merges back to `main` until
the full demo path (§Definition of done below) passes end to end.

## Phase 0 findings that shape the plan

1. **The task prompt's §6 was inverted from reality.** The auth/family/viewer
   work it attributes to `main` (role picker, `/family-code`,
   `family_viewer_service`, ViewerPage resolving from its own `:id`) actually
   lives on `frontend-ui`. `main`'s ViewerPage still reads the caregiver-only
   `SelectedProfile` singleton. **Decision (confirmed with Ralph):
   frontend-ui wins on auth/viewer/invite logic**, with one manual port —
   `main`'s router auth-gate redirect + SelectedProfile-restore logic goes
   into frontend-ui's router (frontend-ui's router has no auth guard at all).
2. `frontend-ui` touches **zero** backend files (`apps/api`,
   `packages/kalinga_firestore_package`) — nothing to discard, and its
   services already call `main`'s current endpoints.
3. Only 10 files are modified on both sides; frontend-ui's edits to
   `main`-reworked pages (`meds_page`, `prototype_home_page`,
   `prototype_log_page`, `settings_page`, `profile_picker_page`) are
   cosmetic: bg `#F5F0E8` → white, `AppBackButton`, one border. Resolution:
   take `main`'s versions, re-apply the cosmetic tweaks.
4. Verify in Phase 2: invite-code format vs `main`'s post-fork commits
   `b10bcd9` (join codes + authz) and `b40815c` (human-readable ids).

## Backend changes made (required log — all additive, none breaking)

1. `POST /households/:hid/care-recipients/:crid/observations/symptom-check`
   — **new route** (F1). Could not be solved on the frontend: the existing
   observation path starts from an audio upload and a tap-based triage has
   no audio, so there was no way to record a check-in at all. Everything
   downstream is reused unchanged (same collection, same document builder,
   same daily/weekly rollups). No existing route touched.
2. `apps/api/src/lib/symptomTriage.js` — **new lib**, the deterministic
   urgency rule table + its 9 tests.
3. `buildObservationDocument({ …, inputMode })` — **new optional
   parameter**, defaulting to `'voice'` so every existing caller behaves
   identically. `'structuredForm'` is a value the schema's
   `inputMode: "voice|text|structuredForm"` already declares, so this is
   not a schema change.
4. `apps/api/src/routes/tasks.js` — **new routes** (F2/F3):
   `POST|GET .../tasks`, `DELETE .../tasks/:taskId`,
   `POST .../task-events/generate-today`,
   `POST .../task-events/:eventId/complete`. Could not be solved on the
   frontend: `tasks`/`taskEvents` are `serverOnly` for client writes per
   the schema, and no route exposed them. All four mirror the equivalent
   medication routes rather than inventing a new shape.
5. `apps/api/src/lib/reminderCheckin.js` — **new lib**, the F3 question
   sets and their score mapping, plus 9 tests.

6. `PATCH /households/:hid/care-recipients/:crid` — **new optional
   `mustRemember` field** (F5), written into the same free-form
   `careProfile` map that already holds `age` and `conditions`. Existing
   callers that don't send it are unaffected; validated and capped
   server-side.

No existing route's shape or authorization was changed at any point.

Nothing else under `apps/api` or `packages/kalinga_firestore_package` was
modified beyond the RAG system-prompt commit listed above.

## Decisions (confirmed)

- Uncommitted RAG system-prompt improvement (`answer.js`: answer in the
  caregiver's language, plain-word style, safety framing) → committed here.
- F6 fourth hotline: **NIA 0800-024-111** (24/7, multilingual incl.
  Vietnamese/Indonesian/Thai) alongside 1955 / 119 / 110.
- Hokkien gap: **minimal caregiver→elder Hokkien phrases inside the F6
  phrasebook** (eat, medicine, toilet, pain, rest — romanized), not folded
  into F1, not dropped.

## Plan

- [x] Phase 0 — inventory, no code changes (report delivered in session)
- [x] Phase 1 — merged `origin/frontend-ui` (commit `fad1c59`)
  - [x] both-modified files: main wins, cosmetic tweaks re-applied
  - [x] `router.dart` manual port: frontend-ui routes + main's redirect guard
  - [x] no duplicate screens (frontend-ui only added new pages)
  - [x] builds and runs on Android emulator (API 37)
- [x] Phase 1b — auth gate (§5b) **all lines pass on device**, verified by
      driving the emulator and screenshotting each state:
  - [x] caregiver sign-up → `/language` → `/patient` → `/home`, scoped to
        the created recipient; household bootstraps once
  - [x] caregiver restart → straight to `/home`, session persists
  - [x] invite code minted (`GT5Z7DM5`), family code validated, family
        registered → viewer showing **that** recipient
  - [x] family restart → "Opening your family view…" → correct viewer
  - [x] family login (role fork) → correct viewer
  - [x] sign-out (caregiver, Settings) clears state → welcome
  - [x] failure states: invalid code, wrong password, no network — all
        inline and plain-language
  - Bugs found and fixed during this gate: see commits `3ca3470`, and the
    fix-list commit below.
- [ ] Phase 2 — wiring table (verified against `main`'s live routes)

| Screen | Source | State |
|---|---|---|
| `welcome` / `role_select` | none (navigation only) | n/a ✓ |
| `auth_page` | Firebase Auth + `POST /households/bootstrap` | verified ✓ |
| `family_code_page` | `GET /invites/:code` | verified ✓ (contract fixed) |
| `family_register_page` | Firebase Auth + `POST /invites/:code/accept` | verified ✓ (contract fixed) |
| `family_recipients_page` | `FamilyViewerService` (mine + care-recipients + member doc) | verified ✓ |
| `viewer_page` | `GET /care-recipients/:id/household` + `weeklySummaries` | verified ✓ (fixture alert removed) |
| `prototype_language_page` | local state only | n/a ✓ |
| `prototype_patient_page` | `POST/PATCH /households/:id/care-recipients` | verified ✓ |
| `profile_picker_page` | `SelectedProfile` / `GET …/care-recipients` | verified ✓ |
| `prototype_home_page` | meds today + observations | verified ✓ |
| `prototype_log_page` | `ObservationService` + `dailySummaries` | wired (pre-existing) |
| `meds_page` | `MedicationService` | wired (pre-existing) |
| `ask_page` | `POST /rag/ask` | wired (pre-existing) |
| `invite_sheet` | `POST /households/:id/invitations` | verified ✓ (contract fixed) |
| `help_page` | static, by design — vetted hotlines + phrasebook | **F6 done ✓** |
| `symptom_check_page` | `POST …/observations/symptom-check` + `/rag/ask` | **F1 done ✓** |
| `reminders_page` | `tasks` CRUD | **F2 done ✓** (replaced the mock) |
| `reminder_checkin_page` | `task-events/:id/complete` → observation | **F3 done ✓** (replaced the mock) |
| `activity_page` | hardcoded `_items` fixture | **still mock** |

- [ ] Phase 3 — features
  - [ ] F0 scoping audit (careRecipientId threaded through every screen)
  - [x] F1 structured symptom check-in. Tap-based tree over six red flags
        (breathing, chest pain, fall, sudden confusion, fever, not
        eating/drinking) — scope confirmed with Ralph. **Urgency is
        deterministic**, from a fixed rule table in
        `apps/api/src/lib/symptomTriage.js`, never from an LLM: a
        hallucinated "sounds fine" here means somebody doesn't call 119.
        The schema anticipated this (`safetyRuleSets` = "deterministic
        routing… no autonomous diagnosis"). 9 unit tests assert every red
        flag escalates and that non-boolean answers can't trip one.
        RAG is used only for "while you wait" guidance, shown with sources
        and unable to change the urgency. Voice follow-up reuses the F4
        pipeline unchanged (records → `submitVoiceLog`), no second speech
        path. Result: urgency + action + the Mandarin text the family will
        see, stored as an observation so it feeds the same rollups.
  - [x] F2 labeled reminders. Reuses the schema's existing `tasks` +
        `taskEvents` pair — the same definition/materialized-occurrence
        split the medication reminders already use, including the same
        "generate today + list in one round trip" call. Labels map onto the
        existing `TaskCategory` enum (Eating → `meal`, Exercise →
        `exercise`, Medication, Drinking water → `hydration`, custom →
        `other` with the typed label in `title`). No new data modelling.
        Replaced the hardcoded schedule page.
  - [x] F3 reminder-triggered structured check-ins. Eating and Exercise
        reminders open a short question set; the answers become an
        observation through the **same** builder and rollups as the voice
        log, so `appetiteLevel`/mobility land in the existing trend charts.
        The schema's `taskEvent.relatedObservationId` links the two. Any
        other label just completes with an optional note — inventing
        questions for an unknown label would produce meaningless trends.
        Scores only move for the dimension actually asked about (answering
        about lunch never fabricates a sleep score); 9 tests cover this.
        Voice alternative reuses the F4 pipeline. Replaced the hardcoded
        check-in page.
  - [x] F5 "must remember" + insights.
        **Manual half:** allergy / directive / sensory / trigger /
        preference items on the elder's profile, stored in the existing
        free-form `careProfile` map (same place age and conditions already
        live — no schema change). Human-entered only: nothing here is
        model-generated, since a confidently-wrong DNR or allergy is the
        most dangerous thing this app could produce. Allergies and
        directives render with a warning colour; the rest stay calm.
        **Auto half:** `deriveInsights()` reads the `trendSeries` the weekly
        rollup already writes — no new analytics system. Three honesty
        rules, each with a test: days with no observations (the rollup's
        neutral 0.5) are skipped rather than read as average; fewer than 4
        real days or a change under 0.15 produces nothing at all; and the
        wording describes without diagnosing ("eating less than earlier
        this week", never "possible dehydration"). Empty state says "not
        enough logs yet", never "everything is fine". 8 Flutter tests.
  - [x] F6 emergency contacts + phrasebook. 119 / 110 / 1955 /
        0800-024-111 (NIA foreign-resident line), real `tel:` dialling via
        `url_launcher`. Removed the fabricated "Rosa's daughter" and
        "city health hotline" rows — no household phone numbers are
        collected anywhere, so a fake number in a crisis is worse than no
        row at all. Mandarin phrasebook + **Hokkien caregiver→elder
        phrases** (the resolved known gap). Personal-phone caveat in the UI.
  - [ ] F7 med OCR: move vision fallback chain to Vertex AI paid-model
        pattern (match text-extraction path)
- [ ] Phase 4 — demo path end-to-end on Android; final report; ask before
      merging to `main`

## Definition of done

Demo path: caregiver signup → household bootstrap → 2 recipients → scoped
screens → voice log reflected in trends → symptom check-in with Mandarin
summary → Eating reminder fires → structured check-in lands in trends →
med-label scan schedules reminder → profile shows must-remember + insight →
emergency tap-to-call → invite code → family member registers → viewer shows
that recipient's data.
