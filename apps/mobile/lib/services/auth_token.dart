import 'package:firebase_auth/firebase_auth.dart';

/// Shared by every backend-calling service. No real sign-in flow exists yet
/// (see PLAN.md) — anonymous auth is a stopgap so apps/api's requireAuth
/// middleware has a real Firebase ID token to check.
Future<String> getIdToken() async {
  var user = FirebaseAuth.instance.currentUser;
  user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
  final token = await user?.getIdToken();
  if (token == null) {
    throw Exception('Could not obtain a Firebase ID token');
  }
  return token;
}
