import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/family_viewer_service.dart';
import '../state/session_role.dart';
import '../theme.dart';

/// App entry point (`/`). Highlights Sign Up / Log In; both detour through
/// the role picker (`/role`) — for Log In this determines where `AuthPage`
/// routes to after a successful sign-in (caregiver home vs. the signed-in
/// family member's own viewer page), not which form is shown.
///
/// Restored sessions never wait here: a caregiver with a profile is bounced
/// to `/home` by the router redirect, and a family session is resolved to
/// its viewer below (async FamilyViewerService lookup, which a sync router
/// redirect can't do).
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  static const _tagline = 'Care shouldn\'t get lost in translation';

  bool _resumingFamily = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final hasRealAccount = user != null && !user.isAnonymous;
    if (hasRealAccount && SessionRole.instance.isFamily) {
      _resumingFamily = true;
      _resumeFamilySession();
    }
  }

  Future<void> _resumeFamilySession() async {
    try {
      final recipients = await const FamilyViewerService().resolveViewableRecipients();
      if (!mounted) return;
      if (recipients.length == 1) {
        context.go('/viewer/${recipients.first.careRecipient.id}');
        return;
      }
      if (recipients.length > 1) {
        context.go('/family-recipients', extra: recipients);
        return;
      }
      // Zero resolvable recipients — fall back to the normal entry buttons
      // (log in again, or use a fresh code).
      setState(() => _resumingFamily = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _resumingFamily = false);
    }
  }

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

              if (_resumingFamily) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Opening your family view…',
                  style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600),
                ),
              ] else ...[
                // ── Sign up (primary) ──────────────────────────────────
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

                // ── Log in (secondary) ─────────────────────────────────
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
              ],

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
