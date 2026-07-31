import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsRoleKey = 'kalinga.role';

/// Which surface this signed-in account uses: 'caregiver' or 'family'.
///
/// Persisted so an app restart restores the right surface without asking
/// again — a family member must NOT go through SelectedProfile.initialize()
/// on launch (its POST /households/bootstrap would mint a spurious caregiver
/// household for a family account with no membership yet), and the router
/// needs to know synchronously which home surface to bounce a restored
/// session to. Loaded once in main() before runApp for exactly that reason.
class SessionRole extends ChangeNotifier {
  SessionRole._();
  static final instance = SessionRole._();

  static const caregiver = 'caregiver';
  static const family = 'family';

  String? _role;
  String? get role => _role;
  bool get isFamily => _role == family;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _role = prefs.getString(_prefsRoleKey);
    notifyListeners();
  }

  Future<void> set(String role) async {
    _role = role;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsRoleKey, role);
  }

  Future<void> clear() async {
    _role = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsRoleKey);
  }
}
