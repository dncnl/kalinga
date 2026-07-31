# Fix: family viewer page only shows stats, not translated notes

Branch: `fix/viewer-page-translated-notes-feed`, cut from `main`.

## Bug report (from Ralph)

"Landing page of family account only shows translated stats of the
patient."

## What was actually going on

`viewer_page.dart` (the family/doctor read-only surface) only rendered two
aggregate percentage bars (睡眠/進食, from `weeklySummaries.trendSeries`).
Every observation — voice logs, symptom check-ins, and now the F1 chat
exchanges — already carries a full Mandarin translation
(`translations['zh-TW'].text`, written specifically for this audience, see
`buildObservationDocument.js`) and none of it ever reached the family view.
Literally true as reported: only stats, no actual notes.

## Fix

- New `_recentObservationsStream()`: queries the last 8 `ready`
  observations, ordered by `observedAt desc`. Reuses an index already
  declared in `firestore.indexes.json` (`status` + `observedAt`) — no
  schema change needed.
- New `_RecentNoteCard`: shows the translated Mandarin text, a
  concern-level badge (緊急/請留意) when `safetyAssessment.concernLevel`
  is `medium`/`high`, and the date. Falls back to a plain "translation
  unavailable" message rather than showing untranslated original-language
  text — this is the one audience that can't read that.
- Additive: the sleep/food bars stay, this sits below them.

## Status

- [x] Implemented, `flutter analyze` clean, mobile suite 13/13
- [ ] Manual verification against a real household with mixed
      voice-log/symptom-check/chat observations
- [ ] PR, merge to `main`
