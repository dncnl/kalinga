import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Base URL for apps/api. Override at build/run time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8081
///
/// Without an override, picks a per-platform default that reaches a
/// locally-running apps/api: 10.0.2.2 is a special NAT alias that ONLY
/// means anything on the Android emulator — using it on desktop/iOS just
/// times out with a SocketException, since there's no such host. Everything
/// else (Windows/macOS/Linux/web/iOS simulator) can reach the host machine
/// via plain localhost. A physical device needs the machine's real LAN IP,
/// which nothing here can guess — use the dart-define override for that.
/// Nothing is deployed yet — see PLAN.md.
const _envOverride = String.fromEnvironment('API_BASE_URL');

String get apiBaseUrl {
  if (_envOverride.isNotEmpty) return _envOverride;
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8081';
  return 'http://localhost:8081';
}

// Prototype-only stand-ins until profile selection (Multi-patient profiles
// in CLAUDE.md) and language selection are wired to real shared state.
const demoHouseholdId = 'demo-household';
const demoCareRecipientId = 'lola-rosa';
const demoLocale = 'fil';
