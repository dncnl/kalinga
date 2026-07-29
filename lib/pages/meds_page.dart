import 'package:flutter/material.dart';
import '../theme.dart';

class MedsPage extends StatefulWidget {
  const MedsPage({super.key});
  @override
  State<MedsPage> createState() => _MedsPageState();
}

class _MedsPageState extends State<MedsPage> {
  static const _bg = Color(0xFFF5F0E8);
  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);

  final _taken = {0: true, 1: false, 2: false};

  static const _meds = [
    _Med('Donepezil',   '1 tablet · 5 mg · 08:00'),
    _Med('Amlodipine',  '1 tablet · 5 mg · 09:00'),
    _Med('Metformin',   '2 tablets · 500 mg · 21:00'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            _buildHeader(),
            const SizedBox(height: 28),
            Text('Medicines', style: AppTextStyles.heading(fontSize: 32).copyWith(color: Colors.black)),
            const SizedBox(height: 8),
            Text('Photograph the box. Kalinga reads the dose\nfor you.',
                style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600, height: 1.5)),
            const SizedBox(height: 20),
            // Scan box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                Icon(Icons.camera_alt_outlined, size: 32, color: Colors.grey.shade500),
                const SizedBox(height: 8),
                Text('Scan label', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
                const SizedBox(height: 4),
                Text('Hold the box steady in good light',
                    style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500)),
              ]),
            ),
            const SizedBox(height: 24),
            Text('TODAY', style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(color: Colors.grey.shade500, letterSpacing: 0.8)),
            const SizedBox(height: 12),
            ...List.generate(_meds.length, (i) {
              final taken = _taken[i] ?? false;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.medication_outlined, color: Colors.grey.shade500, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_meds[i].name, style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
                      Text(_meds[i].details, style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500)),
                    ])),
                    taken
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(20)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.check, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text('TAKEN', style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(color: Colors.white)),
                            ]),
                          )
                        : OutlinedButton(
                            onPressed: () => setState(() => _taken[i] = true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: const BorderSide(color: Colors.black87),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            child: Text('Mark taken', style: AppTextStyles.bodyMedium(fontSize: 13)),
                          ),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 24),
          ]),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Row(children: [
      Container(width: 38, height: 38,
        decoration: const BoxDecoration(color: Color(0xFF2BBFB3), shape: BoxShape.circle),
        child: Center(child: Text('LR', style: AppTextStyles.bodyMedium(fontSize: 13).copyWith(color: Colors.white)))),
      const SizedBox(width: 10),
      Expanded(child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Lola Rosa', style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87)),
          Text('82 · speaks Hokkien', style: AppTextStyles.body(fontSize: 11).copyWith(color: Colors.grey.shade500)),
        ]),
        const SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey.shade500),
      ])),
      IconButton(onPressed: () {}, icon: Icon(Icons.notifications_none_rounded, color: Colors.grey.shade700, size: 24), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      const SizedBox(width: 16),
      IconButton(onPressed: () {}, icon: Icon(Icons.settings_outlined, color: Colors.grey.shade700, size: 24), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
    ]);
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 3, onTap: (_) {},
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: _red, unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle: AppTextStyles.bodyMedium(fontSize: 11),
      unselectedLabelStyle: AppTextStyles.body(fontSize: 11),
      elevation: 8,
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

class _Med {
  final String name, details;
  const _Med(this.name, this.details);
}
