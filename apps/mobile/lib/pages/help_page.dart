import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/selected_profile.dart';
import '../theme.dart';

/// F6 · Emergency contacts + phrasebook (`/help`).
///
/// Every number here is a real, vetted, nationwide Taiwan service — no
/// placeholders, because a caregiver in a crisis will dial whatever this
/// screen shows. Deliberately NOT included: a "family contact" row. The
/// household's own numbers aren't collected anywhere yet, and a fake one is
/// worse than none.
///
/// Assumes this is the caregiver's PERSONAL phone. Many live-in workers use
/// an employer-provided or employer-monitored handset; the note at the
/// bottom of the screen says so plainly rather than pretending otherwise.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _bg = Color(0xFFFFFFFF);
  static const _red = Color(0xFFEF3E23);
  static const _teal = Color(0xFF2BBFB3);

  // Ordered by urgency: the two that save a life first, then the ones that
  // protect the caregiver herself.
  static const _contacts = [
    _Contact(
      number: '119',
      name: 'Ambulance and fire',
      nameZh: '救護車・消防',
      subtitle: 'Life-threatening emergency',
      urgent: true,
    ),
    _Contact(
      number: '110',
      name: 'Police',
      nameZh: '警察',
      subtitle: 'Danger, violence, or crime',
      urgent: true,
    ),
    _Contact(
      number: '1955',
      name: 'Labor helpline',
      nameZh: '勞工諮詢申訴專線',
      subtitle: 'Free · 24 hours · your language',
      // 1955 is staffed in Indonesian, Vietnamese, Thai and English as well
      // as Mandarin — the one line here that is guaranteed to understand
      // the caller. Unpaid wages, no rest days, abuse, contract problems.
      urgent: false,
    ),
    _Contact(
      number: '0800024111',
      display: '0800 024 111',
      name: 'Foreign resident hotline',
      nameZh: '外來人士在臺服務專線',
      subtitle: 'Free · 24 hours · living, visa, and legal help',
      urgent: false,
    ),
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

            const SizedBox(height: 12),
            Text(
              'These calls come from your own phone. If your employer holds '
              'or checks your phone, use a friend\'s phone or a public phone.',
              style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500, height: 1.5),
            ),

            const SizedBox(height: 32),

            // ── Phrasebook ──────────────────────────────────────────────
            Text('Say it in Mandarin', style: AppTextStyles.heading(fontSize: 24).copyWith(color: Colors.black)),
            const SizedBox(height: 6),
            Text('Show the screen, or read it out loud.',
                style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 14),
            ..._emergencyPhrases.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PhraseCard(phrase: p, accent: _red),
                )),

            const SizedBox(height: 28),

            // ── Hokkien (elder-facing) ──────────────────────────────────
            // The gap nothing else in the app closes: pre-departure training
            // covers Mandarin, but many elders in home care speak only
            // Taiwanese Hokkien. These are the few phrases that come up
            // every single day, written the way they sound.
            Text('Talking to the elder', style: AppTextStyles.heading(fontSize: 24).copyWith(color: Colors.black)),
            const SizedBox(height: 6),
            Text('Many elders speak Taiwanese Hokkien, not Mandarin.\nSay it the way it is written.',
                style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade600, height: 1.5)),
            const SizedBox(height: 14),
            ..._hokkienPhrases.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PhraseCard(phrase: p, accent: _teal),
                )),

            const SizedBox(height: 32),
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

// ── Data ────────────────────────────────────────────────────────────────────

class _Contact {
  final String number;
  final String? display;
  final String name;
  final String nameZh;
  final String subtitle;
  final bool urgent;

  const _Contact({
    required this.number,
    this.display,
    required this.name,
    required this.nameZh,
    required this.subtitle,
    required this.urgent,
  });

  String get displayNumber => display ?? number;
}

class _Phrase {
  /// What the caregiver means, in the app's working language.
  final String meaning;

  /// Written form to show a Mandarin reader. Null for the Hokkien phrases:
  /// Hokkien is spoken, not written, in this context — an elder who speaks
  /// it may not read Han characters, and the written Mandarin equivalent
  /// would be a different sentence, not a transcription.
  final String? script;

  /// How to say it, written for a Tagalog/Bahasa/Vietnamese speaker rather
  /// than in a formal romanization system.
  final String sounds;

  const _Phrase({required this.meaning, this.script, required this.sounds});
}

/// Caregiver → responder/family, in Mandarin. Ordered by how urgent they are.
const _emergencyPhrases = [
  _Phrase(meaning: 'Please send an ambulance.', script: '請派救護車。', sounds: 'ching pai jiu-hu-che'),
  _Phrase(meaning: 'She cannot breathe.', script: '她沒辦法呼吸。', sounds: 'ta mei-ban-fa hu-shi'),
  _Phrase(meaning: 'She fell down.', script: '她跌倒了。', sounds: 'ta die-dao le'),
  _Phrase(meaning: 'She has chest pain.', script: '她胸口痛。', sounds: 'ta shiong-kou tong'),
  _Phrase(meaning: 'I am the caregiver. I am not family.', script: '我是看護，不是家人。', sounds: 'wo shi kan-hu, bu shi jia-ren'),
  _Phrase(meaning: 'I do not speak Mandarin well.', script: '我中文說得不好。', sounds: 'wo jong-wen shuo de bu hao'),
  _Phrase(meaning: 'Please speak slowly.', script: '請說慢一點。', sounds: 'ching shuo man yi-dian'),
];

/// Caregiver → elder, in Taiwanese Hokkien. Deliberately tiny: the handful
/// of things that must be asked every day. Pre-departure training covers
/// Mandarin only, so without these the daily interaction has no shared
/// language at all.
const _hokkienPhrases = [
  _Phrase(meaning: 'Have you eaten?', sounds: 'chiah pa bue?'),
  _Phrase(meaning: 'Time for your medicine.', sounds: 'ho-si chiah ioh a'),
  _Phrase(meaning: 'Do you need the toilet?', sounds: 'beh khi pang-so bo?'),
  _Phrase(meaning: 'Does it hurt? Where?', sounds: 'e thiann bo? toh-ui thiann?'),
  _Phrase(meaning: 'Please rest / lie down.', sounds: 'hioh-khun tsit-e'),
  _Phrase(meaning: 'Are you cold?', sounds: 'e kuann bo?'),
  _Phrase(meaning: 'I am here. Do not worry.', sounds: 'gua ti tsia, mai huan-lo'),
];

// ── Widgets ─────────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final _Contact contact;
  const _ContactCard({required this.contact});

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: contact.number);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      // Web/desktop, or a device with no dialler — show the number so it can
      // still be dialled by hand rather than failing silently.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dial ${contact.displayNumber} on your phone.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = contact.urgent ? HelpPage._red : Colors.black87;
    return GestureDetector(
      onTap: () => _call(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(contact.displayNumber, style: AppTextStyles.bodyMedium(fontSize: 20).copyWith(color: Colors.white)),
            Text('${contact.name} · ${contact.nameZh}',
                style: AppTextStyles.bodyMedium(fontSize: 13).copyWith(color: Colors.white)),
            Text(contact.subtitle,
                style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.white.withValues(alpha: 0.75))),
          ])),
          Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.7), size: 22),
        ]),
      ),
    );
  }
}

class _PhraseCard extends StatelessWidget {
  final _Phrase phrase;
  final Color accent;
  const _PhraseCard({required this.phrase, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(phrase.meaning, style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
        const SizedBox(height: 6),
        if (phrase.script != null) ...[
          Text(phrase.script!, style: AppTextStyles.bodyMedium(fontSize: 19).copyWith(color: accent, height: 1.4)),
          const SizedBox(height: 2),
        ],
        Text(phrase.sounds, style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600)),
      ]),
    );
  }
}
