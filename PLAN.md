# Fix: Re-sync selected profile after sign-in/register

Caregivers use the app anonymously by default (no account required). If a
caregiver later registers or logs in via `AuthPage`, they land on a
**different Firebase UID** than whatever was active at cold start — but
nothing re-runs household bootstrap for the new UID, so `SelectedProfile`
keeps pointing at the old (often anonymous) UID's household. Every
household-scoped call (voice-log, profiles, invites) then 403s until the
app is restarted.

## What already exists

- `POST /households/bootstrap` (`apps/api/src/routes/households.js`) —
  idempotent: finds the caller's household via `householdMemberships/{uid}`,
  or creates household + member doc + `householdMemberships` doc in one
  batch if this UID has never been seen before. Already correct; just never
  re-triggered after an auth state change.
- `SelectedProfile.instance.initialize()`
  (`apps/mobile/lib/state/selected_profile.dart`) — calls bootstrap, lists
  care recipients, restores the last-selected one from `SharedPreferences`.
  Only ever called once, from `main.dart`, at app launch.
- `AuthPage._submit()` (`apps/mobile/lib/pages/auth_page.dart`) — handles
  both register and login via the Firebase Auth client SDK, but never
  touched the backend or `SelectedProfile` afterward.

## Fix

Re-run `SelectedProfile.instance.initialize()` right after `_submit()`'s
Firebase Auth call succeeds — covers both register and login, since both
can leave a different UID active than whatever was active a moment before.

## Scope decisions (hackathon)

- **Orphaned anonymous households are left alone** — not migrated, not
  deleted. No real users exist yet, so a household created under an
  abandoned anonymous UID is inert clutter, not a liability. A cleanup
  routine adds real risk (could delete the wrong household) for no benefit
  at this stage; if cleanup is ever wanted, it's a manual one-off, not part
  of the auth code path.
- **Data continuity is explicitly out of scope.** This fix stops future
  403s; it does not preserve whatever a caregiver logged anonymously before
  registering (that would need `linkWithCredential` to upgrade the
  anonymous account in place instead of creating a new one — a separate,
  bigger change not needed for the hackathon).

## Progress

- [x] Re-trigger `SelectedProfile.instance.initialize()` after successful
      register/login in `auth_page.dart`. `flutter analyze` clean on the
      changed file. Covers both `_AuthMode.register` and `_AuthMode.login`
      (single call sits after the if/else, before navigating to `/home`).
      **Not yet tested live** — no GUI/mic-input automation available here;
      same limitation noted throughout prior features' PLAN.md entries.
