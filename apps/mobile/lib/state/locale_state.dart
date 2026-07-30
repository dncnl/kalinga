import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsLocaleKey = 'kalinga.locale';

/// The caregiver's chosen speaking language (BCP-47-ish code matching
/// apps/api's LocaleCode: fil/ceb/id/vi — see translate.js). Used for
/// symptom-checker requests and voice-log transcription/translation.
/// Persisted like SelectedProfile; defaults to 'fil' until a real
/// selection is made or restored, matching the old demoLocale placeholder
/// this replaces.
class LocaleState extends ChangeNotifier {
  LocaleState._();
  static final instance = LocaleState._();

  String locale = 'fil';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsLocaleKey);
    if (saved != null) {
      locale = saved;
      notifyListeners();
    }
  }

  Future<void> select(String newLocale) async {
    locale = newLocale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLocaleKey, newLocale);
  }
}
