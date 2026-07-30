# Tests

Cross-app tests that don't belong to a single package live here. Each app
still owns its own unit tests alongside its code:

- `apps/mobile/test/` — Flutter widget/unit tests (required location, Flutter
  convention).
- `apps/api/test/` — Node/Express unit tests (create when `apps/api` gets its
  first source files).
- `packages/kalinga_firestore_package/` — schema validation scripts under
  `scripts/validate-package.mjs`.

## Structure

- `unit/` — cross-package unit tests that don't fit inside a single app
  (e.g. shared schema/contract logic).
- `integration/` — tests that exercise multiple services together, e.g.
  mobile → API → Firestore/Storage (emulator-backed).
- `e2e/` — full user-flow tests driving the app end to end (e.g. record a
  voice log → see it in the trend chart).

## Status

Empty scaffolding for now — no runner wired up yet. Fill in as features
(starting with feature_2, the voice-log) land and need coverage.
