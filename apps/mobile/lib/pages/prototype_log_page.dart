import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';

import '../state/selected_profile.dart';
import '../services/observation_service.dart';
import '../theme.dart';
import '../wav.dart';
import '../week_key.dart';

const _sampleRate = 16000;
const _numChannels = 1;

class PrototypeLogPage extends StatefulWidget {
  const PrototypeLogPage({super.key});
  @override
  State<PrototypeLogPage> createState() => _PrototypeLogPageState();
}

class _PrototypeLogPageState extends State<PrototypeLogPage> {
  static const _bg = Color(0xFFF5F0E8);
  static const _teal = Color(0xFF2BBFB3);
  static const _amber = Color(0xFFFBBF24);
  static const _red = Color(0xFFEF3E23);
  bool _isHolding = false;
  bool _isProcessing = false;

  final _recorder = AudioRecorder();
  final _observationService = const ObservationService();
  final _pcmChunks = BytesBuilder();
  StreamSubscription<Uint8List>? _pcmSubscription;

  @override
  void dispose() {
    _pcmSubscription?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;

    _pcmChunks.clear();

    // Raw PCM streaming (not start()+a file path) so this works on every
    // platform, including web — record's path-based mode needs a real
    // filesystem (via path_provider), which web doesn't have; a temp-file
    // path there throws immediately. The container-less PCM chunks get
    // wrapped into a proper .wav (see wav.dart) once recording stops and
    // the total length is known.
    //
    // pcm16bits, not wav/AAC: Google Cloud Speech-to-Text (apps/api)
    // doesn't support AAC/M4A at all, and streaming can't emit a WAV
    // container mid-recording anyway (its header needs the final byte
    // count). Sample rate must match transcribe.js's sampleRateHertz.
    final stream = await _recorder.startStream(
      const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: _sampleRate, numChannels: _numChannels),
    );
    _pcmSubscription = stream.listen(_pcmChunks.add);
    setState(() => _isHolding = true);
  }

  Future<void> _stopRecordingAndSubmit() async {
    await _recorder.stop();
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;

    final pcmData = _pcmChunks.takeBytes();
    setState(() {
      _isHolding = false;
      _isProcessing = pcmData.isNotEmpty;
    });
    if (pcmData.isEmpty) return;

    final profile = SelectedProfile.instance;
    final householdId = profile.householdId;
    final careRecipientId = profile.careRecipient?.id;
    if (householdId == null || careRecipientId == null) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a profile before logging.')),
      );
      return;
    }

    try {
      final wavBytes = wrapPcmAsWav(pcmData, sampleRate: _sampleRate, numChannels: _numChannels);
      // Returns as soon as processing has started server-side, not once
      // it finishes (see observation_service.dart) — no category summary
      // to show yet, just confirm the recording was received. The chart
      // below updates on its own via the weeklySummaries listener once
      // the background job's rollup completes.
      await _observationService.submitVoiceLog(
        wavBytes,
        householdId: householdId,
        careRecipientId: careRecipientId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged — processing...')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save voice log: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _cancelRecording() async {
    await _recorder.cancel();
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    _pcmChunks.clear();
    setState(() => _isHolding = false);
  }

  // Neutral placeholder shown while the real weeklySummaries doc is loading
  // or doesn't exist yet (e.g. before the first voice log of the week).
  static const _neutralWeek = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5];

  Stream<DocumentSnapshot<Map<String, dynamic>>>? get _weeklySummaryStream {
    final profile = SelectedProfile.instance;
    final householdId = profile.householdId;
    final careRecipientId = profile.careRecipient?.id;
    if (householdId == null || careRecipientId == null) return null;

    return FirebaseFirestore.instance
        .doc(
          'households/$householdId/careRecipients/$careRecipientId/weeklySummaries/${currentWeekKey()}',
        )
        .snapshots();
  }

  static List<double> _series(Map<String, dynamic>? trendSeries, String key) {
    final raw = trendSeries?[key] as List?;
    if (raw == null || raw.isEmpty) return _neutralWeek;
    return raw.map((v) => (v as num).toDouble()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SelectedProfile.instance,
      builder: (context, _) {
        final name = SelectedProfile.instance.careRecipient?.displayName ?? 'them';
        return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            const _Header(),
            const SizedBox(height: 28),
            Text('How did $name sleep,\neat and feel today?',
                style: AppTextStyles.heading(fontSize: 26).copyWith(color: Colors.black)),
            const SizedBox(height: 8),
            Text('Speak in your own language. One minute\nis enough.',
                style: AppTextStyles.body(fontSize: 14).copyWith(color: _teal, height: 1.5)),
            const SizedBox(height: 32),
            Center(child: Column(children: [
              GestureDetector(
                onLongPressStart: _isProcessing ? null : (_) => _startRecording(),
                onLongPressEnd: _isProcessing ? null : (_) => _stopRecordingAndSubmit(),
                onLongPressCancel: _isProcessing ? null : () => _cancelRecording(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _isHolding ? 88 : 80, height: _isHolding ? 88 : 80,
                  decoration: BoxDecoration(
                    color: _isProcessing
                        ? Colors.grey.shade400
                        : _isHolding
                            ? _red
                            : _amber,
                    shape: BoxShape.circle,
                    boxShadow: _isHolding
                        ? [BoxShadow(color: _red.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 4)]
                        : [],
                  ),
                  child: _isProcessing
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : const Icon(Icons.mic_rounded, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isProcessing ? 'Saving...' : _isHolding ? 'Recording...' : 'Hold to speak',
                style: AppTextStyles.body(fontSize: 13).copyWith(
                  color: _isHolding ? _red : Colors.grey.shade600,
                  fontWeight: _isHolding ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ])),
            const SizedBox(height: 32),
            Text('LAST 7 DAYS', style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(color: Colors.grey.shade500, letterSpacing: 0.8)),
            const SizedBox(height: 16),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _weeklySummaryStream,
              builder: (context, snapshot) {
                final trendSeries =
                    snapshot.data?.data()?['trendSeries'] as Map<String, dynamic>?;
                final sleepData = _series(trendSeries, 'sleep');
                final foodData = _series(trendSeries, 'food');
                final moodData = _series(trendSeries, 'mood');

                // Week series is anchored to Sunday (index 0). Today's index is
                // how many days since the most recent Sunday (Sun=0, Mon=1 … Sat=6).
                // Dart weekday: Mon=1…Sun=7 → Sun%7==0, others match JS getUTCDay.
                final todayIndex = (DateTime.now().toUtc().weekday % 7)
                    .clamp(0, sleepData.length - 1);

                return Column(children: [
                  _ChartRow(
                    label: 'Sleep',
                    unit: 'quality',
                    value: '${(sleepData[todayIndex] * 100).round()}%',
                    data: sleepData,
                    color: _amber,
                    todayIndex: todayIndex,
                  ),
                  const SizedBox(height: 14),
                  _ChartRow(
                    label: 'Food\neaten',
                    unit: 'of usual',
                    value: '${(foodData[todayIndex] * 100).round()}%',
                    data: foodData,
                    color: _teal,
                    todayIndex: todayIndex,
                  ),
                  const SizedBox(height: 14),
                  _ChartRow(
                    label: 'Mood',
                    unit: 'score',
                    value: '${(moodData[todayIndex] * 100).round()}%',
                    data: moodData,
                    color: _teal,
                    todayIndex: todayIndex,
                  ),
                ]);
              },
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
      bottomNavigationBar: const _BottomNav(activeIndex: 2),
    );
      },
    );
  }
}

class _ChartRow extends StatelessWidget {
  final String label, unit, value;
  final List<double> data;
  final Color color;
  final int todayIndex;
  const _ChartRow({required this.label, required this.unit, required this.value, required this.data, required this.color, required this.todayIndex});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      SizedBox(width: 52, child: Text(label, style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade600))),
      Expanded(child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(data.length, (i) {
          final isToday = i == todayIndex;
          return Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              height: 40 * data[i],
              decoration: BoxDecoration(
                color: isToday ? color : color.withValues(alpha: 0.25 + i * 0.05),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ));
        }),
      )),
      const SizedBox(width: 8),
      SizedBox(width: 44, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87)),
        Text(unit, style: AppTextStyles.body(fontSize: 10).copyWith(color: Colors.grey.shade500)),
      ])),
    ]);
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();
  static const _teal = Color(0xFF2BBFB3);

  @override
  Widget build(BuildContext context) {
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
}

class _BottomNav extends StatelessWidget {
  final int activeIndex;
  const _BottomNav({required this.activeIndex});
  static const _red = Color(0xFFEF3E23);
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: activeIndex,
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
