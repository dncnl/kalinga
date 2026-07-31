import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/profile_service.dart';
import '../state/selected_profile.dart';
import '../theme.dart';
import '../widgets/back_button.dart';
import '../widgets/must_remember_section.dart';
import 'invite_sheet.dart';

/// Shows the currently *selected* profile (SelectedProfile.instance) — the
/// [patientId] route param is kept for URL shape compatibility but not used
/// to look up a different profile. Navigating here always means "show me
/// details for whoever I currently have selected"; switching who's selected
/// happens on the profile picker (/profiles), not here.
class PrototypePatientDetailPage extends StatelessWidget {
  final String patientId;
  const PrototypePatientDetailPage({super.key, required this.patientId});

  static const _bg = Color(0xFFFFFFFF);
  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SelectedProfile.instance,
      builder: (context, _) {
        final recipient = SelectedProfile.instance.careRecipient;

        if (recipient == null) {
          return Scaffold(
            backgroundColor: _bg,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No profile selected.',
                  style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildHeader(context, recipient),
                  const SizedBox(height: 24),
                  _buildProfileBlock(recipient),
                  const SizedBox(height: 20),
                  _buildConditions(recipient),
                  const SizedBox(height: 24),
                  MustRememberSection(recipient: recipient),
                  const SizedBox(height: 24),
                  InsightsSection(careRecipientId: recipient.id),
                  const SizedBox(height: 20),
                  _buildMenuRows(context, recipient),
                  const SizedBox(height: 20),
                  _buildEditButton(context, recipient),
                  const SizedBox(height: 10),
                  _buildDeleteButton(context, recipient),
                  const SizedBox(height: 12),
                  _buildPreviewLink(context, recipient),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _buildBottomNav(context),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, CareRecipient recipient) {
    return Row(
      children: [
        const AppBackButton(),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => context.push('/profiles'),
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
            child: Center(
              child: Text(recipient.initials,
                  style: AppTextStyles.bodyMedium(fontSize: 13).copyWith(color: Colors.white)),
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
                    Text(recipient.displayName,
                        style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87)),
                    if (recipient.age != null || recipient.preferredLanguages.isNotEmpty)
                      Text(
                        [
                          if (recipient.age != null) '${recipient.age}',
                          if (recipient.preferredLanguages.isNotEmpty)
                            'speaks ${recipient.preferredLanguages.first}',
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
  }

  Widget _buildProfileBlock(CareRecipient recipient) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
          child: Center(
            child: Text(recipient.initials,
                style: AppTextStyles.bodyMedium(fontSize: 22).copyWith(color: Colors.white)),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recipient.displayName, style: AppTextStyles.heading(fontSize: 26).copyWith(color: Colors.black)),
            Text(
              [
                if (recipient.age != null) '${recipient.age}',
                if (recipient.preferredLanguages.isNotEmpty) recipient.preferredLanguages.first,
              ].join(' · '),
              style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConditions(CareRecipient recipient) {
    if (recipient.conditions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONDITIONS',
            style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(color: Colors.grey.shade500, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: recipient.conditions
              .map((c) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Text(c, style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.black87)),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMenuRows(BuildContext context, CareRecipient recipient) {
    final rows = [
      _MenuRow(
        icon: Icons.medication_outlined,
        label: 'Medications',
        trailing: '',
        onTap: () => context.push('/meds'),
      ),
      _MenuRow(
        icon: Icons.schedule_rounded,
        label: 'Schedules',
        trailing: '',
        onTap: () => context.push('/patients/${recipient.id}/schedules'),
      ),
      _MenuRow(
        icon: Icons.remove_red_eye_outlined,
        label: 'Linked viewers',
        trailing: '',
        trailingColor: Colors.grey.shade400,
        onTap: () => context.push('/viewer/${recipient.id}'),
      ),
      _MenuRow(
        icon: Icons.person_add_alt_outlined,
        label: 'Invite family or caregiver',
        trailing: '',
        onTap: () => showInviteSheet(context, recipient: recipient),
      ),
    ];

    return Column(
      children: rows
          .map(
            (row) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                onTap: row.onTap,
                leading: Icon(row.icon, color: Colors.grey.shade600, size: 22),
                title: Text(row.label, style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
                trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildEditButton(BuildContext context, CareRecipient recipient) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => context.push('/patient/edit', extra: recipient),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text('Edit profile', style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.black87)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.black87, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context, CareRecipient recipient) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmDelete(context, recipient),
        icon: const Icon(Icons.delete_outline, size: 18, color: _red),
        label: Text('Delete profile', style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: _red)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _red,
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: _red, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, CareRecipient recipient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete profile?'),
        content: Text('This removes ${recipient.displayName} from your active profiles. Their history is kept, not erased.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await SelectedProfile.instance.deleteSelected();
      if (context.mounted) context.go('/home');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  Widget _buildPreviewLink(BuildContext context, CareRecipient recipient) {
    return Center(
      child: GestureDetector(
        onTap: () => context.push('/viewer/${recipient.id}'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.black87),
            const SizedBox(width: 8),
            Text('Preview what family sees',
                style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87)),
          ],
        ),
      ),
    );
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
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: _red,
      unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle: AppTextStyles.bodyMedium(fontSize: 11),
      unselectedLabelStyle: AppTextStyles.body(fontSize: 11),
      elevation: 8,
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

class _MenuRow {
  final IconData icon;
  final String label;
  final String trailing;
  final Color? trailingColor;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.onTap,
    this.trailingColor,
  });
}
