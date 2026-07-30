import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'router.dart';
import 'state/selected_profile.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
