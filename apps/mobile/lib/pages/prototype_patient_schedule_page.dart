import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/selected_profile.dart';
import '../theme.dart';
import '../widgets/back_button.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _ScheduleEntry {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String time;
  bool enabled;

  _ScheduleEntry({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.time,
    this.enabled = true,
  });
}

// ── Page ──────────────────────────────────────────────────────────────────────

class PrototypePatientSchedulePage extends StatefulWidget {
  final String patientId;
  const PrototypePatientSchedulePage({super.key, required this.patientId});

  @override
  State<PrototypePatientSchedulePage> createState() =>
      _PrototypePatientSchedulePageState();
}

class _PrototypePatientSchedulePageState
    extends State<PrototypePatientSchedulePage> {
  static const _bg = Color(0xFFFFFFFF);
  static const _teal = Color(0xFF2BBFB3);

  late final List<_ScheduleEntry> _entries = [
    _ScheduleEntry(
      icon: Icons.restaurant_outlined,
      iconBg: const Color(0xFFFFF3C4),
      iconColor: const Color(0xFFD97706),
      label: 'Breakfast',
      time: '08:00 · daily',
      enabled: true,
    ),
    _ScheduleEntry(
      icon: Icons.directions_walk_rounded,
      iconBg: const Color(0xFFD0EFFE),
      iconColor: const Color(0xFF2BBFB3),
      label: 'Morning walk',
      time: '10:00 · daily',
      enabled: true,
    ),
    _ScheduleEntry(
      icon: Icons.medication_outlined,
      iconBg: const Color(0xFFFFD5CF),
      iconColor: const Color(0xFFEF3E23),
      label: 'Medicine',
      time: '09:00 · 21:00',
      enabled: true,
    ),
    _ScheduleEntry(
      icon: Icons.bedtime_outlined,
      iconBg: const Color(0xFFEEEEEE),
      iconColor: const Color(0xFF777777),
      label: 'Sleep check',
      time: '22:00 · daily',
      enabled: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(context),
              const SizedBox(height: 28),

              // ── Title ────────────────────────────────────────────────
              Text(
                'Schedules',
                style: AppTextStyles.heading(fontSize: 32)
                    .copyWith(color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                'Kalinga asks you at these times. Turn one off\nany day it does not apply.',
                style: AppTextStyles.body(fontSize: 14).copyWith(
                  color: _teal,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // ── Schedule cards ───────────────────────────────────────
              ..._entries.asMap().entries.map((e) {
                final i = e.key;
                final entry = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ScheduleCard(
                    entry: entry,
                    onToggle: (val) =>
                        setState(() => _entries[i].enabled = val),
                  ),
                );
              }),

              // ── Add schedule ─────────────────────────────────────────
              GestureDetector(
                onTap: () => context.push('/checkin/morning-walk'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(
                      color: Colors.grey.shade400,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.grey.shade500, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Add schedule',
                        style: AppTextStyles.body(fontSize: 14).copyWith(
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final recipient = SelectedProfile.instance.careRecipient;
    return Row(
      children: [
        const AppBackButton(),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => context.push('/profiles'),
          child: Container(
            width: 38,
            height: 38,
            decoration:
                const BoxDecoration(color: _teal, shape: BoxShape.circle),
            child: Center(
              child: Text(recipient?.initials ?? '?',
                  style: AppTextStyles.bodyMedium(fontSize: 13)
                      .copyWith(color: Colors.white)),
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
                    Text(recipient?.displayName ?? 'Add a profile',
                        style: AppTextStyles.bodyMedium(fontSize: 14)
                            .copyWith(color: Colors.black87)),
                    if (recipient != null)
                      Text(
                        [
                          if (recipient.age != null) '${recipient.age}',
                          if (recipient.preferredLanguages.isNotEmpty)
                            'speaks ${recipient.preferredLanguages.first}',
                        ].join(' · '),
                        style: AppTextStyles.body(fontSize: 11)
                            .copyWith(color: Colors.grey.shade500),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: () => context.push('/activity'),
          icon: Icon(Icons.notifications_none_rounded,
              color: Colors.grey.shade700, size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: Icon(Icons.settings_outlined,
              color: Colors.grey.shade700, size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (i) {
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
      selectedItemColor: const Color(0xFFEF3E23),
      unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle: AppTextStyles.bodyMedium(fontSize: 11),
      unselectedLabelStyle: AppTextStyles.body(fontSize: 11),
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded), label: 'Today'),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Ask'),
        BottomNavigationBarItem(
            icon: Icon(Icons.mic_none_rounded), label: 'Log'),
        BottomNavigationBarItem(
            icon: Icon(Icons.medication_outlined), label: 'Meds'),
        BottomNavigationBarItem(
            icon: Icon(Icons.help_outline_rounded), label: 'Help'),
      ],
    );
  }
}

// ── Schedule card ─────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final _ScheduleEntry entry;
  final ValueChanged<bool> onToggle;

  static const _teal = Color(0xFF2BBFB3);

  const _ScheduleCard({required this.entry, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: entry.iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(entry.icon, color: entry.iconColor, size: 22),
          ),
          const SizedBox(width: 14),

          // Label + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: AppTextStyles.bodyMedium(fontSize: 15)
                      .copyWith(color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.time,
                  style: AppTextStyles.body(fontSize: 12)
                      .copyWith(color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          // Toggle
          Switch(
            value: entry.enabled,
            onChanged: onToggle,
            activeColor: Colors.white,
            activeTrackColor: _teal,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }
}
