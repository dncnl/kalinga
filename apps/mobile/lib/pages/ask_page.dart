import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/rag_service.dart';
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
  RagAnswer? _answer;
  String? _error;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _asking) return;

    setState(() {
      _asking = true;
      _answer = null;
      _error = null;
    });

    try {
      final result = await _ragService.ask(question);
      if (!mounted) return;
      setState(() => _answer = result);
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
            if (_answer != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _teal, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_answer!.answer, style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.black87, height: 1.5)),
                  if (_answer!.sources.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('SOURCES', style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(color: Colors.grey.shade500, letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    ..._answer!.sources.map((s) => Padding(
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
    return Row(children: [
      GestureDetector(
        onTap: () => context.push('/patients/lola-rosa'),
        child: Container(width: 38, height: 38, decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
          child: Center(child: Text('LR', style: AppTextStyles.bodyMedium(fontSize: 13).copyWith(color: Colors.white)))),
      ),
      const SizedBox(width: 10),
      Expanded(child: GestureDetector(
        onTap: () => context.push('/patients/lola-rosa'),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Lola Rosa', style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87)),
            Text('82 · speaks Hokkien', style: AppTextStyles.body(fontSize: 11).copyWith(color: Colors.grey.shade500)),
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
