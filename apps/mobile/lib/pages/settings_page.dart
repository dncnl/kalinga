import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../state/selected_profile.dart';
import '../theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _bg = Color(0xFFF5F0E8);
  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);

  String _language = 'Tagalog';
  String _familyLanguage = 'Mandarin (Traditional)';
  bool _checkinReminders = true;
  bool _shareWeeklyTrends = true;
  bool _workOffline = true;
  bool _biggerText = false;

  static const _languages = ['Tagalog', 'Bisaya', 'Bahasa Indonesia', 'Vietnamese'];
  static const _familyLanguages = ['Mandarin (Traditional)', 'Mandarin (Simplified)', 'English'];

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
            Text('Settings', style: AppTextStyles.heading(fontSize: 32).copyWith(color: Colors.black)),
            const SizedBox(height: 24),

            // Your language
            Text('Your language', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
            const SizedBox(height: 8),
            _buildDropdown(_language, _languages, (v) => setState(() => _language = v!)),
            const SizedBox(height: 6),
            Text('Everything you read and speak uses this.',
                style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500)),
            const SizedBox(height: 20),

            // Family reads
            Text('Family reads', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
            const SizedBox(height: 8),
            _buildDropdown(_familyLanguage, _familyLanguages, (v) => setState(() => _familyLanguage = v!)),
            const SizedBox(height: 24),

            // Account
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                onTap: () => context.push('/auth'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.person_outline_rounded, color: Colors.grey.shade600, size: 22),
                title: Text('Sign in / create account', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
                subtitle: Text('Only needed to invite a family viewer.', style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500)),
                trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
              ),
            ),
            const SizedBox(height: 24),

            // Toggles
            _buildToggle(
              title: 'Check-in reminders',
              subtitle: 'A gentle buzz at each scheduled time.',
              value: _checkinReminders,
              onChanged: (v) => setState(() => _checkinReminders = v),
            ),
            const SizedBox(height: 10),
            _buildToggle(
              title: 'Share weekly trends',
              subtitle: 'Sleep, food and mood only.',
              value: _shareWeeklyTrends,
              onChanged: (v) => setState(() => _shareWeeklyTrends = v),
            ),
            const SizedBox(height: 10),
            _buildToggle(
              title: 'Work without signal',
              subtitle: 'Logs are kept and sent later.',
              value: _workOffline,
              onChanged: (v) => setState(() => _workOffline = v),
            ),
            const SizedBox(height: 10),
            _buildToggle(
              title: 'Bigger text',
              subtitle: 'For reading in bright daylight.',
              subtitleColor: _teal,
              value: _biggerText,
              onChanged: (v) => setState(() => _biggerText = v),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildDropdown(String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
          style: AppTextStyles.body(fontSize: 15).copyWith(color: Colors.black87),
          items: items.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTextStyles.body(fontSize: 12).copyWith(color: subtitleColor ?? Colors.grey.shade500)),
        ])),
        Switch(
          value: value, onChanged: onChanged,
          activeColor: Colors.white, activeTrackColor: _teal,
          inactiveThumbColor: Colors.white, inactiveTrackColor: Colors.grey.shade300,
        ),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final recipient = SelectedProfile.instance.careRecipient;
    return Row(children: [
      GestureDetector(
        onTap: () => context.push('/profiles'),
        child: Container(width: 38, height: 38,
          decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
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
