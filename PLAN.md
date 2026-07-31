# Voice-log demo mode (for the showcase video)

Branch: `feature/voice-log-demo-mode`, cut from `main`.

## Ask

Ralph wants to film the app for the hackathon video without relying on
real speech-to-text picking up whatever's said on camera. "Hold to Speak"
should just move the trend chart, no real recording.

## Design

Gated behind the existing `DevBypass.instance.skipped` flag (the same one
`AuthPage`'s "Skip (dev)" button sets) — deliberately not a separate
always-visible demo button, since a second UI element would look odd on
camera and the literal ask was "after I press Hold to Speak."

- `prototype_log_page.dart`: when the flag is set, `_startRecording`
  skips the mic entirely (just flips the recording animation state), and
  `_stopRecordingAndSubmit` calls the new demo path instead of the real
  upload/STT pipeline. `_cancelRecording` guarded the same way — the
  recorder was never started, so there's nothing to cancel.
- New server route `POST .../observations/demo-log` (`observations.js`):
  no audio, no STT. Writes a plausible observation (sleep/appetite/mood
  randomized 0.65–0.95, gently upward of neutral so a short clip shows a
  visible trend) straight through the same `buildObservationDocument` +
  daily/weekly rollup path a real voice log uses — the chart updates
  exactly the way it would for a real log, same Firestore listener,
  nothing chart-side needed to change.
- Skips a real Mandarin translation call (hardcoded placeholder text
  instead) — this observation is never meant to be read by family, and a
  live network call is one more thing that could stall mid-recording.

## Known trade-off

`DevBypass.skipped` is the existing "Skip (dev)" flag from the auth
funnel — broader than just this feature. Any dev-bypass session now gets
fake voice logs instead of exercising the real STT pipeline. Fine for
filming; worth a narrower flag later if someone needs to dev-bypass auth
*and* still test real voice logging in the same session.

## Status

- [x] Implemented, both mobile + API sides
- [x] Tests: `observations-demo-log.test.js` (3) — full backend suite
      194/194, mobile suite 15/15, `flutter analyze` clean
- [ ] PR, merge to `main`
