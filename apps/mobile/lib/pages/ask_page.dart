import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import '../services/rag_service.dart';
import '../state/locale_state.dart';
import '../state/selected_profile.dart';
import '../theme.dart';

class AskPage extends StatefulWidget {
  const AskPage({super.key});
  @override
  State<AskPage> createState() => _AskPageState();
}

class _AskPageState extends State<AskPage> {
  static const _bg = Color(0xFFF5F0E8);
  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);

  final _controller = TextEditingController();
  final _ragService = const RagService();
  static const _prompts = [
    'She is not eating',
    'Chest pain and hard to breathe',
    'She fell down',
  ];

  bool _asking = false;
  SymptomCheckResult? _result;
  String? _error;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _asking) return;

    final profile = SelectedProfile.instance;
    final householdId = profile.householdId;
    final careRecipientId = profile.careRecipient?.id;
    if (householdId == null || careRecipientId == null) {
      setState(() => _error = 'Add a profile before asking about a symptom.');
      return;
    }

    setState(() {
      _asking = true;
      _result = null;
      _error = null;
    });

    try {
      final result = await _ragService.checkSymptom(
        message,
        householdId: householdId,
        careRecipientId: careRecipientId,
        locale: LocaleState.instance.locale,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            _buildHeader(context),
            const SizedBox(height: 28),
            Text('Ask about a symptom', style: AppTextStyles.heading(fontSize: 30).copyWith(color: Colors.black)),
            const SizedBox(height: 8),
            Text('Write in your own language. Kalinga answers, and\nsends the family a Mandarin summary.',
                style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600, height: 1.5)),
            const SizedBox(height: 20),
            TextField(
              controller: _controller, maxLines: 5,
              style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Describe what you noticed…',
                hintStyle: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade400),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _teal, width: 1.5)),
              ),
            ),
            const SizedBox(height: 20),
            ..._prompts.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _controller.text = p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(32)),
                  child: Row(children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 10),
                    Text(p, style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.black87)),
                  ]),
                ),
              ),
            )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _asking ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _asking
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text('Ask', style: AppTextStyles.bodyMedium(fontSize: 15)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFFFE9E5), borderRadius: BorderRadius.circular(14)),
                child: Text(_error!, style: AppTextStyles.body(fontSize: 13).copyWith(color: _red)),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 20),
              _UrgencyBanner(result: _result!),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _teal, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  MarkdownBody(
                    data: _result!.answer,
                    styleSheet: MarkdownStyleSheet(
                      p: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.black87, height: 1.5),
                      strong: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87, height: 1.5),
                      listBullet: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.black87, height: 1.5),
                      h1: AppTextStyles.bodyMedium(fontSize: 18).copyWith(color: Colors.black87),
                      h2: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.black87),
                    ),
                  ),
                  if (_result!.sources.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('SOURCES', style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(color: Colors.grey.shade500, letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    ..._result!.sources.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '[${s.n}] ${s.title} — ${s.publisher}',
                        style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade600),
                      ),
                    )),
                  ],
                ]),
              ),
            ],
            const SizedBox(height: 24),
          ]),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final recipient = SelectedProfile.instance.careRecipient;
    return Row(children: [
      GestureDetector(
        onTap: () => context.push('/profiles'),
        child: Container(width: 38, height: 38, decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
          child: Center(child: Text(recipient?.initials ?? '?', style: AppTextStyles.bodyMedium(fontSize: 13).copyWith(color: Colors.white)))),
      ),
      const SizedBox(width: 10),
      Expanded(child: GestureDetector(
        onTap: () => context.push('/profiles'),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(recipient?.displayName ?? 'Add a profile', style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87)),
            if (recipient != null)
              Text(
                [
                  if (recipient.age != null) '${recipient.age}',
                  if (recipient.preferredLanguages.isNotEmpty) 'speaks ${recipient.preferredLanguages.first}',
                ].join(' · '),
                style: AppTextStyles.body(fontSize: 11).copyWith(color: Colors.grey.shade500),
              ),
          ]),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey.shade500),
        ]),
      )),
      IconButton(onPressed: () => context.push('/activity'), icon: Icon(Icons.notifications_none_rounded, color: Colors.grey.shade700, size: 24), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      const SizedBox(width: 16),
      IconButton(onPressed: () => context.push('/settings'), icon: Icon(Icons.settings_outlined, color: Colors.grey.shade700, size: 24), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
    ]);
  }

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 1,
      onTap: (i) {
        switch (i) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/ask');
            break;
          case 2:
            context.go('/log');
            break;
          case 3:
            context.go('/meds');
            break;
          case 4:
            context.go('/help');
            break;
        }
      },
      type: BottomNavigationBarType.fixed, backgroundColor: Colors.white,
      selectedItemColor: _red, unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle: AppTextStyles.bodyMedium(fontSize: 11),
      unselectedLabelStyle: AppTextStyles.body(fontSize: 11), elevation: 8,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Today'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Ask'),
        BottomNavigationBarItem(icon: Icon(Icons.mic_none_rounded), label: 'Log'),
        BottomNavigationBarItem(icon: Icon(Icons.medication_outlined), label: 'Meds'),
        BottomNavigationBarItem(icon: Icon(Icons.help_outline_rounded), label: 'Help'),
      ],
    );
  }
}

class _UrgencyBanner extends StatelessWidget {
  final SymptomCheckResult result;
  const _UrgencyBanner({required this.result});

  ({Color bg, Color fg, IconData icon, String title}) get _style {
    switch (result.urgency) {
      case 'emergency':
        return (bg: const Color(0xFFFFE9E5), fg: const Color(0xFFB3261E), icon: Icons.emergency_rounded, title: 'Possible emergency');
      case 'urgent':
        return (bg: const Color(0xFFFFF4E5), fg: const Color(0xFFB3691E), icon: Icons.priority_high_rounded, title: 'Needs a doctor soon');
      case 'attention':
        return (bg: const Color(0xFFFFFBEA), fg: const Color(0xFF8A6D00), icon: Icons.visibility_outlined, title: 'Worth watching');
      default:
        return (bg: const Color(0xFFE9F7F5), fg: const Color(0xFF1F7A6C), icon: Icons.check_circle_outline_rounded, title: 'Not urgent');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(s.icon, color: s.fg, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.title, style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: s.fg)),
          const SizedBox(height: 4),
          Text(
            result.flaggedToFamily
                ? 'Sent to family and doctor in Mandarin.'
                : 'Not sent to family — not urgent enough to flag.',
            style: AppTextStyles.body(fontSize: 12).copyWith(color: s.fg.withValues(alpha: 0.85)),
          ),
          if (result.flaggedToFamily) ...[
            const SizedBox(height: 8),
            Text(result.familySummaryZh, style: AppTextStyles.body(fontSize: 13).copyWith(color: s.fg, height: 1.4)),
          ],
        ])),
      ]),
    );
  }
}
