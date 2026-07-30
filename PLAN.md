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

---

# Phase 2: Closing the gaps

After live-testing Phase 1, five real gaps were identified and the user
asked to close all of them:

1. Can't edit or delete a profile once created
2. Can't remove/switch households — one auto-created household per
   caregiver, no invite/linking flow
3. No multi-caregiver support — schema allows multiple caregivers per
   recipient, nothing lets a second one join
4. Family/doctor linking isn't wired to real profiles — "preview what
   family sees" just reuses the caregiver's own selected profile
5. 6 screens (`meds`, `help`, `activity`, `schedule`, `settings`,
   `checkin`) still show the hardcoded "Lola Rosa" header

## Key discovery grounding this phase

`packages/kalinga_firestore_package/firestore.rules` already has the full
access model built: `isPrivilegedHouseholdMember` (role in
`family`/`careCoordinator`/`clinician`/`householdAdmin`/`agencyStaff`) OR
`isAssignedCaregiver` (caregiver role + an active assignment doc) both
satisfy `canAccessCareRecipient`, which gates reads on `weeklySummaries`,
`dailySummaries`, `observations`, etc. **A family member just needs an
active `households/{id}/members/{uid}` doc with `role: 'family'`** — no
extra assignment doc, no extra plumbing. Multi-caregiver is the same
mechanism plus a per-recipient assignment doc. This means gaps 2-4 all
collapse into **one real feature: a working household invite system.**

`apps/mobile/lib/services/invite_service.dart` already exists as a
deliberately-scoped stub — its doc comment names the exact contract to
build against: `GET /invites/:token` (public, unauthenticated — the
invitee has no account yet) and `POST /invites/:token/accept`
(authenticated). `family_register_page.dart` (`/invite/:token`) already
consumes it. This phase mostly fills in that seam rather than inventing a
new one.

## Steps

1. **Backend: edit/delete care recipient** — `PATCH` and `DELETE` (soft —
   `status: 'archived'`, per the schema's own soft-delete mixin) on
   `/households/:householdId/care-recipients/:id`.
2. **Backend: `careRecipientLocations/{id}` lookup** — same pragmatic
   pattern as `householdMemberships/{uid}`. Needed so an invite or a
   family viewer can resolve "which household is this recipient in" from
   just a recipient id, without a collection-group query.
3. **Backend: invitation system**
   - `POST /households/:householdId/invitations` — caregiver creates an
     invite (`intendedRole`: `family` or `caregiver`, invited email,
     optional `careRecipientId`). Returns a token.
   - `GET /invites/:token` — public, no auth. Resolves the invite,
     inviter's display name, and (if scoped) the recipient's name.
   - `POST /invites/:token/accept` — authenticated (invitee just created
     their Firebase account client-side). Adds them as a household member
     with `intendedRole`; if `caregiver` + a `careRecipientId`, also
     creates the per-recipient assignment doc so
     `isAssignedCaregiver`/`isCaregiverAssigned` actually pass.
4. **Backend: multi-household membership + switch** — `householdMemberships/{uid}`
   changes shape from a single `householdId` to `{ householdIds: [...],
   activeHouseholdId }`, since accepting an invite to someone else's
   household means the invitee now belongs to two. New
   `POST /households/switch` sets which one is active (must already be a
   member).
5. **Mobile: wire the real `InviteService`** — replace the two `TODO(api)`
   stub methods with real HTTP calls to the endpoints above. No other file
   should need to change — that was the point of the existing seam.
6. **Mobile: "invite family/caregiver" UI** — an entry point (likely off
   the patient detail page's existing "Linked viewers" row) to create an
   invite and surface the resulting link. No email-sending infrastructure
   exists, so this shows/copies the link for manual sharing rather than
   actually emailing it.
7. **Mobile: household switcher UI** — minimal: something in the profile
   picker to see which household is active and switch if the caregiver
   belongs to more than one (e.g. accepted someone else's invite).
8. **Mobile: edit/delete profile UI** — reuse `prototype_patient_page.dart`
   in an edit mode (prefilled, calls `PATCH` instead of `POST`), plus a
   delete action (likely on the patient detail page).
9. **Mobile: wire the remaining 6 screens' headers** to `SelectedProfile`,
   same pattern already used on home/log — mechanical, no new concepts.
10. **Test live** — especially the invite accept chain, since it's the
    highest-risk new mechanism (two different Firebase Auth identities,
    two different households, real `firestore.rules` enforcement instead
    of just our own Express middleware).

## Progress

- [x] Backend edit/delete care recipient
      (`PATCH .../care-recipients/:id` — updates only provided fields,
      merges into existing `careProfile` rather than replacing it wholesale.
      `DELETE .../care-recipients/:id` — soft delete only (`status:
      'archived'`, per the schema's own soft-delete mixin), never a hard
      delete. Confirmed live: PATCHed name showed up correctly downstream
      in an invite lookup; DELETEd recipient correctly dropped out of the
      active-recipients list.)
- [x] Backend careRecipientLocations lookup
      (Written alongside every care-recipient creation. Confirmed live as
      part of the household-resolution endpoint below.)
- [x] Backend invitation system (create / fetch / accept)
      (`POST /households/:householdId/invitations`,
      `GET /invites/:token` (public, no auth — the invitee has no account
      yet), `POST /invites/:token/accept`. `GET /care-recipients/:id/household`
      resolves which household a recipient belongs to for a caller who
      only has the recipient id (the invite-link scenario) — checks
      membership itself before answering, confirmed live that a random
      unrelated user gets a real 403, not just relies on obscurity.
      Family-role accept creates only a household membership; caregiver-role
      accept (with a `careRecipientId`) also creates the per-recipient
      assignment doc. Both confirmed live: the family member's household
      membership doc landed with `role: 'family'`/`status: 'active'` (which
      `firestore.rules`' `isPrivilegedHouseholdMember` already accepts for
      read access — no further work needed there, see the "key discovery"
      note above), and a second caregiver could immediately call the
      voice-log upload-url endpoint on the shared recipient.
      33 new unit tests across `households.test.js`/`invites.test.js`,
      all mocked, plus an 11-step live smoke test covering the full chain:
      bootstrap → create → patch → invite → fetch invite → accept (as a
      *second, separate* Firebase identity) → verify membership → resolve
      household → confirm a stranger is rejected → second-caregiver invite
      → confirm voice-log access → household switch → delete. All 11
      passed against real Firebase.
      Minor cosmetic note, not a bug: `inviterName` fell back to "A
      caregiver" in the live test because the test caregiver used
      anonymous auth (no Firebase Auth display name set) — a real
      registered caregiver would show their actual name.)
- [x] Backend multi-household membership + switch
      (`householdMemberships/{uid}` reshaped from a single `householdId`
      to `{ householdIds: [...], activeHouseholdId }`. `bootstrap` reads/
      writes the new shape. `POST /households/switch` and
      `GET /households/mine` (lists every household the caller belongs to,
      with names, for a switcher UI) both added and live-tested.
      **Migration gap found and fixed by cleanup, not by code:** a
      `householdMemberships` doc created during earlier Feature 5 testing
      (before this reshape) still had the old `{ householdId }` shape.
      Bootstrap's `if (membershipSnap.exists)` branch returns early without
      migrating it, so it would have handed back `undefined` as the
      household id to a real client. No migration path exists for
      pre-existing old-shape docs — harmless right now since there are no
      real users and this was pure test data (deleted), but would be a
      real bug the moment this ships with actual accounts already
      bootstrapped under the old shape.)
- [x] Mobile InviteService wired to real endpoints
      (`fetchInvite()`/`acceptInvite()` now call the real endpoints,
      signatures unchanged — exactly the point of the seam
      `invite_service.dart` was originally written as. Added
      `createInvite()` for the caregiver side.)
- [x] Mobile invite-family/caregiver UI
      (New `pages/invite_sheet.dart` — bottom sheet off the patient detail
      page's new "Invite family or caregiver" row. Role toggle (family/
      caregiver), email field, creates the invite and shows the token as a
      copyable link. No email-sending infrastructure exists, so it's
      manual-share only — `kalinga://invite/{token}` is a placeholder
      scheme, not a registered/working deep link outside the app yet.)
- [x] Mobile household switcher UI
      (Added to `profile_picker_page.dart` — fetches
      `ProfileService.listMyHouseholds()` on load, only renders the
      switcher row if the caregiver actually belongs to more than one
      (most never will). Tapping a household calls
      `SelectedProfile.switchHousehold()`, which re-fetches that
      household's recipients and re-selects.)
- [x] Mobile edit/delete profile UI
      (`prototype_patient_page.dart` now takes an optional `editing:
      CareRecipient?` — prefills the form and calls
      `SelectedProfile.updateSelected()` instead of `createAndSelect()`
      when set. New route `/patient/edit` passes the recipient via
      `GoRouter`'s `extra`. `prototype_patient_detail_page.dart` was
      rewritten to show the *real* selected profile instead of a
      hardcoded one — this was necessary groundwork for edit/delete to
      have somewhere real to live, and also fixed a page that was
      previously 100% fake data. Delete asks for confirmation
      (`AlertDialog`) before calling `SelectedProfile.deleteSelected()`.)
- [x] Mobile remaining 6 screens' headers wired (see commit `60aebb6`,
      done earlier in this phase alongside the InviteService wiring)
- [x] Live test
      (Full backend invite/edit/delete/switch chain already live-tested
      in the "Backend invitation system" entry above — 11/11 passed. On
      the mobile side: `flutter analyze` clean across all changed files,
      Windows build succeeds, and the actual compiled app was launched
      live against the real API with no crash on startup (which now
      exercises `ProfilePickerPage`'s new household-fetch-on-init code
      path too, not just `SelectedProfile.initialize()`). Same limitation
      as every prior feature: no GUI/mic-input automation available here,
      so create → edit → delete → invite → accept was never clicked
      through as one unbroken UI session — each piece is proven live
      individually (backend chain via script with real separate Firebase
      identities; mobile wiring via analyze + build + no-crash launch).)
