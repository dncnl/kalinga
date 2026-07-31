import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../state/selected_profile.dart';
import '../services/observation_service.dart';
import '../theme.dart';
import '../wav.dart';
import '../week_key.dart';
import '../widgets/app_header.dart';
import '../widgets/kalinga_bottom_nav.dart';

const _sampleRate = 16000;
const _numChannels = 1;

class PrototypeLogPage extends StatefulWidget {
  const PrototypeLogPage({super.key});
  @override
  State<PrototypeLogPage> createState() => _PrototypeLogPageState();
}

class _PrototypeLogPageState extends State<PrototypeLogPage> {
  static const _bg = Color(0xFFFFFFFF);
  static const _teal = Color(0xFF2BBFB3);
  static const _amber = AppColors.amber;
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("We couldn't save your voice log. Check your connection and try again.")),
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
            const AppPageHeader(),
            const SizedBox(height: 28),
            Text('How did $name sleep,\neat and feel today?',
                style: AppTextStyles.heading(fontSize: 26).copyWith(color: Colors.black)),
            const SizedBox(height: 8),
            Text('Speak in your own language. One minute\nis enough.',
                style: AppTextStyles.body(fontSize: 14).copyWith(color: _teal, height: 1.5)),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isHolding)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: _amber.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                      ),
                    GestureDetector(
                      onLongPressStart: _isProcessing ? null : (_) => _startRecording(),
                      onLongPressEnd: _isProcessing ? null : (_) => _stopRecordingAndSubmit(),
                      onLongPressCancel: _isProcessing ? null : () => _cancelRecording(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _isHolding ? 120 : 112,
                        height: _isHolding ? 120 : 112,
                        decoration: BoxDecoration(
                          color: _isProcessing
                              ? Colors.grey.shade400
                              : _isHolding
                                  ? _red
                                  : _amber,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isHolding ? _red : _amber).withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: _isProcessing
                            ? const Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                              )
                            : const Icon(Icons.mic_rounded, color: Colors.white, size: 44),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _isProcessing ? 'Saving...' : _isHolding ? 'Listening…' : 'Hold to speak',
                  style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(
                    color: _isHolding ? _red : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isProcessing
                      ? 'Saving your log…'
                      : _isHolding
                          ? 'Release when you finish'
                          : 'e.g. "She ate well but seemed anxious after lunch"',
                  style: AppTextStyles.body(fontSize: 12).copyWith(color: AppColors.mutedText),
                ),
              ]),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'How the week looked',
                  style: AppTextStyles.bodyMedium(fontSize: 17).copyWith(color: Colors.black87),
                ),
                Text(
                  'Last 7 days',
                  style: AppTextStyles.body(fontSize: 12).copyWith(color: AppColors.mutedText),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _weeklySummaryStream,
              builder: (context, snapshot) {
                final trendSeries =
                    snapshot.data?.data()?['trendSeries'] as Map<String, dynamic>?;
                final sleepData = _series(trendSeries, 'sleep');
                final foodData = _series(trendSeries, 'food');
                final moodData = _series(trendSeries, 'mood');

                final todayIndex = (DateTime.now().toUtc().weekday % 7)
                    .clamp(0, sleepData.length - 1);

                final metrics = [
                  (
                    label: 'Sleep',
                    icon: Icons.bedtime_outlined,
                    data: sleepData,
                  ),
                  (
                    label: 'Food',
                    icon: Icons.restaurant_outlined,
                    data: foodData,
                  ),
                  (
                    label: 'Mood',
                    icon: Icons.sentiment_satisfied_outlined,
                    data: moodData,
                  ),
                ];

                final dayInitials = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Column(
                    children: [
                      for (int m = 0; m < metrics.length; m++) ...[
                        if (m > 0) const SizedBox(height: 20),
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(metrics[m].icon, size: 16, color: AppColors.mutedText),
                                    const SizedBox(width: 6),
                                    Text(
                                      metrics[m].label,
                                      style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Today: ${(metrics[m].data[todayIndex] * 100).round()}%',
                                  style: AppTextStyles.body(fontSize: 12).copyWith(color: AppColors.mutedText),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(7, (i) {
                                final isToday = i == todayIndex;
                                final val = metrics[m].data[i];
                                final (color, fraction) = val >= 0.70
                                    ? (_teal, 1.0)
                                    : val >= 0.40
                                        ? (_amber, 0.62)
                                        : (_red, 0.32);
                                final barColor = isToday ? color : color.withValues(alpha: 0.45);
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: Column(
                                      children: [
                                        SizedBox(
                                          height: 48,
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Container(
                                              height: 48 * fraction,
                                              decoration: BoxDecoration(
                                                color: barColor,
                                                borderRadius: BorderRadius.circular(4),
                                                border: isToday
                                                    ? Border.all(color: Colors.black.withValues(alpha: 0.15), width: 1.5)
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          dayInitials[i],
                                          style: AppTextStyles.body(fontSize: 10).copyWith(
                                            color: isToday ? Colors.black87 : AppColors.mutedText,
                                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      Divider(height: 1, color: Colors.grey.shade200),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final entry in [
                            ('Good', _teal),
                            ('Fair', _amber),
                            ('Poor', _red),
                          ]) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: entry.$2, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              entry.$1,
                              style: AppTextStyles.body(fontSize: 11).copyWith(color: AppColors.mutedText),
                            ),
                            if (entry.$1 != 'Poor') const SizedBox(width: 16),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
      bottomNavigationBar: const KalingaBottomNav(activeIndex: 2),
    );
      },
    );
  }
}
