# Fix: reminder/schedule cross-patient bug + login race

Branch: `fix/reminder-cross-patient-bug`, cut from `main` (post F1-chat merge).

## Bug reports (from Ralph)

1. Today's Reminders disappear after logging in and logging out.
2. Logging a schedule item for Patient 1 shows up under Patient 2 —
   suspected Firestore data mismanagement.
3. Reminder CRUD + visual bugs, an error mentioning "Drei" in logs — not yet
   reproduced/understood, need more detail from Ralph (screenshot or exact
   log line).

## Root cause found (covers #1 and #2)

`prototype_home_page.dart`'s schedule/reminders section is **not**
Firestore-backed — it's plain `setState` fetched once. Two bugs stacked:

- `initState()` called `_loadSchedule()` immediately, without waiting for
  `SelectedProfile.instance.ready`. Right after login, `SelectedProfile`
  is still bootstrapping the household async — `_scope` was null, so the
  page silently settled on an empty schedule and nothing ever retried.
  Reads as "reminders disappeared."
- Only `_buildHeader()` listens to `SelectedProfile` via `ListenableBuilder`.
  Switching care recipients (`/profiles`) updates the header but the
  schedule/reminders lists just keep whatever the *previous* recipient's
  fetch returned, until a manual pull-to-refresh. Reads as "Patient 1's
  schedule showing under Patient 2" — not a Firestore/backend scoping bug;
  backend routes are correctly scoped per `careRecipientId` subcollection
  (verified in `tasks.js`/`observations.js`).

## Fix

- Await `SelectedProfile.instance.ready` before the first `_loadSchedule()`.
- Add a `SelectedProfile` listener that reloads when `careRecipient.id`
  actually changes (not on every notify), removed in `dispose()`.
- Guard against a stale in-flight fetch landing after a second recipient
  switch (compare the requested recipient id before applying results).

## Status

- [x] Root cause identified
- [x] Fix implemented in `prototype_home_page.dart`
- [ ] Manual verification: login → reminders present; switch profile →
      schedule updates immediately, no stale data
- [ ] Follow up with Ralph on the "Drei" log error / CRUD specifics
- [ ] Tests, PR
