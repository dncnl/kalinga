import 'package:flutter/foundation.dart';

/// Set only by AuthPage's debug-only "Skip (dev)" button — router.dart's
/// gate redirect checks this alongside "has a real account" so the skip
/// tap actually sticks instead of the redirect immediately bouncing back
/// to /auth (only an anonymous session exists after skipping, which the
/// gate correctly never treats as a real account on its own).
class DevBypass extends ChangeNotifier {
  DevBypass._();
  static final instance = DevBypass._();

  bool skipped = false;

  void skip() {
    skipped = true;
    notifyListeners();
  }
}
