import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../state/selected_profile.dart';
import '../theme.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _bg = Color(0xFFF5F0E8);
  static const _red = Color(0xFFEF3E23);
  static const _teal = Color(0xFF2BBFB3);

  static const _contacts = [
    _Contact('119', 'Ambulance and fire', 'Life-threatening emergency', _red, true),
    _Contact('110', 'Police', 'Danger or crime', _red, true),
    _Contact('1955', 'Labor helpline', 'Free · your language · 24 hours', Colors.black, false),
    _Contact('1990', 'Foreigner hotline', 'Living and visa questions', Colors.black, false),
    _Contact('0912 345 678', "Rosa's daughter", 'Family contact', _teal, false),
    _Contact('02 2595 3316', 'City health hotline', 'Medical advice', _teal, false),
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
            _buildHeader(context),
            const SizedBox(height: 28),
            Text('Get help now', style: AppTextStyles.heading(fontSize: 32).copyWith(color: Colors.black)),
            const SizedBox(height: 6),
            Text('One tap calls. No menus.',
                style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            ..._contacts.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ContactCard(contact: c),
            )),
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
        child: Container(width: 38, height: 38,
          decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
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
      currentIndex: 4,
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

class _Contact {
  final String number, name, subtitle;
  final Color bg;
  final bool isLight;
  const _Contact(this.number, this.name, this.subtitle, this.bg, this.isLight);
}

class _ContactCard extends StatelessWidget {
  final _Contact contact;
  const _ContactCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    final fg = contact.isLight ? Colors.white : Colors.white;
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: contact.bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(contact.number, style: AppTextStyles.bodyMedium(fontSize: 17).copyWith(color: fg)),
            Text(contact.name, style: AppTextStyles.bodyMedium(fontSize: 13).copyWith(color: fg)),
            Text(contact.subtitle, style: AppTextStyles.body(fontSize: 12).copyWith(color: fg.withValues(alpha: 0.75))),
          ])),
          Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.7), size: 22),
        ]),
      ),
    );
  }
}
