import 'package:flutter/material.dart';

import '../theme.dart';

class PrototypeAskPage extends StatefulWidget {
  const PrototypeAskPage({super.key});

  @override
  State<PrototypeAskPage> createState() => _PrototypeAskPageState();
}

class _PrototypeAskPageState extends State<PrototypeAskPage> {
  static const _bg = Color(0xFFFFFFFF);
  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);

  final _controller = TextEditingController();

  static const _prompts = [
    'She is not eating',
    'Chest pain and hard to breathe',
    'She fell down',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 28),

              // ── Title ────────────────────────────────────────────────
              Text(
                'Ask about a symptom',
                style: AppTextStyles.heading(fontSize: 30)
                    .copyWith(color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                'Write in your own language. Kalinga answers, and\nsends the family a Mandarin summary.',
                style: AppTextStyles.body(fontSize: 14).copyWith(
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),

              // ── Text input ───────────────────────────────────────────
              TextField(
                controller: _controller,
                maxLines: 5,
                style: AppTextStyles.body(fontSize: 14)
                    .copyWith(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Describe what you noticed…',
                  hintStyle: AppTextStyles.body(fontSize: 14)
                      .copyWith(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: _teal, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Quick prompts ────────────────────────────────────────
              ..._prompts.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _controller.text = p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border:
                            Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 16,
                              color: Colors.grey.shade500),
                          const SizedBox(width: 10),
                          Text(
                            p,
                            style: AppTextStyles.body(fontSize: 14)
                                .copyWith(color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(1),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
              color: Color(0xFF2BBFB3), shape: BoxShape.circle),
          child: Center(
            child: Text('LR',
                style: AppTextStyles.bodyMedium(fontSize: 13)
                    .copyWith(color: Colors.white)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lola Rosa',
                    style: AppTextStyles.bodyMedium(fontSize: 14)
                        .copyWith(color: Colors.black87)),
                Text('82 · speaks Hokkien',
                    style: AppTextStyles.body(fontSize: 11)
                        .copyWith(color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: Colors.grey.shade500),
          ]),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.notifications_none_rounded,
              color: Colors.grey.shade700, size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.settings_outlined,
              color: Colors.grey.shade700, size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildBottomNav(int index) {
    return BottomNavigationBar(
      currentIndex: index,
      onTap: (_) {},
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: _red,
      unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle: AppTextStyles.bodyMedium(fontSize: 11),
      unselectedLabelStyle: AppTextStyles.body(fontSize: 11),
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded), label: 'Today'),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Ask'),
        BottomNavigationBarItem(
            icon: Icon(Icons.mic_none_rounded), label: 'Log'),
        BottomNavigationBarItem(
            icon: Icon(Icons.medication_outlined), label: 'Meds'),
        BottomNavigationBarItem(
            icon: Icon(Icons.help_outline_rounded), label: 'Help'),
      ],
    );
  }
}
