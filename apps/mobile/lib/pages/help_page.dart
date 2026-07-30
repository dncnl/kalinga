import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../data/phrasebook_data.dart';
import '../data/content_sync_repository.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  static const _bg = Color(0xFFF5F0E8);
  static const _red = Color(0xFFEF3E23);
  static const _teal = Color(0xFF2BBFB3);

  static const _bundledNumbers = [
    _Contact('119', 'Ambulance and fire', 'Ambulance and fire', _red, true, displayOrder: 2),
    _Contact('1955', 'Labor helpline', 'Labor helpline', Colors.black, false, displayOrder: 4),
    _Contact('110', 'Police', 'Police', _red, true, displayOrder: 1),
    _Contact('1990', 'Foreigner hotline', 'Foreigner helpline', Colors.black, false, displayOrder: 6),
    _Contact('0800474580', 'National Dementia Care Hotline', 'Dementia support', Colors.black, false, displayOrder: 7),
    _Contact('1966', 'Long-Term Care Service Hotline', 'Long-term care', Colors.black, false, displayOrder: 5),
    _Contact('1995', 'Lifeline (caregiver support)', 'Caregiver support', Colors.black, false, displayOrder: 8),
    _Contact('165', 'Anti-Fraud Hotline', 'Danger or protection', Colors.black, false, displayOrder: 9),
  ];

  List<_Contact> _primaryContacts = [];
  List<_Contact> _moreContacts = [];
  List<PhrasebookEntry> _phrases = phrasebookSeed;

  late final ContentSyncRepository<_Contact> _numbersRepo;
  late final ContentSyncRepository<PhrasebookEntry> _phrasebookRepo;

  _Contact _familyContact = const _Contact(
    '0912 345 678',
    "Rosa's daughter",
    'Family contact',
    _teal,
    false,
  );
  _Contact _clinicContact = const _Contact(
    '02 2595 3316',
    'City health hotline',
    'Medical advice',
    _teal,
    false,
  );


  late FlutterTts _flutterTts;
  String? _speakingId;
  bool _moreNumbersExpanded = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadContacts();
    _initContentSync();
  }

  Future<void> _initContentSync() async {
    _numbersRepo = ContentSyncRepository<_Contact>(
      collectionPath: 'governmentServices',
      cacheKey: 'government_services_cache',
      fromJson: _Contact.fromJson,
      toJson: (c) => c.toJson(),
      bundledSeed: _bundledNumbers,
    );
    _phrasebookRepo = ContentSyncRepository<PhrasebookEntry>(
      collectionPath: 'emergencyPhrasebooks/core-1.0.0/phrases',
      cacheKey: 'emergency_phrases_cache',
      fromJson: PhrasebookEntry.fromJson,
      toJson: (p) => p.toJson(),
      bundledSeed: phrasebookSeed,
    );

    // Initial load from cache or bundled seed
    final numbers = await _numbersRepo.getInitial();
    final phrases = await _phrasebookRepo.getInitial();

    if (mounted) {
      setState(() {
        _primaryContacts = numbers.where((c) => c.number == '119' || c.number == '1955').toList();
        _moreContacts = numbers.where((c) => c.number != '119' && c.number != '1955').toList();
        _moreContacts.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        _phrases = phrases;
        _phrases.sort((a, b) => a.id.compareTo(b.id)); // Maintain display order or ID ordering
      });
    }

    // Background sync
    final updatedNumbers = await _numbersRepo.syncInBackground();
    final updatedPhrases = await _phrasebookRepo.syncInBackground();

    if (mounted) {
      setState(() {
        if (updatedNumbers != null) {
          _primaryContacts = updatedNumbers.where((c) => c.number == '119' || c.number == '1955').toList();
          _moreContacts = updatedNumbers.where((c) => c.number != '119' && c.number != '1955').toList();
          _moreContacts.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        }
        if (updatedPhrases != null) {
          _phrases = updatedPhrases;
          _phrases.sort((a, b) => a.id.compareTo(b.id));
        }
      });
    }
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _familyContact = _Contact(
          prefs.getString('family_contact_number') ?? _familyContact.number,
          _familyContact.name,
          _familyContact.subtitle,
          _familyContact.bg,
          _familyContact.isLight,
        );
        _clinicContact = _Contact(
          prefs.getString('clinic_contact_number') ?? _clinicContact.number,
          _clinicContact.name,
          _clinicContact.subtitle,
          _clinicContact.bg,
          _clinicContact.isLight,
        );
      });
    }
  }

  Future<void> _showEditDialog(bool isFamily) async {
    final contact = isFamily ? _familyContact : _clinicContact;
    final numberController = TextEditingController(text: contact.number);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Edit ${contact.name}',
            style: AppTextStyles.heading(fontSize: 18),
          ),
          content: TextField(
            controller: numberController,
            decoration: const InputDecoration(labelText: 'Phone Number'),
            keyboardType: TextInputType.phone,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(numberController.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      if (isFamily) {
        await prefs.setString('family_contact_number', result);
        setState(() {
          _familyContact = _Contact(
            result,
            _familyContact.name,
            _familyContact.subtitle,
            _familyContact.bg,
            _familyContact.isLight,
          );
        });
      } else {
        await prefs.setString('clinic_contact_number', result);
        setState(() {
          _clinicContact = _Contact(
            result,
            _clinicContact.name,
            _clinicContact.subtitle,
            _clinicContact.bg,
            _clinicContact.isLight,
          );
        });
      }
    }
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();

    try {
      final List<dynamic>? languages = await _flutterTts.getLanguages;
      debugPrint('TTS Available Languages: $languages');
      
      final List<dynamic>? voices = await _flutterTts.getVoices;
      debugPrint('TTS Available Voices: $voices');

      // Attempt to set zh-TW
      int result = await _flutterTts.setLanguage("zh-TW");
      debugPrint('TTS SetLanguage zh-TW result: $result');

      // Fallback if zh-TW is not supported
      if (result == 0 && languages != null) {
        final possibleFallbacks = ['zh_TW', 'zh-CN', 'zh_HK', 'zh'];
        for (final code in possibleFallbacks) {
          if (languages.contains(code)) {
            result = await _flutterTts.setLanguage(code);
            debugPrint('TTS SetLanguage fallback $code result: $result');
            if (result == 1) break;
          }
        }
      }
    } catch (e) {
      debugPrint('TTS Initialization exception: $e');
    }

    await _flutterTts.setSpeechRate(0.6);

    _flutterTts.setStartHandler(() {
      debugPrint('TTS Speak Started');
      if (mounted) setState(() {});
    });

    _flutterTts.setCompletionHandler(() {
      debugPrint('TTS Speak Completed');
      if (mounted) {
        setState(() {
          _speakingId = null;
        });
      }
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('TTS Error: $msg');
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
    debugPrint('TTS requesting speak for ID: ${entry.id}, text: "${entry.ttsPhrase}"');
    if (_speakingId != null && _speakingId != entry.id) {
      await _flutterTts.stop();
      await Future.delayed(const Duration(milliseconds: 50));
    }
    // For now we default to Mandarin
    setState(() {
      _speakingId = entry.id;
    });

    final result = await _flutterTts.speak(entry.ttsPhrase);
    debugPrint('TTS speak call returned: $result');
  }

  Future<void> _makeCall(String number) async {
    final cleanNumber = number.replaceAll(' ', '');
    final uri = Uri.parse('tel:$cleanNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not place call')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not place call')));
    }
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
              _buildHeader(context),
              const SizedBox(height: 28),
              Text(
                'Get help now',
                style: AppTextStyles.heading(
                  fontSize: 32,
                ).copyWith(color: Colors.black),
              ),
              const SizedBox(height: 6),
              Text(
                'One tap calls. No menus.',
                style: AppTextStyles.body(
                  fontSize: 14,
                ).copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ..._primaryContacts.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ContactCard(
                    contact: c,
                    onTap: () => _makeCall(c.number),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildQuickActions(),
              const SizedBox(height: 10),
              _buildMoreNumbers(),
              const SizedBox(height: 32),
              _buildPhrasebookHeader(),
              const SizedBox(height: 16),
              _buildPhrasebookList(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Edit phone # by long pressing',
          style: AppTextStyles.body(
            fontSize: 12,
          ).copyWith(color: Colors.grey.shade500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.phone_rounded,
                label: 'Call family',
                phoneNumber: _familyContact.number,
                onTap: () => _makeCall(_familyContact.number),
                onLongPress: () => _showEditDialog(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.local_hospital_rounded,
                label: 'Clinic',
                phoneNumber: _clinicContact.number,
                onTap: () => _makeCall(_clinicContact.number),
                onLongPress: () => _showEditDialog(false),
              ),
            ),
          ],
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
          style: AppTextStyles.heading(
            fontSize: 18,
          ).copyWith(color: Colors.black),
        ),
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Edit coming soon')));
          },
          child: Row(
            children: [
              const Icon(Icons.edit, size: 16, color: _teal),
              const SizedBox(width: 4),
              Text(
                'Edit',
                style: AppTextStyles.bodyMedium(
                  fontSize: 14,
                ).copyWith(color: _teal),
              ),
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
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Showing Mandarin — Hokkien phrases coming soon',
                    style: AppTextStyles.body(
                      fontSize: 12,
                    ).copyWith(color: Colors.orange.shade900),
                  ),
                ),
              ],
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _phrases.length,
          itemBuilder: (context, index) {
            final entry = _phrases[index];
            final isSpeaking = _speakingId == entry.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: isSpeaking ? Colors.teal.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSpeaking ? _teal : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.targetRomanization,
                            style: AppTextStyles.body(
                              fontSize: 13,
                            ).copyWith(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.targetPhrase,
                            style: AppTextStyles.heading(
                              fontSize: 18,
                            ).copyWith(color: Colors.black),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.caregiverGloss,
                            style: AppTextStyles.body(
                              fontSize: 13,
                            ).copyWith(color: Colors.grey.shade600),
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
                            isSpeaking
                                ? Icons.volume_up
                                : Icons.volume_up_outlined,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            ListTile(
              title: Text(
                'More numbers',
                style: AppTextStyles.heading(
                  fontSize: 16,
                ).copyWith(color: Colors.black),
              ),
              trailing: Icon(
                _moreNumbersExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: Colors.grey.shade600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onTap: () {
                setState(() {
                  _moreNumbersExpanded = !_moreNumbersExpanded;
                });
              },
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 400),
              sizeCurve: Curves.easeInOut,
              crossFadeState: _moreNumbersExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Column(
                children: _moreContacts
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: 10,
                          left: 16,
                          right: 16,
                        ),
                        child: _ContactCard(
                          contact: c,
                          onTap: () => _makeCall(c.number),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/patients/lola-rosa'),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lola Rosa',
                      style: AppTextStyles.bodyMedium(
                        fontSize: 14,
                      ).copyWith(color: Colors.black87),
                    ),
                    Text(
                      '82 · speaks Hokkien',
                      style: AppTextStyles.body(
                        fontSize: 11,
                      ).copyWith(color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: () => context.push('/activity'),
          icon: Icon(
            Icons.notifications_none_rounded,
            color: Colors.grey.shade700,
            size: 24,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: Icon(
            Icons.settings_outlined,
            color: Colors.grey.shade700,
            size: 24,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
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
      selectedItemColor: _red,
      unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle: AppTextStyles.bodyMedium(fontSize: 11),
      unselectedLabelStyle: AppTextStyles.body(fontSize: 11),
      elevation: 8,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Today'),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          label: 'Ask',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.mic_none_rounded),
          label: 'Log',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.medication_outlined),
          label: 'Meds',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.help_outline_rounded),
          label: 'Help',
        ),
      ],
    );
  }
}

class _Contact {
  final String number, name, subtitle;
  final Color bg;
  final bool isLight;
  final int displayOrder;

  const _Contact(this.number, this.name, this.subtitle, this.bg, this.isLight, {this.displayOrder = 0});

  static String _labelForCategory(String category) {
    switch (category) {
      case 'police':
        return 'Police';
      case 'fireMedicalEmergency':
        return 'Ambulance and fire';
      case 'protection':
        return 'Danger or protection';
      case 'labor':
        return 'Labor helpline';
      case 'longTermCare':
        return 'Long-term care';
      case 'generalForeignerSupport':
        return 'Foreigner helpline';
      case 'dementiaSupport':
        return 'Dementia support';
      case 'caregiverSupport':
        return 'Caregiver support';
      default:
        return category;
    }
  }

  factory _Contact.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as String;
    final isEmergency = json['emergency'] as bool? ?? false;
    return _Contact(
      json['phoneNumber'] as String? ?? json['shortName'] as String,
      json['officialName'] as String,
      _labelForCategory(category),
      isEmergency ? _HelpPageState._red : Colors.black,
      isEmergency,
      displayOrder: json['displayOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'phoneNumber': number,
    'officialName': name,
    'category': subtitle,
    'emergency': isLight,
    'displayOrder': displayOrder,
  };
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
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.number,
                    style: AppTextStyles.bodyMedium(
                      fontSize: 17,
                    ).copyWith(color: fg),
                  ),
                  Text(
                    contact.name,
                    style: AppTextStyles.bodyMedium(
                      fontSize: 13,
                    ).copyWith(color: fg),
                  ),
                  Text(
                    contact.subtitle,
                    style: AppTextStyles.body(
                      fontSize: 12,
                    ).copyWith(color: fg.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String phoneNumber;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.phoneNumber,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      onLongPress: onLongPress,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: Colors.black),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium(
                fontSize: 14,
              ).copyWith(color: Colors.black),
            ),
            const SizedBox(height: 4),
            Text(
              phoneNumber,
              style: AppTextStyles.body(
                fontSize: 13,
              ).copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
