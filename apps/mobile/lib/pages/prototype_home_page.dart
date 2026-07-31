import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/medication_service.dart';
import '../services/reminder_service.dart';
import '../state/selected_profile.dart';
import '../theme.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class PrototypeHomePage extends StatefulWidget {
  const PrototypeHomePage({super.key});

  @override
  State<PrototypeHomePage> createState() => _PrototypeHomePageState();
}

class _PrototypeHomePageState extends State<PrototypeHomePage> {
  static const _bg = Color(0xFFFFFFFF);
  static const _red = Color(0xFFEF3E23);
  static const _teal = Color(0xFF2BBFB3);
  static const _amber = Color(0xFFD97706);
  static const _cardShadow = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  int _navIndex = 0;
  final _medicationService = const MedicationService();
  final _reminderService = const ReminderService();

  List<MedicationEvent> _events = [];
  Map<String, Medication> _medsById = {};
  List<ReminderEvent> _reminderEvents = [];
  bool _loadingSchedule = true;
  String? _scheduleError;

  // The schedule/reminders section isn't rebuilt by a ListenableBuilder (the
  // header is the only part that listens directly), so without this the
  // fetched lists go stale when the caregiver switches care recipients —
  // Patient 1's schedule kept showing under Patient 2 until a manual
  // pull-to-refresh. Tracked separately from SelectedProfile.careRecipient
  // so the listener only reloads on an actual switch, not every notify.
  String? _loadedForRecipientId;

  @override
  void initState() {
    super.initState();
    SelectedProfile.instance.addListener(_onProfileChanged);
    // initState fires before SelectedProfile.initialize() (started
    // unawaited in main.dart) necessarily finishes — loading immediately
    // could see a null householdId/careRecipient and settle on an empty
    // schedule that nothing ever retries, which is why reminders looked
    // like they "disappeared" right after logging back in.
    SelectedProfile.instance.ready.then((_) {
      if (mounted) _loadSchedule();
    });
  }

  @override
  void dispose() {
    SelectedProfile.instance.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    final recipientId = SelectedProfile.instance.careRecipient?.id;
    if (recipientId != _loadedForRecipientId) _loadSchedule();
  }

  ({String householdId, String careRecipientId})? get _scope {
    final profile = SelectedProfile.instance;
    final householdId = profile.householdId;
    final careRecipientId = profile.careRecipient?.id;
    if (householdId == null || careRecipientId == null) return null;
    return (householdId: householdId, careRecipientId: careRecipientId);
  }

  Future<void> _loadSchedule() async {
    final scope = _scope;
    if (scope == null) {
      _loadedForRecipientId = null;
      setState(() {
        _loadingSchedule = false;
        _events = [];
        _reminderEvents = [];
        _medsById = {};
      });
      return;
    }
    // Captured up front: if the caregiver switches recipients again while
    // this fetch is in flight, the response landing later must not clobber
    // the newer recipient's already-loading/loaded data with the old one's.
    final requestedRecipientId = scope.careRecipientId;
    setState(() {
      _loadingSchedule = true;
      _scheduleError = null;
    });
    try {
      final results = await Future.wait([
        _medicationService.listMedications(scope.householdId, scope.careRecipientId),
        _medicationService.todaysEvents(scope.householdId, scope.careRecipientId),
        // F2 reminders load alongside the medicine schedule rather than in
        // their own pass — they're both "what is due today".
        _reminderService.todaysEvents(
          householdId: scope.householdId,
          careRecipientId: scope.careRecipientId,
        ),
      ]);
      if (!mounted || SelectedProfile.instance.careRecipient?.id != requestedRecipientId) return;
      final meds = results[0] as List<Medication>;
      final events = results[1] as List<MedicationEvent>;
      final reminders = results[2] as List<ReminderEvent>;
      events.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      reminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      setState(() {
        _medsById = {for (final m in meds) m.id: m};
        _events = events;
        _reminderEvents = reminders;
        _loadedForRecipientId = requestedRecipientId;
      });
    } catch (e) {
      if (!mounted || SelectedProfile.instance.careRecipient?.id != requestedRecipientId) return;
      setState(() => _scheduleError = e.toString());
    } finally {
      if (mounted && SelectedProfile.instance.careRecipient?.id == requestedRecipientId) {
        setState(() => _loadingSchedule = false);
      }
    }
  }

  Future<void> _markTaken(MedicationEvent event) async {
    final scope = _scope;
    if (scope == null) return;
    try {
      await _medicationService.markEvent(scope.householdId, scope.careRecipientId, event.id, status: 'completed');
      await _loadSchedule();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not mark taken: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSchedule,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildHeader(context),
                const SizedBox(height: 20),
                _buildGreetingCard(),
                const SizedBox(height: 16),
                _buildStartLogButton(),
                const SizedBox(height: 10),
                _buildSymptomCheckButton(),
                const SizedBox(height: 28),
                _buildQuickActions(),
                const SizedBox(height: 28),
                _buildRemindersSection(),
                _buildScheduleSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return ListenableBuilder(
      listenable: SelectedProfile.instance,
      builder: (context, _) {
        final recipient = SelectedProfile.instance.careRecipient;
        return Row(
          children: [
            GestureDetector(
              onTap: () => context.push('/profiles'),
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(color: Color(0xFF2BBFB3), shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    recipient?.initials ?? '?',
                    style: AppTextStyles.bodyMedium(fontSize: 13).copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/profiles'),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipient?.displayName ?? 'Add a profile',
                          style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87),
                        ),
                        if (recipient != null)
                          Text(
                            [
                              if (recipient.age != null) '${recipient.age}',
                              if (recipient.preferredLanguages.isNotEmpty) 'speaks ${recipient.preferredLanguages.first}',
                            ].join(' · '),
                            style: AppTextStyles.body(fontSize: 11).copyWith(color: Colors.grey.shade500),
                          ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey.shade500),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: () => context.push('/activity'),
              icon: Icon(Icons.notifications_none_rounded, color: Colors.grey.shade700, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: () => context.push('/settings'),
              icon: Icon(Icons.settings_outlined, color: Colors.grey.shade700, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        );
      },
    );
  }

  // ── Greeting card ──────────────────────────────────────────────────────────

  static const _weekdayNames = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
  static const _monthNames = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];

  static String _todayLabel() {
    final now = DateTime.now();
    return '${_weekdayNames[now.weekday - 1]}, ${now.day} ${_monthNames[now.month - 1]}';
  }

  static String _timeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? get _todaysObservationsStream {
    final scope = _scope;
    if (scope == null) return null;
    final startOfDay = DateTime.now().toUtc();
    final todayStart = DateTime.utc(startOfDay.year, startOfDay.month, startOfDay.day);
    return FirebaseFirestore.instance
        .collection('households/${scope.householdId}/careRecipients/${scope.careRecipientId}/observations')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  Widget _buildGreetingCard() {
    final name = SelectedProfile.instance.careRecipient?.displayName ?? 'them';
    // Auth is optional (see auth_page.dart) — most caregivers never set a
    // displayName, so this only personalizes the greeting for the ones who
    // did.
    final caregiverName = FirebaseAuth.instance.currentUser?.displayName;
    final greeting = caregiverName != null && caregiverName.isNotEmpty
        ? '${_timeOfDayGreeting()}, $caregiverName'
        : _timeOfDayGreeting();

    final completedToday = _events.where((e) => e.status == 'completed').length;
    final totalToday = _events.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3C4),
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -12,
            right: -12,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFFDE68A).withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _todayLabel(),
                style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(color: Colors.grey.shade600, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              Text(
                greeting,
                style: AppTextStyles.heading(fontSize: 26).copyWith(color: Colors.black),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _todaysObservationsStream,
                builder: (context, snapshot) {
                  final hasLoggedToday = (snapshot.data?.docs.length ?? 0) > 0;
                  return Row(children: [
                    Icon(
                      hasLoggedToday ? Icons.check_circle_rounded : Icons.mic_none_rounded,
                      size: 16,
                      color: hasLoggedToday ? const Color(0xFF22C55E) : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hasLoggedToday ? "Logged for $name today." : "Haven't logged $name yet today.",
                        style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade700, height: 1.4),
                      ),
                    ),
                  ]);
                },
              ),
              if (totalToday > 0) ...[
                const SizedBox(height: 10),
                Container(height: 1, color: Colors.black.withValues(alpha: 0.06)),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.medication_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    '$completedToday of $totalToday medicine doses taken today',
                    style: AppTextStyles.bodyMedium(fontSize: 13).copyWith(color: Colors.grey.shade700),
                  ),
                ]),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Start daily log button ─────────────────────────────────────────────────

  Widget _buildStartLogButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.go('/log'),
        icon: const Icon(Icons.mic_none_rounded, size: 20),
        label: Text(
          'Start daily log',
          style: AppTextStyles.bodyMedium(fontSize: 17).copyWith(color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          elevation: 2,
          shadowColor: _red.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  // ── Symptom check-in (F1) ──────────────────────────────────────────────────
  //
  // Its own full-width button rather than a fifth quick-action icon: this is
  // the path someone takes when they think something is wrong right now, and
  // it should be findable without reading a row of small labels. Calm styling
  // on purpose — an alarming red button invites panic taps.

  Widget _buildSymptomCheckButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => context.push('/symptom-check'),
        icon: const Icon(Icons.health_and_safety_outlined, size: 20),
        label: Text(
          'Something is wrong',
          style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.black87),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: Colors.grey.shade400, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
      ),
    );
  }

  // ── Quick actions ──────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    final recipientId = SelectedProfile.instance.careRecipient?.id ?? 'none';
    final dueCount = _events.where((e) => e.status == 'scheduled' && e.scheduledAt.isBefore(DateTime.now())).length;
    final actions = [
      const _QuickAction(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Ask',
        bg: Color(0xFFFFD5CF),
        iconColor: Color(0xFFEF3E23),
        route: '/ask',
      ),
      _QuickAction(
        icon: Icons.medication_outlined,
        label: 'Meds',
        bg: const Color(0xFFD0EFFE),
        iconColor: const Color(0xFF2BBFB3),
        badge: dueCount > 0 ? '$dueCount' : null,
        route: '/meds',
      ),
      _QuickAction(
        icon: Icons.schedule_rounded,
        label: 'Schedules',
        bg: const Color(0xFFFFF3C4),
        iconColor: _amber,
        route: '/patients/$recipientId/schedules',
      ),
      const _QuickAction(
        icon: Icons.help_outline_rounded,
        label: 'Help',
        bg: Color(0xFFEEEEEE),
        iconColor: Color(0xFF555555),
        route: '/help',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(color: Colors.grey.shade500, letterSpacing: 0.8),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: _cardShadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: actions.map((a) => _QuickActionTile(action: a)).toList(),
          ),
        ),
      ],
    );
  }

  // ── Schedule section ───────────────────────────────────────────────────────

  // ── Today's reminders (F2/F3) ──────────────────────────────────────────────
  //
  // Hidden entirely when there are none: an empty-state card for a feature
  // the caregiver hasn't set up yet is just noise above the thing she
  // actually opened the app for. The reminders screen itself has the empty
  // state and the add button.

  Widget _buildRemindersSection() {
    if (_loadingSchedule || _reminderEvents.isEmpty) return const SizedBox.shrink();
    final recipientId = SelectedProfile.instance.careRecipient?.id ?? 'none';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("TODAY'S REMINDERS",
            style: AppTextStyles.bodyMedium(fontSize: 11)
                .copyWith(color: Colors.grey.shade500, letterSpacing: 0.8)),
        GestureDetector(
          onTap: () => context.push('/patients/$recipientId/schedules'),
          child: Text('Manage', style: AppTextStyles.bodyMedium(fontSize: 12).copyWith(color: _teal)),
        ),
      ]),
      const SizedBox(height: 12),
      ..._reminderEvents.map((event) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ReminderTile(
              event: event,
              onTap: event.isDone
                  ? null
                  : () async {
                      await context.push('/checkin/${event.id}', extra: event);
                      if (mounted) _loadSchedule();
                    },
            ),
          )),
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "TODAY'S MEDICINE SCHEDULE",
              style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(color: Colors.grey.shade500, letterSpacing: 0.8),
            ),
            GestureDetector(
              onTap: () => context.push('/meds'),
              child: Text(
                'See all',
                style: AppTextStyles.bodyMedium(fontSize: 12).copyWith(color: _teal),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingSchedule)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_scheduleError != null)
          Text(_scheduleError!, style: AppTextStyles.body(fontSize: 13).copyWith(color: _red))
        else if (_events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(children: [
              Icon(Icons.medication_outlined, size: 28, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'No medicines scheduled for today.',
                style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade500),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => context.push('/meds'),
                child: Text(
                  'Add a medicine',
                  style: AppTextStyles.bodyMedium(fontSize: 13).copyWith(color: _teal),
                ),
              ),
            ]),
          )
        else
          ...List.generate(
            _events.length,
            (i) => _ScheduleTile(
              event: _events[i],
              medication: _medsById[_events[i].medicationId],
              isLast: i == _events.length - 1,
              onMarkTaken: () => _markTaken(_events[i]),
            ),
          ),
      ],
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    const items = [
      BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Today'),
      BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Ask'),
      BottomNavigationBarItem(icon: Icon(Icons.mic_none_rounded), label: 'Log'),
      BottomNavigationBarItem(icon: Icon(Icons.medication_outlined), label: 'Meds'),
      BottomNavigationBarItem(icon: Icon(Icons.help_outline_rounded), label: 'Help'),
    ];

    return BottomNavigationBar(
      currentIndex: _navIndex,
      onTap: (i) {
        setState(() => _navIndex = i);
        switch (i) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/ask');
            break;
          case 2:
            context.go('/log');
            break;
          case 3:
            context.go('/meds');
            break;
          case 4:
            context.go('/help');
            break;
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: _red,
      unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle: AppTextStyles.bodyMedium(fontSize: 11),
      unselectedLabelStyle: AppTextStyles.body(fontSize: 11),
      elevation: 8,
      items: items,
    );
  }
}

// ── Quick action tile ─────────────────────────────────────────────────────────

class _QuickAction {
  final IconData icon;
  final String label;
  final Color bg;
  final Color iconColor;
  final String? badge;
  final String route;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.bg,
    required this.iconColor,
    required this.route,
    this.badge,
  });
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(action.route),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: action.bg, borderRadius: BorderRadius.circular(16)),
                child: Icon(action.icon, color: action.iconColor, size: 26),
              ),
              if (action.badge != null)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(color: Color(0xFFEF3E23), shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        action.badge!,
                        style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(action.label, style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

// ── Schedule tile (real medication events) ──────────────────────────────────

enum _ScheduleStatus { done, due, upcoming, skipped }

class _ReminderTile extends StatelessWidget {
  final ReminderEvent event;
  final VoidCallback? onTap;

  const _ReminderTile({required this.event, this.onTap});

  static const _teal = Color(0xFF2BBFB3);

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(event.scheduledAt);
    final timeText =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final isDue = !event.isDone && event.scheduledAt.isBefore(DateTime.now());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: isDue ? _teal : Colors.grey.shade200, width: isDue ? 1.5 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: event.isDone ? _teal : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                  color: event.isDone ? _teal : Colors.grey.shade300, width: 1.5),
            ),
            child: event.isDone
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.taskTitle,
                style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(
                  color: event.isDone ? Colors.grey.shade500 : Colors.black87,
                  decoration: event.isDone ? TextDecoration.lineThrough : null,
                )),
            const SizedBox(height: 2),
            Text(timeText,
                style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500)),
          ])),
          if (!event.isDone)
            Text(event.hasCheckin ? 'How did it go?' : 'Mark done',
                style: AppTextStyles.bodyMedium(fontSize: 13).copyWith(color: _teal)),
        ]),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final MedicationEvent event;
  final Medication? medication;
  final bool isLast;
  final VoidCallback onMarkTaken;

  const _ScheduleTile({
    required this.event,
    required this.medication,
    required this.isLast,
    required this.onMarkTaken,
  });

  static const _teal = Color(0xFF2BBFB3);
  static const _amber = Color(0xFFD97706);

  _ScheduleStatus get _status {
    if (event.status == 'completed') return _ScheduleStatus.done;
    if (['skipped', 'refused', 'notAvailable'].contains(event.status)) return _ScheduleStatus.skipped;
    if (event.scheduledAt.isBefore(DateTime.now())) return _ScheduleStatus.due;
    return _ScheduleStatus.upcoming;
  }

  Color get _badgeColor => switch (_status) {
        _ScheduleStatus.done => _teal,
        _ScheduleStatus.due => _amber,
        _ScheduleStatus.skipped => Colors.grey,
        _ScheduleStatus.upcoming => Colors.grey,
      };

  String get _badgeLabel => switch (_status) {
        _ScheduleStatus.done => 'TAKEN',
        _ScheduleStatus.due => 'DUE',
        _ScheduleStatus.skipped => event.status.toUpperCase(),
        _ScheduleStatus.upcoming => 'UPCOMING',
      };

  @override
  Widget build(BuildContext context) {
    final isDone = _status == _ScheduleStatus.done;
    final name = medication?.name ?? 'Medicine';
    final detailParts = [
      if (medication?.strength != null) medication!.strength!,
      TimeOfDay.fromDateTime(event.scheduledAt.toLocal()).format(context),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                isDone
                    ? Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                      )
                    : Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300, width: 1.5),
                        ),
                      ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_badgeLabel, style: AppTextStyles.bodyMedium(fontSize: 10).copyWith(color: _badgeColor)),
                    ),
                    const SizedBox(width: 8),
                    Text(detailParts.join(' · '), style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade500)),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(name, style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87)),
                      ),
                      if (!isDone)
                        OutlinedButton(
                          onPressed: onMarkTaken,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: const BorderSide(color: Colors.black87),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('Mark taken', style: AppTextStyles.bodyMedium(fontSize: 12)),
                        ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
