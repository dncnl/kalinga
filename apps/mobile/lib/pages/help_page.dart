import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../data/phrasebook_data.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  static const _bg = Color(0xFFF5F0E8);
  static const _red = Color(0xFFEF3E23);
  static const _teal = Color(0xFF2BBFB3);

  static const _primaryContacts = [
    _Contact('119', 'Ambulance and fire', 'Life-threatening emergency', _red, true),
    _Contact('1955', 'Labor helpline', 'Free · your language · 24 hours', Colors.black, false),
  ];

  static const _moreContacts = [
    _Contact('110', 'Police', 'Danger or crime', _red, true),
    _Contact('1990', 'Foreigner hotline', 'Living and visa questions', Colors.black, false),
  ];

  static const _familyContact = _Contact('0912 345 678', "Rosa's daughter", 'Family contact', _teal, false);
  static const _clinicContact = _Contact('02 2595 3316', 'City health hotline', 'Medical advice', _teal, false);

  late FlutterTts _flutterTts;
  String? _speakingId;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("zh-TW");
    await _flutterTts.setSpeechRate(0.4);
    
    _flutterTts.setStartHandler(() {
      if (mounted) setState(() {});
    });
    
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _speakingId = null;
        });
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _speakingId = null;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speak(PhrasebookEntry entry) async {
    // For now we default to Mandarin
    setState(() {
      _speakingId = entry.id;
    });
    await _flutterTts.speak(entry.targetPhrase);
  }

  Future<void> _makeCall(String number) async {
    final cleanNumber = number.replaceAll(' ', '');
    final uri = Uri.parse('tel:$cleanNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not place call')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not place call')));
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
            Text('Get help now', style: AppTextStyles.heading(fontSize: 32).copyWith(color: Colors.black)),
            const SizedBox(height: 6),
            Text('One tap calls. No menus.',
                style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            ..._primaryContacts.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ContactCard(
                contact: c,
                onTap: () => _makeCall(c.number),
              ),
            )),
            const SizedBox(height: 10),
            _buildQuickActions(),
            const SizedBox(height: 10),
            _buildMoreNumbers(),
            const SizedBox(height: 32),
            _buildPhrasebookHeader(),
            const SizedBox(height: 16),
            _buildPhrasebookList(),
            const SizedBox(height: 24),
          ]),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.phone_rounded,
            label: 'Call family',
            onTap: () => _makeCall(_familyContact.number),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.local_hospital_rounded,
            label: 'Clinic',
            onTap: () => _makeCall(_clinicContact.number),
          ),
        ),
      ],
    );
  }

  Widget _buildPhrasebookHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Emergency phrasebook',
          style: AppTextStyles.heading(fontSize: 18).copyWith(color: Colors.black),
        ),
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit coming soon')));
          },
          child: Row(
            children: [
              const Icon(Icons.edit, size: 16, color: _teal),
              const SizedBox(width: 4),
              Text('Edit', style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: _teal)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhrasebookList() {
    return Column(
      children: [
        // Disclaimer for Hokkien
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Showing Mandarin — Hokkien phrases coming soon',
                    style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.orange.shade900),
                  ),
                ),
              ],
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: phrasebookSeed.length,
          itemBuilder: (context, index) {
            final entry = phrasebookSeed[index];
            final isSpeaking = _speakingId == entry.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isSpeaking ? Colors.teal.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSpeaking ? _teal : Colors.grey.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.targetRomanization,
                            style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.targetPhrase,
                            style: AppTextStyles.heading(fontSize: 18).copyWith(color: Colors.black),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.caregiverGloss,
                            style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _speak(entry),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: _teal,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            isSpeaking ? Icons.volume_up : Icons.volume_up_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMoreNumbers() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        title: Text('More numbers', style: AppTextStyles.heading(fontSize: 16).copyWith(color: Colors.black)),
        initiallyExpanded: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        children: _moreContacts.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
          child: _ContactCard(
            contact: c,
            onTap: () => _makeCall(c.number),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(children: [
      GestureDetector(
        onTap: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
          child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.black87)),
        ),
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
  final VoidCallback onTap;
  
  const _ContactCard({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = contact.isLight ? Colors.white : Colors.white;
    return GestureDetector(
      onTap: onTap,
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

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.black),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black)),
        ],
      ),
    );
  }
}
