import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

enum _AuthMode { register, login }

/// Screen 03 · Sign in / register (`/auth`).
/// Optional — reachable from Settings. Uses Firebase Auth email+password
/// directly from the client; the app runs unauthenticated until then.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static const _bg = Color(0xFFF5F0E8);
  static const _red = Color(0xFFEF3E23);

  _AuthMode _mode = _AuthMode.register;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

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
        final credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await credential.user?.updateDisplayName(name);
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
      if (!mounted) return;
      context.go('/home');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Something went wrong. Try again.');
    } catch (_) {
      setState(() => _error = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _skip() => context.canPop() ? context.pop() : context.go('/home');

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
              const SizedBox(height: 32),

              // ── Logo ──────────────────────────────────────────────────
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Text('K', style: AppTextStyles.heading(fontSize: 28).copyWith(color: _red)),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                isRegister ? 'Create your account' : 'Welcome back',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading(fontSize: 30).copyWith(color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                isRegister
                    ? 'Only needed to link the family. Two fields\nand a password.'
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
                  isRegister ? 'Write it somewhere safe. We cannot see it.' : 'At least 6 characters.',
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

              GestureDetector(
                onTap: _submitting ? null : _skip,
                child: Text(
                  'Skip for now',
                  style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'You can use Kalinga without an account. Sign in only\nwhen you want the family to read your logs.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500, height: 1.5),
              ),

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
