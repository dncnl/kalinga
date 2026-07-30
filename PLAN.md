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

- [ ] Backend household bootstrap + care-recipient CRUD
- [ ] Mobile profile state + service
- [ ] Add-profile screen wired
- [ ] Profile picker screen
- [ ] Selected profile threaded through voice-log feature
- [ ] Live test
