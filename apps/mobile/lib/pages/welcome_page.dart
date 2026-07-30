import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

/// App entry point (`/`). Highlights Sign Up / Log In, with a
/// "continue without an account" path into the existing
/// language → patient-setup flow — same optional-auth philosophy as
/// `AuthPage`. UI/navigation only, nothing here talks to the backend or
/// database directly. Both Sign Up and Log In now detour through the role
/// picker (`/role`) — for Log In this determines where `AuthPage` routes to
/// after a successful sign-in (caregiver home vs. the signed-in family
/// member's own viewer page), not which form is shown (email+password is
/// the same either way).
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  // Placeholder copy — easy to find/replace, same pattern as the
  // `_languages` / `_scheduleItems` consts elsewhere in this codebase.
  static const _tagline =
      'Care shouldn\'t get lost in translation';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Logo mark ─────────────────────────────────────────────
              Image.asset(
                'assets/branding/kalinga-logo-app.png',
                width: 96,
                height: 96,
              ),

              const SizedBox(height: 20),

              // ── Wordmark ──────────────────────────────────────────────
              Image.asset(
                'assets/branding/kalinga-logo-text.png',
                height: 40,
              ),

              const SizedBox(height: 16),

              Text(
                _tagline,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 14).copyWith(
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 56),

              // ── Sign up (primary) ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/role'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Sign up',
                    style: AppTextStyles.bodyMedium(
                      fontSize: 17,
                    ).copyWith(color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Log in (secondary) ───────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push('/role?mode=login'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  child: Text(
                    'Log in',
                    style: AppTextStyles.bodyMedium(fontSize: 17),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Continue without an account (tertiary) ───────────────
              GestureDetector(
                onTap: () => context.push('/language'),
                child: Text(
                  'Continue without an account',
                  style: AppTextStyles.bodyMedium(
                    fontSize: 15,
                  ).copyWith(color: Colors.black87),
                ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
