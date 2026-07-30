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

Two parts, in `AuthPage._submit()`:

1. **Register:** if the current user is anonymous (the common case — the
   language screen is the first thing anyone sees, before any sign-in, so
   most caregivers reaching this screen are already anonymous, often with
   real logs already saved under that UID), call `linkWithCredential` with
   an `EmailAuthProvider` credential instead of `createUserWithEmailAndPassword`.
   This upgrades the anonymous account in place — same UID before and
   after — so whatever household/data it already bootstrapped stays
   reachable instead of being orphaned. Falls back to
   `createUserWithEmailAndPassword` if there's no anonymous session to
   link (shouldn't normally happen, but defensive).
2. **Re-sync regardless:** re-run `SelectedProfile.instance.initialize()`
   right after the Firebase Auth call succeeds — covers login (always a
   different UID) and the no-anonymous-session register fallback. A no-op
   refresh in the common linking case, since the UID didn't change.

Also added a clearer error message for `credential-already-in-use` /
`email-already-in-use` (linking fails if the email is already registered
to a different real account) — points the user at signing in instead.

## Scope decisions (hackathon)

- **Orphaned anonymous households are still left alone** — not migrated,
  not deleted, no cleanup routine. This only matters now for the rarer
  register-without-linking fallback path; the common path no longer
  orphans anything.
- **No merge of two anonymous sessions' data.** If a caregiver somehow
  registers from a *second* anonymous session after already having a
  registered account elsewhere, `credential-already-in-use` surfaces as an
  error rather than attempting any merge — out of scope for the hackathon.

## Progress

- [x] Re-trigger `SelectedProfile.instance.initialize()` after successful
      register/login in `auth_page.dart`.
- [x] `linkWithCredential` on register when an anonymous session exists,
      falling back to `createUserWithEmailAndPassword` otherwise. Clearer
      error message for `credential-already-in-use`/`email-already-in-use`.
      `flutter analyze` clean on the changed file.
      **Not yet tested live** — no GUI/mic-input automation available here;
      same limitation noted throughout prior features' PLAN.md entries.
