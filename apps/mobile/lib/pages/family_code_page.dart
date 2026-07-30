import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/invite_service.dart';
import '../theme.dart';
import '../widgets/back_button.dart';

/// Screen — family sign-up via shared code (`/family-code`). Reached from
/// RoleSelectPage. Validates the caregiver-shared code by calling the
/// existing InviteService.fetchInvite before navigating; on success hands
/// off to the existing, unchanged FamilyRegisterPage at /invite/:token
/// (which re-fetches the invite itself — an accepted, deliberate duplicate
/// network call in exchange for zero changes to FamilyRegisterPage). On
/// failure, shows an inline error here instead of navigating, so the user
/// doesn't land on FamilyRegisterPage's own dead-end "invalid invite" state.
class FamilyCodePage extends StatefulWidget {
  const FamilyCodePage({super.key});

  @override
  State<FamilyCodePage> createState() => _FamilyCodePageState();
}

class _FamilyCodePageState extends State<FamilyCodePage> {
  static const _bg = Color(0xFFFFFFFF);
  static const _red = Color(0xFFEF3E23);

  final _inviteService = InviteService();
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // The backend always generates lowercase hex tokens and resolves them
    // via an exact-match Firestore doc-id lookup — normalize defensively
    // in case a keyboard auto-capitalized the first character or the user
    // pasted with stray whitespace.
    final code = _codeController.text.trim().toLowerCase();

    if (code.isEmpty) {
      setState(() => _error = '請輸入照顧者提供給您的代碼 · Enter the code the caregiver shared with you.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _inviteService.fetchInvite(code);
      if (!mounted) return;
      context.push('/invite/$code');
    } catch (_) {
      setState(() => _error = '此代碼無效或已過期，請向照顧者確認 · That code isn\'t valid or has expired. Double-check it with the caregiver.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              const Align(alignment: Alignment.centerLeft, child: AppBackButton()),

              const SizedBox(height: 20),

              Image.asset('assets/branding/kalinga-logo-app.png', width: 56, height: 56),

              const SizedBox(height: 20),

              Text(
                '輸入代碼',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading(fontSize: 26).copyWith(color: Colors.black),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter your code',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Text(
                '向照顧者索取他們在應用程式中建立的代碼，然後在下方輸入。',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Ask the caregiver for the code they created for you\nin the app, then type it below.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade500, height: 1.5),
              ),

              const SizedBox(height: 32),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('代碼 · Code', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                style: AppTextStyles.body(fontSize: 15).copyWith(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'e.g. 4f9c2a...',
                  hintStyle: AppTextStyles.body(fontSize: 15).copyWith(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2BBFB3), width: 1.5)),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(fontSize: 13).copyWith(color: _red),
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _red.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text('繼續 · Continue', style: AppTextStyles.bodyMedium(fontSize: 17).copyWith(color: Colors.white)),
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
