import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/profile_service.dart';
import '../state/selected_profile.dart';
import '../theme.dart';

/// "Who do you care for?" picker — Feature 5. Lists every profile in the
/// caregiver's household, lets her switch which one every subsequent log,
/// alert, and med-reminder is scoped to (SelectedProfile.instance).
class ProfilePickerPage extends StatelessWidget {
  const ProfilePickerPage({super.key});

  static const _bg = Color(0xFFF5F0E8);
  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text('Who are you caring for?', style: AppTextStyles.bodyMedium(fontSize: 17).copyWith(color: Colors.black)),
      ),
      body: ListenableBuilder(
        listenable: SelectedProfile.instance,
        builder: (context, _) {
          final state = SelectedProfile.instance;

          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load profiles: ${state.error}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(fontSize: 14).copyWith(color: _red),
                ),
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Expanded(
                    child: state.careRecipients.isEmpty
                        ? Center(
                            child: Text(
                              'No profiles yet.',
                              style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.separated(
                            itemCount: state.careRecipients.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final recipient = state.careRecipients[i];
                              final selected = recipient.id == state.careRecipient?.id;
                              return _ProfileTile(
                                recipient: recipient,
                                selected: selected,
                                onTap: () async {
                                  await state.select(recipient);
                                  if (context.mounted) context.pop();
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/patient'),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Add another profile', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.black87, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final CareRecipient recipient;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileTile({required this.recipient, required this.selected, required this.onTap});

  static const _teal = Color(0xFF2BBFB3);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _teal.withValues(alpha: 0.1) : Colors.white,
          border: Border.all(color: selected ? _teal : Colors.grey.shade300, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
            child: Center(child: Text(recipient.initials, style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.white))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipient.displayName, style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
                if (recipient.age != null || recipient.conditions.isNotEmpty)
                  Text(
                    [
                      if (recipient.age != null) '${recipient.age}',
                      if (recipient.conditions.isNotEmpty) recipient.conditions.join(', '),
                    ].join(' · '),
                    style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          if (selected) const Icon(Icons.check_circle, color: _teal, size: 22),
        ]),
      ),
    );
  }
}
