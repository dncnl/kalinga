import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

class _Language {
  final String name;
  final String native;

  const _Language({required this.name, required this.native});
}

const _languages = [
  _Language(name: 'Tagalog', native: 'Filipino'),
  _Language(name: 'Bisaya', native: 'Cebuano'),
  _Language(name: 'Bahasa Indonesia', native: 'Indonesian'),
  _Language(name: 'Vietnamese', native: 'Tiếng Việt'),
];

class PrototypeLanguagePage extends StatefulWidget {
  const PrototypeLanguagePage({super.key});

  @override
  State<PrototypeLanguagePage> createState() => _PrototypeLanguagePageState();
}

class _PrototypeLanguagePageState extends State<PrototypeLanguagePage> {
  static const _bg = Color(0xFFF5F0E8);
  static const _tealSelected = Color(0xFF2BBFB3);
  static const _tealSelectedBg = Color(0xFFE4F5F3);
  static const _red = Color(0xFFEF3E23);

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),

              // ── Logo ──────────────────────────────────────────────────
              Text(
                'Kalinga',
                style: AppTextStyles.heading(fontSize: 22).copyWith(
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 28),

              // ── Heading ───────────────────────────────────────────────
              Text(
                'Choose your\nlanguage',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading(fontSize: 36).copyWith(
                  color: Colors.black,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 12),

              // ── Subtitle ──────────────────────────────────────────────
              Text(
                'Kalinga speaks your language. The family\nreads Mandarin.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 14).copyWith(
                  color: _red,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 28),

              // ── Language cards ────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  itemCount: _languages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final lang = _languages[index];
                    final isSelected = index == _selected;
                    return _LanguageCard(
                      language: lang,
                      selected: isSelected,
                      tealColor: _tealSelected,
                      tealBg: _tealSelectedBg,
                      onTap: () => setState(() => _selected = index),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // ── Continue button ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/patient'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: AppTextStyles.bodyMedium(fontSize: 17).copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Footer ────────────────────────────────────────────────
              Text(
                'No account needed. You can change this later in Settings.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 12).copyWith(
                  color: Colors.grey.shade500,
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Language card ─────────────────────────────────────────────────────────────

class _LanguageCard extends StatelessWidget {
  final _Language language;
  final bool selected;
  final Color tealColor;
  final Color tealBg;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.language,
    required this.selected,
    required this.tealColor,
    required this.tealBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? tealBg : Colors.white,
          border: Border.all(
            color: selected ? tealColor : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // ── Language name + native ────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language.name,
                    style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    language.native,
                    style: AppTextStyles.body(fontSize: 13).copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            // ── Radio / checkmark ─────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: selected
                  ? Icon(Icons.check, color: tealColor, size: 22, key: const ValueKey('check'))
                  : Container(
                      key: const ValueKey('circle'),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 1.5,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
