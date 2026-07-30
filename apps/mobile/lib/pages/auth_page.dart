import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/family_viewer_service.dart';
import '../state/dev_bypass.dart';
import '../state/selected_profile.dart';
import '../state/session_role.dart';
import '../theme.dart';
import '../widgets/back_button.dart';

enum _AuthMode { register, login }

/// Screen 03 · Sign in / register (`/auth`).
/// Reached from RoleSelectPage's caregiver fork (register or login) or its
/// family login fork. A real (non-anonymous) account is mandatory — every
/// app route redirects back to the welcome flow until one exists (see
/// router.dart); the "Skip (dev)" button is a debug-build-only escape
/// hatch. [asFamilyMember] only affects the login branch's post-success
/// routing — a fresh family sign-up goes through
/// FamilyCodePage/FamilyRegisterPage instead, never this screen's register.
class AuthPage extends StatefulWidget {
  final bool startInLoginMode;
  final bool asFamilyMember;

  const AuthPage({super.key, this.startInLoginMode = false, this.asFamilyMember = false});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static const _bg = Color(0xFFFFFFFF);
  static const _red = Color(0xFFEF3E23);

  final _familyViewerService = const FamilyViewerService();

  late _AuthMode _mode;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mode = widget.startInLoginMode ? _AuthMode.login : _AuthMode.register;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isRegister = _mode == _AuthMode.register;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty || (isRegister && name.isEmpty)) {
      setState(() => _error = 'Fill in every field.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      if (isRegister) {
        final anonymousUser = auth.currentUser;
        final emailCredential = EmailAuthProvider.credential(email: email, password: password);

        // The language screen is the very first thing anyone sees, before
        // any sign-in — so by the time a caregiver reaches this screen
        // she's almost always already anonymous, likely with real logs
        // already saved under that UID. Link the email/password credential
        // onto the existing anonymous account instead of creating a new
        // one: same UID before and after, so the household/data it already
        // bootstrapped (see main.dart) stays reachable rather than being
        // orphaned under a UID nobody will ever authenticate as again.
        final credential = anonymousUser != null && anonymousUser.isAnonymous
            ? await anonymousUser.linkWithCredential(emailCredential)
            : await auth.createUserWithEmailAndPassword(email: email, password: password);
        await credential.user?.updateDisplayName(name);
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
      if (!mounted) return;

      // Family members have no household of their own — running
      // SelectedProfile.initialize() here would POST /households/bootstrap
      // and create a spurious caregiver household under their UID. Their
      // viewer resolution goes through FamilyViewerService instead.
      if (!isRegister && widget.asFamilyMember) {
        await _routeFamilyMemberAfterLogin();
        return;
      }

      // Caregiver path. Login (or the no-anonymous-session register
      // fallback above) lands on a different UID than whatever was active
      // before — re-run bootstrap for it, or every household-scoped call
      // 403s until the app restarts. A no-op re-sync when linking kept the
      // same UID.
      await SessionRole.instance.set(SessionRole.caregiver);
      await SelectedProfile.instance.initialize();
      if (!mounted) return;
      // Not '/home' directly: a brand-new account still needs onboarding
      // (/language, /patient). A returning caregiver with an existing
      // profile gets auto-redirected straight to /home from there anyway
      // (see router.dart's SelectedProfile-based bypass).
      context.go('/language');
    } on FirebaseAuthException catch (e) {
      final message = e.code == 'credential-already-in-use' || e.code == 'email-already-in-use'
          ? 'That email is already registered — try signing in instead.'
          : e.message ?? 'Something went wrong. Try again.';
      setState(() => _error = message);
    } catch (_) {
      setState(() => _error = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // Debug-build-only escape hatch (see class doc comment). '/language',
  // not '/home' — same reasoning as the real-account path in _submit().
  void _skipDev() {
    DevBypass.instance.skip();
    context.go('/language');
  }

  Future<void> _routeFamilyMemberAfterLogin() async {
    try {
      final recipients = await _familyViewerService.resolveViewableRecipients();
      // Persist the surface even for the zero-recipient case — this account
      // signed in through the family fork, and restarting the app must not
      // route it through the caregiver bootstrap path.
      await SessionRole.instance.set(SessionRole.family);
      if (!mounted) return;

      if (recipients.isEmpty) {
        setState(() {
          _error = 'We couldn\'t find any records linked to this account yet. '
              'If a caregiver shared a code with you, use that instead.';
        });
        return;
      }
      if (recipients.length == 1) {
        context.go('/viewer/${recipients.first.careRecipient.id}');
        return;
      }
      context.go('/family-recipients', extra: recipients);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Signed in, but couldn\'t load your family records. Check your connection and try again, '
            'or use a code from the caregiver instead.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _mode == _AuthMode.register;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // ── Back ──────────────────────────────────────────────────
              const Align(alignment: Alignment.centerLeft, child: AppBackButton()),

              const SizedBox(height: 20),

              // ── Logo ──────────────────────────────────────────────────
              Image.asset('assets/branding/kalinga-logo-app.png', width: 56, height: 56),

              const SizedBox(height: 20),

              Text(
                isRegister ? 'Create your account' : 'Welcome back',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading(fontSize: 30).copyWith(color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                isRegister
                    ? 'So the family you care for can see your reports. Takes less than a minute.'
                    : 'Sign in to keep sending your logs to the\nfamily you already invited.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600, height: 1.5),
              ),

              const SizedBox(height: 24),

              // ── Mode toggle ───────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: _ModePill(
                    label: 'New here',
                    selected: isRegister,
                    onTap: () => setState(() => _mode = _AuthMode.register),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModePill(
                    label: 'I have an account',
                    selected: !isRegister,
                    onTap: () => setState(() => _mode = _AuthMode.login),
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              if (isRegister) ...[
                _FieldLabel('Your name'),
                const SizedBox(height: 8),
                _AuthField(controller: _nameController, hint: 'Siti'),
                const SizedBox(height: 16),
              ],

              _FieldLabel('Email'),
              const SizedBox(height: 8),
              _AuthField(
                controller: _emailController,
                hint: 'siti@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              _FieldLabel('Password'),
              const SizedBox(height: 8),
              _AuthField(controller: _passwordController, hint: '••••••••', obscureText: true),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isRegister ? 'Save this somewhere safe — we can\'t reset it for you.' : 'At least 6 characters.',
                  style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500),
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
              if (_error != null && widget.asFamilyMember) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => context.push('/family-code'),
                  child: Text(
                    'Use a code instead',
                    style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(
                      color: Colors.black87,
                      decoration: TextDecoration.underline,
                    ),
                  ),
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
                      : Text(
                          isRegister ? 'Create account' : 'Sign in',
                          style: AppTextStyles.bodyMedium(fontSize: 17).copyWith(color: Colors.white),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              if (kDebugMode) ...[
                GestureDetector(
                  onTap: _submitting ? null : _skipDev,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade300),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Skip (dev)',
                      style: AppTextStyles.bodyMedium(fontSize: 13).copyWith(color: Colors.orange.shade800),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Debug build only — real builds require an account.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(fontSize: 11).copyWith(color: Colors.orange.shade700),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _ModePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModePill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.black87 : Colors.white,
          border: Border.all(color: selected ? Colors.black87 : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: selected ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
    );
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _AuthField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: AppTextStyles.body(fontSize: 15).copyWith(color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body(fontSize: 15).copyWith(color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2BBFB3), width: 1.5)),
      ),
    );
  }
}
