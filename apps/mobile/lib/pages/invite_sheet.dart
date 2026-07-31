import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/invite_service.dart';
import '../services/profile_service.dart';
import '../state/selected_profile.dart';
import '../theme.dart';

/// No email-sending infrastructure exists (see PLAN.md) — this generates a
/// token via apps/api and shows it as a copyable code for the caregiver to
/// share manually (message, etc). The family member types this code into
/// the app themselves under "I'm a family member" (`FamilyCodePage`,
/// `/family-code`) rather than following a deep link — a working
/// `kalinga://` URL scheme was never registered, so the link-based flow
/// this screen used to describe didn't actually work outside the app.
Future<void> showInviteSheet(BuildContext context, {required CareRecipient recipient}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _InviteSheet(recipient: recipient),
  );
}

class _InviteSheet extends StatefulWidget {
  final CareRecipient recipient;
  const _InviteSheet({required this.recipient});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);

  final _inviteService = InviteService();
  String _role = 'family';
  bool _creating = false;
  String? _error;
  String? _code;

  Future<void> _create() async {
    final householdId = SelectedProfile.instance.householdId;
    if (householdId == null) {
      setState(() => _error = 'No household — try again after the app finishes loading.');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final code = await _inviteService.createInvite(
        householdId: householdId,
        intendedRole: _role,
        careRecipientId: widget.recipient.id,
      );
      setState(() => _code = code);
    } catch (e) {
      setState(() => _error = 'Could not create invite: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invite someone', style: AppTextStyles.heading(fontSize: 24).copyWith(color: Colors.black)),
          const SizedBox(height: 4),
          Text('For ${widget.recipient.displayName}',
              style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600)),
          const SizedBox(height: 20),

          if (_code == null) ...[
            Row(children: [
              Expanded(
                child: _RolePill(
                  label: 'Family (read-only)',
                  selected: _role == 'family',
                  onTap: () => setState(() => _role = 'family'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RolePill(
                  label: 'Caregiver',
                  selected: _role == 'caregiver',
                  onTap: () => setState(() => _role = 'caregiver'),
                ),
              ),
            ]),
            // No email field: the backend mints a pure shared-secret join
            // code (b10bcd9) not tied to any invitee identity — collecting
            // an email here would imply something is sent to it.
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: AppTextStyles.body(fontSize: 13).copyWith(color: _red)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _creating ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _creating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text('Create invite code', style: AppTextStyles.bodyMedium(fontSize: 15)),
              ),
            ),
          ] else ...[
            Text('Share this code:', style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
              child: Text(_code!, style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.black87)),
            ),
            const SizedBox(height: 12),
            Text(
              'Give this code to the family member — they\'ll enter it in the app under "I\'m a family member."',
              style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _code!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text('Copy code', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.black87, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Expires in 7 days.', style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500)),
          ],
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RolePill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.black87 : Colors.white,
          border: Border.all(color: selected ? Colors.black87 : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Center(
          child: Text(label,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium(fontSize: 13).copyWith(color: selected ? Colors.white : Colors.black87)),
        ),
      ),
    );
  }
}
