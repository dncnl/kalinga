import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart' show Listenable;
import 'package:go_router/go_router.dart';

import 'services/profile_service.dart';
import 'state/dev_bypass.dart';
import 'state/selected_profile.dart';
import 'state/session_role.dart';
import 'pages/prototype_language_page.dart';
import 'pages/prototype_patient_page.dart';
import 'pages/profile_picker_page.dart';
import 'pages/prototype_home_page.dart';
import 'pages/prototype_patient_detail_page.dart';
import 'pages/reminders_page.dart';
import 'pages/reminder_checkin_page.dart';
import 'pages/symptom_check_page.dart';
import 'services/reminder_service.dart';
import 'pages/prototype_log_page.dart';
import 'pages/ask_page.dart';
import 'pages/meds_page.dart';
import 'pages/viewer_page.dart';
import 'pages/help_page.dart';
import 'pages/activity_page.dart';
import 'pages/settings_page.dart';
import 'pages/auth_page.dart';
import 'pages/family_register_page.dart';
import 'pages/family_code_page.dart';
import 'pages/family_recipients_page.dart';
import 'pages/role_select_page.dart';
import 'pages/welcome_page.dart';
import 'services/family_viewer_service.dart';

final router = GoRouter(
  initialLocation: '/',
  // SelectedProfile.initialize() (fired unawaited in main.dart) restores an
  // already-onboarded caregiver's household/profile from the server. Once
  // that resolves and finds an existing profile, skip the onboarding
  // flow (/language, /patient) straight to /home instead of making a
  // returning caregiver click through it again every launch.
  refreshListenable: Listenable.merge([SelectedProfile.instance, DevBypass.instance, SessionRole.instance]),
  redirect: (context, state) {
    // A real (non-anonymous) account is required to use the app —
    // AuthPage's dev-only "Skip (dev)" button is the only way past this
    // outside of actually registering/signing in. The whole entry funnel
    // (welcome → role picker → auth / family-code / invite) has to stay
    // reachable without an account, since it's how one gets created.
    final loc = state.matchedLocation;
    final onEntryFunnel = loc == '/' ||
        loc == '/role' ||
        loc == '/auth' ||
        loc == '/family-code' ||
        loc.startsWith('/invite/');
    final user = FirebaseAuth.instance.currentUser;
    final hasRealAccount = user != null && !user.isAnonymous;
    if (!hasRealAccount && !DevBypass.instance.skipped && !onEntryFunnel) return '/';

    final profile = SelectedProfile.instance;
    // Family surface never touches SelectedProfile — WelcomePage's resume
    // logic (async FamilyViewerService resolution, can't run in a sync
    // redirect) routes a restored family session to its viewer.
    if (SessionRole.instance.isFamily) return null;
    if (!profile.hasProfile) return null;

    // A caregiver with a restored profile shouldn't click through
    // language selection again (re-picking it makes no sense once a
    // profile exists), and a signed-in one shouldn't sit on the entry
    // funnel after an app restart (session persistence) — both go home.
    //
    // /patient is deliberately NOT included here even though it's also
    // part of first-run onboarding: ProfilePickerPage's "Add another
    // profile" button pushes /patient again for a caregiver who already
    // has one (hasProfile == true), and this redirect ran before the page
    // ever rendered, bouncing straight back to /home — the button looked
    // completely broken. /patient itself already handles both create (no
    // `editing` extra) and edit correctly regardless of hasProfile, and
    // navigates itself on success (see prototype_patient_page.dart), so it
    // doesn't need this guard's help.
    if (loc == '/language') return '/home';
    final onWelcomeOrAuth = loc == '/' || loc == '/role' || loc == '/auth';
    if (hasRealAccount && onWelcomeOrAuth) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/',          builder: (c, s) => const WelcomePage()),
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
        builder: (c, s) => RemindersPage(patientId: s.pathParameters['id']!)),
    // The ReminderEvent comes through `extra` so the check-in can render its
    // question set immediately; it degrades to a plain note if opened cold.
    GoRoute(path: '/checkin/:eventId',
        builder: (c, s) => ReminderCheckinPage(
              eventId: s.pathParameters['eventId']!,
              event: s.extra as ReminderEvent?,
            )),
    GoRoute(path: '/symptom-check', builder: (c, s) => const SymptomCheckPage()),
    GoRoute(path: '/viewer/:id',
        builder: (c, s) => ViewerPage(viewerId: s.pathParameters['id']!)),
    GoRoute(path: '/auth',
        builder: (c, s) => AuthPage(
              startInLoginMode: s.uri.queryParameters['mode'] == 'login',
              asFamilyMember: s.uri.queryParameters['role'] == 'family',
            )),
    GoRoute(path: '/role',
        builder: (c, s) => RoleSelectPage(isLogin: s.uri.queryParameters['mode'] == 'login')),
    GoRoute(path: '/family-code',  builder: (c, s) => const FamilyCodePage()),
    GoRoute(path: '/family-recipients',
        builder: (c, s) => FamilyRecipientsPage(recipients: s.extra as List<ViewableCareRecipient>)),
    GoRoute(path: '/invite/:token',
        builder: (c, s) => FamilyRegisterPage(token: s.pathParameters['token']!)),
  ],
);
