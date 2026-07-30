import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/invite_service.dart';
import '../theme.dart';

/// Screen 16 · Family registration (`/invite/:token`).
/// Deep link from the invite email. Only name + password are typed; email
/// comes from the token. On success the family viewer lands on screen 17
/// (`/viewer/:id`), read-only, in zh-TW.
class FamilyRegisterPage extends StatefulWidget {
  final String token;
  const FamilyRegisterPage({super.key, required this.token});

  @override
  State<FamilyRegisterPage> createState() => _FamilyRegisterPageState();
}

class _FamilyRegisterPageState extends State<FamilyRegisterPage> {
  static const _bg = Color(0xFFFFFFFF);
  static const _red = Color(0xFFEF3E23);

  final _inviteService = InviteService();
  late final Future<InviteDetails> _inviteFuture;
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inviteFuture = _inviteService.fetchInvite(widget.token);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(InviteDetails invite) async {
    final name = _nameController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      setState(() => _error = '請輸入您的名字 · Enter your name.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = '密碼至少 6 個字元 · At least 6 characters.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: invite.email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      await _inviteService.acceptInvite(token: widget.token, viewerUid: credential.user!.uid);
      if (!mounted) return;
      context.go('/viewer/${invite.patientId}');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? '發生錯誤，請再試一次 · Something went wrong. Try again.');
    } catch (_) {
      setState(() => _error = '無法建立帳號，請再試一次 · Could not create your account. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: FutureBuilder<InviteDetails>(
          future: _inviteFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _buildInvalidInvite();
            }
            return _buildForm(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildInvalidInvite() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.link_off_rounded, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('This invite link is no longer valid.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Ask the caregiver to send a new one.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade500)),
        ]),
      ),
    );
  }

  Widget _buildForm(InviteDetails invite) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),

          // ── Invite banner ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('FAMILY INVITE · FROM THE EMAIL LINK',
                  style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(color: Colors.grey.shade500, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Text('${invite.inviterName} invited you to read ${invite.patientName}\'s daily logs.',
                  style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade600, height: 1.4)),
            ]),
          ),

          const SizedBox(height: 28),

          Image.asset('assets/branding/kalinga-logo-app.png', width: 56, height: 56),

          const SizedBox(height: 20),

          Text('設定您的密碼', style: AppTextStyles.heading(fontSize: 26).copyWith(color: Colors.black)),
          const SizedBox(height: 4),
          Text('Set your password', style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600)),

          const SizedBox(height: 28),

          _FieldLabel('電子郵件 · Email'),
          const SizedBox(height: 8),
          _DisabledField(value: invite.email),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('From your invite. It cannot be changed.',
                style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500)),
          ),

          const SizedBox(height: 20),

          _FieldLabel('您的名字 · Your name'),
          const SizedBox(height: 8),
          _InputField(controller: _nameController, hint: '陳美玲'),

          const SizedBox(height: 20),

          _FieldLabel('密碼 · Password'),
          const SizedBox(height: 8),
          _InputField(controller: _passwordController, hint: '••••••', obscureText: true),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('At least 6 characters.', style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500)),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.body(fontSize: 13).copyWith(color: _red)),
          ],

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : () => _submit(invite),
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _red.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text('開始使用 · Start reading', style: AppTextStyles.bodyMedium(fontSize: 17).copyWith(color: Colors.white)),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'You can only read. You cannot change or delete anything ${invite.inviterName} logs.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500, height: 1.5),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

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

class _DisabledField extends StatelessWidget {
  final String value;
  const _DisabledField({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(value, style: AppTextStyles.body(fontSize: 15).copyWith(color: Colors.grey.shade500)),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;

  const _InputField({required this.controller, required this.hint, this.obscureText = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
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
