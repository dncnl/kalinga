import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'router.dart';
import 'state/selected_profile.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firebase Auth restores a persisted session (a real login, or a
  // previous anonymous account) ASYNCHRONOUSLY after initializeApp() —
  // FirebaseAuth.instance.currentUser can still read null for a brief
  // moment even when a real logged-in session is about to be restored.
  // Without this wait, auth_token.dart's getIdToken() can race past that
  // restoration and spin up a throwaway NEW anonymous account instead of
  // resuming the real one — i.e. "log in, close the app, reopen it" would
  // silently forget you were logged in. Waiting for the first
  // authStateChanges() emission settles "who's actually logged in" first.
  await FirebaseAuth.instance.authStateChanges().first;

  // Fire-and-forget: app launches immediately, screens that depend on the
  // selected profile listen to SelectedProfile.instance and react once
  // this resolves rather than blocking startup on a network round trip.
  unawaited(SelectedProfile.instance.initialize());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kalinga',
      theme: appTheme,
      routerConfig: router,
    );
  }
}
