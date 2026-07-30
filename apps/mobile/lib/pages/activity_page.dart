import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../state/selected_profile.dart';
import '../theme.dart';

enum _ActivityStatus { resolved, urgent, logged, watch }

class _ActivityItem {
  final _ActivityStatus status;
  final String time;
  final String title;
  final String body;
  const _ActivityItem({required this.status, required this.time, required this.title, required this.body});
}

const _items = [
  _ActivityItem(status: _ActivityStatus.resolved, time: 'Today 10:20', title: 'Family replied',
      body: 'Thank you. We will bring her to the clinic on Monday.'),
  _ActivityItem(status: _ActivityStatus.urgent, time: 'Today 10:14', title: 'Alert sent',
      body: 'Chest pain and hard to breathe. Sent in Mandarin to family and clinic.'),
  _ActivityItem(status: _ActivityStatus.logged, time: 'Today 08:05', title: 'Breakfast logged',
      body: 'Ate half of her meal.'),
  _ActivityItem(status: _ActivityStatus.watch, time: 'Yesterday 22:10', title: 'Sleep dropped',
      body: 'Under 6 hours for three nights.'),
];

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});
  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  static const _bg = Color(0xFFF5F0E8);
  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            _buildHeader(context),
            const SizedBox(height: 28),
            Text("${SelectedProfile.instance.careRecipient?.displayName ?? 'Their'}'s history", style: AppTextStyles.heading(fontSize: 28).copyWith(color: Colors.black)),
            const SizedBox(height: 8),
            Text('Everything you logged, and what the family saw.',
                style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600, height: 1.5)),
            const SizedBox(height: 20),
            // Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(32)),
              child: Row(children: ['All', 'Alerts', 'Logs'].asMap().entries.map((e) {
                final selected = e.key == _tab;
                return Expanded(child: GestureDetector(
                  onTap: () => setState(() => _tab = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Center(child: Text(e.value,
                        style: (selected ? AppTextStyles.bodyMedium(fontSize: 13) : AppTextStyles.body(fontSize: 13))
                            .copyWith(color: selected ? Colors.black87 : Colors.grey.shade500))),
                  ),
                ));
              }).toList()),
            ),
            const SizedBox(height: 24),
            // Timeline
            ..._items.asMap().entries.map((e) => _ActivityTile(item: e.value, isLast: e.key == _items.length - 1)),
            const SizedBox(height: 24),
          ]),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final recipient = SelectedProfile.instance.careRecipient;
    return Row(children: [
      GestureDetector(
        onTap: () => context.push('/profiles'),
        child: Container(width: 38, height: 38,
          decoration: const BoxDecoration(color: Color(0xFF2BBFB3), shape: BoxShape.circle),
          child: Center(child: Text(recipient?.initials ?? '?', style: AppTextStyles.bodyMedium(fontSize: 13).copyWith(color: Colors.white)))),
      ),
      const SizedBox(width: 10),
      Expanded(child: GestureDetector(
        onTap: () => context.push('/profiles'),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(recipient?.displayName ?? 'Add a profile', style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87)),
            if (recipient != null)
              Text(
                [
                  if (recipient.age != null) '${recipient.age}',
                  if (recipient.preferredLanguages.isNotEmpty) 'speaks ${recipient.preferredLanguages.first}',
                ].join(' · '),
                style: AppTextStyles.body(fontSize: 11).copyWith(color: Colors.grey.shade500),
              ),
          ]),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey.shade500),
        ]),
      )),
      IconButton(onPressed: () => context.push('/activity'), icon: Icon(Icons.notifications_none_rounded, color: Colors.grey.shade700, size: 24), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      const SizedBox(width: 16),
      IconButton(onPressed: () => context.push('/settings'), icon: Icon(Icons.settings_outlined, color: Colors.grey.shade700, size: 24), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
    ]);
  }

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
      type: BottomNavigationBarType.fixed, backgroundColor: Colors.white,
      selectedItemColor: _red, unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle: AppTextStyles.bodyMedium(fontSize: 11),
      unselectedLabelStyle: AppTextStyles.body(fontSize: 11), elevation: 8,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Today'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Ask'),
        BottomNavigationBarItem(icon: Icon(Icons.mic_none_rounded), label: 'Log'),
        BottomNavigationBarItem(icon: Icon(Icons.medication_outlined), label: 'Meds'),
        BottomNavigationBarItem(icon: Icon(Icons.help_outline_rounded), label: 'Help'),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final _ActivityItem item;
  final bool isLast;
  const _ActivityTile({required this.item, required this.isLast});

  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);

  Color get _badgeColor => switch (item.status) {
    _ActivityStatus.resolved => _teal,
    _ActivityStatus.urgent   => const Color(0xFFEF4444),
    _ActivityStatus.logged   => _teal,
    _ActivityStatus.watch    => const Color(0xFFD97706),
  };

  String get _badgeLabel => switch (item.status) {
    _ActivityStatus.resolved => 'RESOLVED',
    _ActivityStatus.urgent   => 'URGENT',
    _ActivityStatus.logged   => 'LOGGED',
    _ActivityStatus.watch    => 'WATCH',
  };

  bool get _isDone => item.status == _ActivityStatus.resolved;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 28, child: Column(children: [
        _isDone
            ? Container(width: 24, height: 24,
                decoration: const BoxDecoration(color: _red, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14))
            : Container(width: 24, height: 24,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 1.5))),
        if (!isLast) Expanded(child: Container(width: 1.5, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(vertical: 4))),
      ])),
      const SizedBox(width: 12),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _badgeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(_badgeLabel, style: AppTextStyles.bodyMedium(fontSize: 10).copyWith(color: _badgeColor)),
            ),
            const SizedBox(width: 8),
            Text(item.time, style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500)),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87)),
              const SizedBox(height: 2),
              Text(item.body, style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade600, height: 1.4)),
            ]),
          ),
        ]),
      )),
    ]));
  }
}
