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

- Household lookup ("which household is this caregiver in") uses a
  lightweight top-level `householdMemberships/{uid}` doc rather than a
  Firestore collection-group query across `members` subcollections — avoids
  needing a composite/collection-group index provisioned before this can
  be tested live. Not part of the original schema package; a pragmatic
  addition, same spirit as RAG's `ragChunks` collection.

## Progress

- [x] Backend household bootstrap + care-recipient CRUD
      (`POST /households/bootstrap` — find-or-create, idempotent, verified
      live: second call returns the same householdId. `POST
      /households/:householdId/care-recipients` — creates the profile AND
      an active assignment for the creator in one batch, so a caregiver can
      immediately log for a profile they just made (confirmed live: called
      the voice-log upload-url endpoint against a freshly created profile,
      got a valid signed URL, no manual assignment seeding needed). `GET
      /households/:householdId/care-recipients` — lists active profiles.
      16 unit tests, all mocked, all passing, plus the full live chain
      above.)
- [x] Mobile profile state + service
      (`lib/services/profile_service.dart` — `bootstrapHousehold()`,
      `listCareRecipients()`, `createCareRecipient()`, plus a `CareRecipient`
      model with an `initials` getter for avatar circles.
      `lib/state/selected_profile.dart` — `SelectedProfile`, a
      `ChangeNotifier` singleton holding `householdId`/`careRecipient`/
      `careRecipients`, persisted across restarts via `shared_preferences`
      (added as a new dependency). `initialize()` bootstraps the household,
      lists its recipients, and restores the last-selected one (or picks
      the first available). Called fire-and-forget from `main.dart` right
      after Firebase init — screens react via `ListenableBuilder` once it
      resolves rather than blocking app startup on a network round trip.)
- [x] Add-profile screen wired
      (`prototype_patient_page.dart`'s "Save and start" button now calls
      `SelectedProfile.instance.createAndSelect(...)` with the form's real
      values instead of just navigating to `/home`. Loading + error states
      added.)
- [x] Profile picker screen
      (New `profile_picker_page.dart` at `/profiles` — didn't exist before.
      Lists every profile in the household via `SelectedProfile`, tap to
      select, "Add another profile" button to `/patient`. Wired the avatar/
      name tap targets in `prototype_home_page.dart` and
      `prototype_log_page.dart`'s headers to push here instead of the old
      hardcoded `/patients/lola-rosa`.
      **Not done:** 6 other screens (`activity_page.dart`, `help_page.dart`,
      `meds_page.dart`, `prototype_checkin_page.dart`,
      `prototype_patient_schedule_page.dart`, `settings_page.dart`) still
      have the old hardcoded header pointing at `/patients/lola-rosa` —
      left alone since those screens aren't functionally built yet either
      (no real data behind them), so wiring their headers now would be
      cosmetic-only. Worth doing when those screens themselves get built.)
- [x] Selected profile threaded through voice-log feature
      (`ObservationService.submitVoiceLog()` now takes `householdId`/
      `careRecipientId` as required named params instead of reading
      hardcoded constants — `api_config.dart`'s `demoHouseholdId`/
      `demoCareRecipientId` are deleted entirely (compile errors forced
      every call site to be found and fixed, rather than silently leaving
      one hardcoded). `prototype_log_page.dart`'s mic button now guards
      against "no profile selected" with a snackbar instead of crashing.
      Both the log screen's and `viewer_page.dart`'s `weeklySummaries`
      chart streams now read from `SelectedProfile.instance` and return
      `null` (safe — `StreamBuilder` accepts a nullable stream) when no
      profile is selected yet. `viewer_page.dart`'s hardcoded Chinese
      title "羅莎奶奶" is now the real `displayName` interpolated in — not
      actually translated, just no longer wrong for a different patient.
      `demoLocale` (which language the caregiver is speaking) is
      unaffected — language selection still isn't wired to real state,
      out of scope for this feature.)
- [x] Live test
      (Full backend chain proven live in Step 1 above: bootstrap → create
      profile → voice-log upload-url accepted immediately, no manual
      Firestore seeding. Separately, the actual compiled Windows app was
      launched for real (not a script) with the API server running, and
      `SelectedProfile.initialize()` completed with `error: null` —
      confirmed by checking Firestore directly afterward and finding a
      real `householdMemberships` doc the app itself created. Both test
      artifacts cleaned up from Firestore afterward.
      **Not done:** clicking all the way through create-profile →
      profile-picker → record-a-log in the actual running UI — same
      limitation as every prior feature (no GUI/mic-input automation
      available here). The pieces are proven live individually
      (bootstrap+list via the real app, create+voice-log chain via the
      same endpoints in Step 1), not as one unbroken UI click-through.)
