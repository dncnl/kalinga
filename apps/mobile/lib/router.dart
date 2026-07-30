import 'package:go_router/go_router.dart';

import 'services/profile_service.dart';
import 'pages/prototype_language_page.dart';
import 'pages/prototype_patient_page.dart';
import 'pages/profile_picker_page.dart';
import 'pages/prototype_home_page.dart';
import 'pages/prototype_patient_detail_page.dart';
import 'pages/prototype_patient_schedule_page.dart';
import 'pages/prototype_checkin_page.dart';
import 'pages/prototype_log_page.dart';
import 'pages/ask_page.dart';
import 'pages/meds_page.dart';
import 'pages/viewer_page.dart';
import 'pages/help_page.dart';
import 'pages/activity_page.dart';
import 'pages/settings_page.dart';
import 'pages/auth_page.dart';
import 'pages/family_register_page.dart';

final router = GoRouter(
  initialLocation: '/language',
  routes: [
    GoRoute(path: '/language',  builder: (c, s) => const PrototypeLanguagePage()),
    GoRoute(path: '/patient',   builder: (c, s) => const PrototypePatientPage()),
    GoRoute(path: '/patient/edit',
        builder: (c, s) => PrototypePatientPage(editing: s.extra as CareRecipient?)),
    GoRoute(path: '/profiles',  builder: (c, s) => const ProfilePickerPage()),
    GoRoute(path: '/home',      builder: (c, s) => const PrototypeHomePage()),
    GoRoute(path: '/ask',       builder: (c, s) => const AskPage()),
    GoRoute(path: '/log',       builder: (c, s) => const PrototypeLogPage()),
    GoRoute(path: '/meds',      builder: (c, s) => const MedsPage()),
    GoRoute(path: '/help',      builder: (c, s) => const HelpPage()),
    GoRoute(path: '/activity',  builder: (c, s) => const ActivityPage()),
    GoRoute(path: '/settings',  builder: (c, s) => const SettingsPage()),
    GoRoute(path: '/patients/:id',
        builder: (c, s) => PrototypePatientDetailPage(patientId: s.pathParameters['id']!)),
    GoRoute(path: '/patients/:id/schedules',
        builder: (c, s) => PrototypePatientSchedulePage(patientId: s.pathParameters['id']!)),
    GoRoute(path: '/checkin/:scheduleId',
        builder: (c, s) => PrototypeCheckinPage(scheduleId: s.pathParameters['scheduleId']!)),
    GoRoute(path: '/viewer/:id',
        builder: (c, s) => ViewerPage(viewerId: s.pathParameters['id']!)),
    GoRoute(path: '/auth',    builder: (c, s) => const AuthPage()),
    GoRoute(path: '/invite/:token',
        builder: (c, s) => FamilyRegisterPage(token: s.pathParameters['token']!)),
  ],
);
