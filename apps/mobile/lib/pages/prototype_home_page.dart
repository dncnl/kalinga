import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

// ── Data models ───────────────────────────────────────────────────────────────

enum _ScheduleStatus { logged, watch, neutral }

class _ScheduleItem {
  final _ScheduleStatus status;
  final String time;
  final String? title;
  final String? subtitle;

  const _ScheduleItem({
    required this.status,
    required this.time,
    this.title,
    this.subtitle,
  });
}

const _scheduleItems = [
  _ScheduleItem(
    status: _ScheduleStatus.logged,
    time: '08:00',
    title: 'Breakfast',
    subtitle: 'Ate half. Logged by you.',
  ),
  _ScheduleItem(
    status: _ScheduleStatus.watch,
    time: '10:00',
    title: 'Morning walk',
    subtitle: 'Check-in waiting for you.',
  ),
  _ScheduleItem(
    status: _ScheduleStatus.neutral,
    time: '21:00',
  ),
];

// ── Page ──────────────────────────────────────────────────────────────────────

class PrototypeHomePage extends StatefulWidget {
  const PrototypeHomePage({super.key});

  @override
  State<PrototypeHomePage> createState() => _PrototypeHomePageState();
}

class _PrototypeHomePageState extends State<PrototypeHomePage> {
  static const _bg = Color(0xFFF5F0E8);
  static const _red = Color(0xFFEF3E23);
  static const _teal = Color(0xFF2BBFB3);

  int _navIndex = 0;

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
              const SizedBox(height: 20),
              _buildGreetingCard(),
              const SizedBox(height: 16),
              _buildStartLogButton(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildScheduleSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // Avatar
        GestureDetector(
          onTap: () => context.push('/patients/lola-rosa'),
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFF2BBFB3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'LR',
                style: AppTextStyles.bodyMedium(fontSize: 13).copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Name + details
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/patients/lola-rosa'),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lola Rosa',
                      style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '82 · speaks Hokkien',
                      style: AppTextStyles.body(fontSize: 11).copyWith(
                        color: Colors.grey.shade500,
                      ),
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
        // Icons
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

  // ── Greeting card ──────────────────────────────────────────────────────────

  Widget _buildGreetingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3C4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Decorative blob
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
                'SATURDAY, 14 JUNE',
                style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Good morning, Siti',
                style: AppTextStyles.heading(fontSize: 26).copyWith(
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "You haven't logged Lola Rosa\nyet today.",
                style: AppTextStyles.body(fontSize: 14).copyWith(
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
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
          style: AppTextStyles.bodyMedium(fontSize: 17).copyWith(
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEF3E23),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // ── Quick actions ──────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    const actions = [
      _QuickAction(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Ask',
        bg: Color(0xFFFFD5CF),
        iconColor: Color(0xFFEF3E23),
        route: '/ask',
      ),
      _QuickAction(
        icon: Icons.medication_outlined,
        label: 'Meds',
        bg: Color(0xFFD0EFFE),
        iconColor: Color(0xFF2BBFB3),
        badge: '2',
        route: '/meds',
      ),
      _QuickAction(
        icon: Icons.schedule_rounded,
        label: 'Schedules',
        bg: Color(0xFFFFF3C4),
        iconColor: Color(0xFFD97706),
        route: '/patients/lola-rosa/schedules',
      ),
      _QuickAction(
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
          style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(
            color: Colors.grey.shade500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: actions
              .map((a) => _QuickActionTile(action: a))
              .toList(),
        ),
      ],
    );
  }

  // ── Schedule section ───────────────────────────────────────────────────────

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "TODAY'S SCHEDULE",
          style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(
            color: Colors.grey.shade500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          _scheduleItems.length,
          (i) => _ScheduleTile(
            item: _scheduleItems[i],
            isLast: i == _scheduleItems.length - 1,
          ),
        ),
      ],
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    const items = [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_rounded),
        label: 'Today',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.chat_bubble_outline_rounded),
        label: 'Ask',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.mic_none_rounded),
        label: 'Log',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.medication_outlined),
        label: 'Meds',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.help_outline_rounded),
        label: 'Help',
      ),
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
      selectedItemColor: const Color(0xFFEF3E23),
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
                decoration: BoxDecoration(
                  color: action.bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(action.icon, color: action.iconColor, size: 26),
              ),
              if (action.badge != null)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF3E23),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        action.badge!,
                        style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            action.label,
            style: AppTextStyles.body(fontSize: 12).copyWith(
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Schedule tile ─────────────────────────────────────────────────────────────

class _ScheduleTile extends StatelessWidget {
  final _ScheduleItem item;
  final bool isLast;

  const _ScheduleTile({required this.item, required this.isLast});

  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);

  Color get _badgeColor {
    return switch (item.status) {
      _ScheduleStatus.logged => _teal,
      _ScheduleStatus.watch => const Color(0xFFD97706),
      _ScheduleStatus.neutral => Colors.grey,
    };
  }

  String get _badgeLabel {
    return switch (item.status) {
      _ScheduleStatus.logged => 'LOGGED',
      _ScheduleStatus.watch => 'WATCH',
      _ScheduleStatus.neutral => 'NEUTRAL',
    };
  }

  bool get _isDone => item.status == _ScheduleStatus.logged;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline column ──────────────────────────────────────────
          SizedBox(
            width: 28,
            child: Column(
              children: [
                // Dot
                _isDone
                    ? Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: _red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      )
                    : Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                      ),
                // Line
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

          // ── Content ──────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge + time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _badgeLabel,
                          style: AppTextStyles.bodyMedium(fontSize: 10)
                              .copyWith(color: _badgeColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.time,
                        style: AppTextStyles.body(fontSize: 13).copyWith(
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),

                  // Card (only if title present)
                  if (item.title != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => context.push('/checkin/1'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title!,
                              style: AppTextStyles.bodyMedium(fontSize: 14)
                                  .copyWith(color: Colors.black87),
                            ),
                            if (item.subtitle != null) ...[
                              const SizedBox(height: 2),
                              _StyledSubtitle(item.subtitle!),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Renders the subtitle with the bold + colored last sentence pattern
class _StyledSubtitle extends StatelessWidget {
  final String text;
  const _StyledSubtitle(this.text);

  @override
  Widget build(BuildContext context) {
    // Split at last period+space to bold the last part
    final parts = text.split('. ');
    if (parts.length < 2) {
      return Text(
        text,
        style: AppTextStyles.body(fontSize: 13).copyWith(
          color: Colors.grey.shade500,
        ),
      );
    }
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${parts[0]}. ',
            style: AppTextStyles.body(fontSize: 13).copyWith(
              color: Colors.grey.shade500,
            ),
          ),
          TextSpan(
            text: parts.sublist(1).join('. '),
            style: AppTextStyles.bodyMedium(fontSize: 13).copyWith(
              color: const Color(0xFF2BBFB3),
            ),
          ),
        ],
      ),
    );
  }
}
