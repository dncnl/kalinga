import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/back_button.dart';

/// Screen — role picker (`/role`). Pushed from WelcomePage's "Sign up" and
/// "Log in" buttons alike (`isLogin` distinguishes the two); forks into the
/// existing caregiver AuthPage or the family path (FamilyCodePage for
/// signup, AuthPage's login form for a returning family member). Pure
/// navigation, no state/network of its own.
class RoleSelectPage extends StatelessWidget {
  final bool isLogin;
  const RoleSelectPage({super.key, this.isLogin = false});

  @override
  Widget build(BuildContext context) {
    final familySubtitle = isLogin
        ? '我已經有帳號，登入查看紀錄 · I already have an account to view their logs.'
        : '我有照顧者提供的代碼，可以查看紀錄 · I have a code from the caregiver to read their logs.';
    final caregiverSubtitle = isLogin
        ? 'Sign in to keep logging care for the family you already invited.'
        : 'I log daily care and send updates to the family.';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              const Align(alignment: Alignment.centerLeft, child: AppBackButton()),

              const SizedBox(height: 40),

              Image.asset('assets/branding/kalinga-logo-app.png', width: 56, height: 56),

              const SizedBox(height: 24),

              Text(
                isLogin ? 'Welcome back — who\'s signing in?' : 'Who\'s joining?',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading(fontSize: 30).copyWith(color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps us take you to the right place.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600, height: 1.5),
              ),

              const SizedBox(height: 40),

              _RoleCard(
                icon: Icons.favorite_rounded,
                title: 'I\'m the caregiver',
                subtitle: caregiverSubtitle,
                onTap: () => context.push(isLogin ? '/auth?mode=login' : '/auth'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.people_alt_rounded,
                title: '我是家人 · I\'m a family member',
                subtitle: familySubtitle,
                onTap: () => context.push(isLogin ? '/auth?mode=login&role=family' : '/family-code'),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.teal, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: AppTextStyles.body(fontSize: 13).copyWith(color: AppColors.secondaryText, height: 1.4)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
