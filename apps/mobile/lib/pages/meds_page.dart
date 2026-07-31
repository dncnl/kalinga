import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../services/medication_service.dart';
import '../state/selected_profile.dart';
import '../theme.dart';

class MedsPage extends StatefulWidget {
  const MedsPage({super.key});
  @override
  State<MedsPage> createState() => _MedsPageState();
}

class _MedsPageState extends State<MedsPage> {
  static const _bg = Color(0xFFFFFFFF);
  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);

  final _medicationService = const MedicationService();
  final _picker = ImagePicker();

  List<Medication> _meds = [];
  List<MedicationEvent> _events = [];
  bool _loading = true;
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ({String householdId, String careRecipientId})? get _scope {
    final profile = SelectedProfile.instance;
    final householdId = profile.householdId;
    final careRecipientId = profile.careRecipient?.id;
    if (householdId == null || careRecipientId == null) return null;
    return (householdId: householdId, careRecipientId: careRecipientId);
  }

  Future<void> _load() async {
    final scope = _scope;
    if (scope == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // listMedications and todaysEvents don't depend on each other's
      // result -- run them in parallel instead of one-after-the-other.
      // (todaysEvents still does its own internal generate-then-list
      // round trip, which has to stay sequential.)
      final results = await Future.wait([
        _medicationService.listMedications(scope.householdId, scope.careRecipientId),
        _medicationService.todaysEvents(scope.householdId, scope.careRecipientId),
      ]);
      if (!mounted) return;
      setState(() {
        _meds = results[0] as List<Medication>;
        _events = results[1] as List<MedicationEvent>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanLabel() async {
    final scope = _scope;
    if (scope == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a profile before scanning a label.')),
      );
      return;
    }
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo == null) return;

    setState(() => _scanning = true);
    try {
      final draft = await _medicationService.scanLabel(
        photo,
        householdId: scope.householdId,
        careRecipientId: scope.careRecipientId,
      );
      if (!mounted) return;
      await _showConfirmSheet(draft);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read label: $e')),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _showConfirmSheet(Medication draft) async {
    final scope = _scope;
    if (scope == null) return;

    final nameCtrl = TextEditingController(text: draft.name);
    final strengthCtrl = TextEditingController(text: draft.strength ?? '');
    final dosageCtrl = TextEditingController(text: draft.dosageText);
    final routeCtrl = TextEditingController(text: draft.route ?? '');
    final instructionsCtrl = TextEditingController(text: draft.specialInstructions ?? '');
    final timesCtrl = TextEditingController(text: draft.times.join(', '));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Review before saving',
                      style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.black87)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                "Kalinga read this from the photo — check it's correct. Nothing is scheduled until you confirm.",
                style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 16),
              _field('Medicine name', nameCtrl),
              _field('Strength (e.g. 5 mg)', strengthCtrl),
              _field('Dosage instructions', dosageCtrl),
              _field('Route (e.g. oral)', routeCtrl),
              _field('Special instructions', instructionsCtrl),
              _field('Times (HH:mm, comma-separated)', timesCtrl),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Discard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _teal),
                    onPressed: () async {
                      final times = timesCtrl.text
                          .split(',')
                          .map((t) => t.trim())
                          .where((t) => RegExp(r'^\d{2}:\d{2}$').hasMatch(t))
                          .toList();
                      try {
                        await _medicationService.confirmMedication(
                          scope.householdId,
                          scope.careRecipientId,
                          draft.id,
                          name: nameCtrl.text.trim(),
                          dosageText: dosageCtrl.text.trim(),
                          strength: strengthCtrl.text.trim().isEmpty ? null : strengthCtrl.text.trim(),
                          route: routeCtrl.text.trim().isEmpty ? null : routeCtrl.text.trim(),
                          times: times,
                          specialInstructions:
                              instructionsCtrl.text.trim().isEmpty ? null : instructionsCtrl.text.trim(),
                        );
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                      } catch (e) {
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(content: Text('Could not confirm: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Confirm'),
                  ),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _markTaken(MedicationEvent event) async {
    final scope = _scope;
    if (scope == null) return;
    try {
      await _medicationService.markEvent(
        scope.householdId, scope.careRecipientId, event.id,
        status: 'completed',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark taken: $e')),
      );
    }
  }

  Medication? _medFor(String medicationId) {
    for (final med in _meds) {
      if (med.id == medicationId) return med;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final confirmedCount = _meds.where((m) => !m.needsConfirmation).length;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 16),
              _buildHeader(context),
              const SizedBox(height: 28),
              Text('Medicines', style: AppTextStyles.heading(fontSize: 32).copyWith(color: Colors.black)),
              const SizedBox(height: 8),
              Text('Photograph the box. Kalinga reads the dose\nfor you.',
                  style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600, height: 1.5)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _scanning ? null : _scanLabel,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    _scanning
                        ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3))
                        : Icon(Icons.camera_alt_outlined, size: 32, color: Colors.grey.shade500),
                    const SizedBox(height: 8),
                    Text(_scanning ? 'Reading label...' : 'Scan label',
                        style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text('Hold the box steady in good light',
                        style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: AppTextStyles.body(fontSize: 12).copyWith(color: _red)),
                ),
              Text('TODAY', style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(color: Colors.grey.shade500, letterSpacing: 0.8)),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                for (final med in _meds.where((m) => m.needsConfirmation))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _draftCard(med),
                  ),
                if (_events.isEmpty && confirmedCount == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('No medicines added yet.',
                        style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade500)),
                  ),
                for (final event in _events) _eventCard(event),
              ],
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _draftCard(Medication med) {
    return GestureDetector(
      onTap: () => _showConfirmSheet(med),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(med.name, style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
            Text('Tap to review scanned label', style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.orange.shade800)),
          ])),
        ]),
      ),
    );
  }

  Widget _eventCard(MedicationEvent event) {
    final med = _medFor(event.medicationId);
    final taken = event.status != 'scheduled';
    final time = TimeOfDay.fromDateTime(event.scheduledAt.toLocal()).format(context);
    final detailParts = [
      if (med?.strength != null) med!.strength!,
      time,
    ];

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
            Text(med?.name ?? 'Medicine', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
            Text(detailParts.join(' · '), style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500)),
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
                  onPressed: () => _markTaken(event),
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
  }

  Widget _buildHeader(BuildContext context) {
    final recipient = SelectedProfile.instance.careRecipient;
    return Row(children: [
      GestureDetector(
        onTap: () => context.push('/profiles'),
        child: Container(width: 38, height: 38,
          decoration: const BoxDecoration(color: Color(0xFF2BBFB3), shape: BoxShape.circle),
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
      currentIndex: 3,
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
