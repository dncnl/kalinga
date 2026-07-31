import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../state/selected_profile.dart';
import '../state/session_role.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/back_button.dart';
import '../widgets/kalinga_bottom_nav.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _bg = Color(0xFFFFFFFF);
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

  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      // Order matters: clear local state before signing out so no widget
      // rebuild between the two reads a stale household/recipient under the
      // next account. §auth-gate requires a later login as a different
      // account to show none of this one's data.
      await SelectedProfile.instance.reset();
      await SessionRole.instance.clear();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.go('/');
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            Row(
              children: const [
                AppBackButton(),
                SizedBox(width: 10),
                Expanded(child: AppPageHeader()),
              ],
            ),
            const SizedBox(height: 28),
            Text('Settings', style: AppTextStyles.heading(fontSize: 32).copyWith(color: Colors.black)),
            const SizedBox(height: 24),

            // Your language
            Text('Your language', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
            const SizedBox(height: 8),
            _buildDropdown(_language, _languages, (v) => setState(() => _language = v!)),
            const SizedBox(height: 6),
            Text('Everything you read and speak uses this.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
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
                leading: Icon(Icons.person_outline_rounded, color: AppColors.secondaryText, size: 22),
                title: Text('Account', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
                subtitle: Text('Switch accounts or update your details.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
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
            
            // Text size (design-only segmented toggle)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Text size', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
                        const SizedBox(height: 2),
                        Text('For reading in bright daylight.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
                      ],
                    ),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(value: false, label: Text('Default')),
                      ButtonSegment<bool>(value: true, label: Text('Large')),
                    ],
                    selected: {_biggerText},
                    onSelectionChanged: (s) => setState(() => _biggerText = s.first),
                    style: ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sign out
            Semantics(
              label: 'Sign out',
              button: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  onTap: _signingOut ? null : _signOut,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout_rounded, color: _red, size: 22),
                  title: Text('Sign out', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: _red)),
                  subtitle: Text('Your logs stay safe. Sign back in anytime.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
      bottomNavigationBar: const KalingaBottomNav(activeIndex: 0),
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
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: subtitleColor ?? AppColors.mutedText)),
        ])),
        Switch(
          value: value, onChanged: onChanged,
          activeTrackColor: _teal,
          inactiveThumbColor: Colors.white, inactiveTrackColor: Colors.grey.shade300,
        ),
      ]),
    );
  }
}
