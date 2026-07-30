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
- [ ] Phase 2 — wire remaining screens to real endpoints, keep wiring table
      (known mock/static: `prototype_checkin_page` schedules, `help_page`
      contacts, `activity_page`, `prototype_patient_schedule_page`)
- [ ] Phase 3 — features
  - [ ] F0 scoping audit (careRecipientId threaded through every screen)
  - [ ] F1 structured symptom check-in (tap decision-tree + voice follow-up
        via existing pipeline, urgency flag + Mandarin summary)
  - [ ] F2 labeled reminders (reuse tasks/taskEvents pattern)
  - [ ] F3 reminder-triggered structured check-ins (feed existing rollups)
  - [ ] F5 "must remember" + insights from existing rollups
  - [ ] F6 emergency contacts (1955/119/110/0800-024-111) + phrasebook
        incl. Hokkien caregiver→elder phrases
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
