import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/family_viewer_service.dart';
import '../services/profile_service.dart';
import '../theme.dart';
import '../widgets/back_button.dart';

/// Screen — family recipient picker (`/family-recipients`). Only reached
/// when a family login resolves to 2+ viewable care recipients (expected
/// rare — most family accounts are linked to one). Receives the already-
/// resolved list via go_router's `extra`; purely renders it, no network
/// calls of its own. Family-facing only, so bilingual throughout.
class FamilyRecipientsPage extends StatelessWidget {
  final List<ViewableCareRecipient> recipients;
  const FamilyRecipientsPage({super.key, required this.recipients});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              const Align(alignment: Alignment.centerLeft, child: AppBackButton()),

              const SizedBox(height: 24),

              Text(
                '選擇要查看的對象',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading(fontSize: 26).copyWith(color: Colors.black),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose who to view',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600),
              ),

              const SizedBox(height: 28),

              Expanded(
                child: ListView.separated(
                  itemCount: recipients.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final r = recipients[i];
                    return _FamilyRecipientTile(
                      recipient: r.careRecipient,
                      onTap: () => context.go('/viewer/${r.careRecipient.id}'),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyRecipientTile extends StatelessWidget {
  final CareRecipient recipient;
  final VoidCallback onTap;
  const _FamilyRecipientTile({required this.recipient, required this.onTap});

  static const _teal = Color(0xFF2BBFB3);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  recipient.initials,
                  style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                recipient.displayName,
                style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
