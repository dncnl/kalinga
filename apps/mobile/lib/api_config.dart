/// Base URL for apps/api. Override at build/run time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8081
///
/// The default (10.0.2.2) only reaches a locally-running apps/api from the
/// Android emulator — it will NOT work on a physical device or iOS
/// simulator (use your machine's LAN IP for those) or in production (needs
/// a deployed URL). Nothing is deployed yet — see PLAN.md.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8081',
);

// Prototype-only stand-ins until profile selection (Multi-patient profiles
// in CLAUDE.md) and language selection are wired to real shared state.
const demoHouseholdId = 'demo-household';
const demoCareRecipientId = 'lola-rosa';
const demoLocale = 'fil';
