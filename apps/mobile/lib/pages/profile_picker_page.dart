import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/profile_service.dart';
import '../state/selected_profile.dart';
import '../theme.dart';

/// "Who do you care for?" picker — Feature 5. Lists every profile in the
/// caregiver's household, lets her switch which one every subsequent log,
/// alert, and med-reminder is scoped to (SelectedProfile.instance).
///
/// Also shows a household switcher when the caregiver belongs to more than
/// one (e.g. she accepted someone else's invite) — most caregivers only
/// ever have the one auto-created household, so this section only appears
/// when it's actually relevant.
class ProfilePickerPage extends StatefulWidget {
  const ProfilePickerPage({super.key});

  @override
  State<ProfilePickerPage> createState() => _ProfilePickerPageState();
}

class _ProfilePickerPageState extends State<ProfilePickerPage> {
  static const _bg = Color(0xFFF5F0E8);
  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);

  final _profileService = const ProfileService();
  List<HouseholdSummary> _households = [];
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _loadHouseholds();
  }

  Future<void> _loadHouseholds() async {
    try {
      final households = await _profileService.listMyHouseholds();
      if (mounted) setState(() => _households = households);
    } catch (_) {
      // Household switcher is a nice-to-have — if this fails, just don't
      // show it rather than blocking the whole profile picker.
    }
  }

  Future<void> _switchTo(String householdId) async {
    setState(() => _switching = true);
    try {
      await SelectedProfile.instance.switchHousehold(householdId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not switch: $e')));
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

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
                  if (_households.length > 1) ...[
                    Text('HOUSEHOLD', style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(color: Colors.grey.shade500, letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _households.map((h) {
                        final active = h.id == state.householdId;
                        return GestureDetector(
                          onTap: _switching || active ? null : () => _switchTo(h.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: active ? Colors.black87 : Colors.white,
                              border: Border.all(color: active ? Colors.black87 : Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Text(h.name, style: AppTextStyles.body(fontSize: 13).copyWith(color: active ? Colors.white : Colors.black87)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
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
          const SizedBox(width: 4),
          IconButton(
            onPressed: () async {
              // Detail/schedule pages read SelectedProfile.instance rather
              // than their own patientId route param (see
              // PrototypePatientDetailPage's doc comment) — this button was
              // navigating straight to /patients/:id without selecting
              // [recipient] first, so tapping "view details" on anyone
              // other than the already-selected profile showed the WRONG
              // patient's name/schedule. Select first, then navigate.
              await SelectedProfile.instance.select(recipient);
              if (context.mounted) context.push('/patients/${recipient.id}');
            },
            icon: Icon(Icons.info_outline_rounded, color: Colors.grey.shade400, size: 20),
            tooltip: 'View details',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
      ),
    );
  }
}
