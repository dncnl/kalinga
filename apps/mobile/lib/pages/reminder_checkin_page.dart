import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';

import '../services/observation_service.dart';
import '../services/reminder_service.dart';
import '../state/selected_profile.dart';
import '../theme.dart';
import '../wav.dart';
import '../widgets/back_button.dart';

const _sampleRate = 16000;
const _numChannels = 1;

/// F3 · Reminder-triggered check-in (`/checkin/:eventId`).
///
/// Replaces the hardcoded prototype check-in. An Eating or Exercise
/// reminder opens a short category-specific question set whose answers feed
/// the SAME rollups as the voice log (`appetiteLevel`, mobility) — new
/// input UI over existing backend behaviour, not a second analytics path.
/// Any other label just completes, with an optional note.
///
/// Voice alternative: hold the mic and speak instead of tapping. That goes
/// through the existing voice-log pipeline unchanged rather than forking a
/// second speech path.
class ReminderCheckinPage extends StatefulWidget {
  final String eventId;
  final ReminderEvent? event;

  const ReminderCheckinPage({super.key, required this.eventId, this.event});

  @override
  State<ReminderCheckinPage> createState() => _ReminderCheckinPageState();
}

class _ReminderCheckinPageState extends State<ReminderCheckinPage> {
  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);

  final _service = const ReminderService();
  final _observationService = const ObservationService();
  final _noteController = TextEditingController();
  final _recorder = AudioRecorder();
  final _pcmChunks = BytesBuilder();
  StreamSubscription<Uint8List>? _pcmSubscription;

  final Map<String, String> _answers = {};
  bool _saving = false;
  bool _recording = false;
  String? _error;

  ReminderEvent? get _event => widget.event;

  @override
  void dispose() {
    _noteController.dispose();
    _pcmSubscription?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    _pcmChunks.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: _sampleRate, numChannels: _numChannels),
    );
    _pcmSubscription = stream.listen(_pcmChunks.add);
    setState(() => _recording = true);
  }

  Future<void> _stopRecordingAndSubmit() async {
    await _recorder.stop();
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    final pcmData = _pcmChunks.takeBytes();
    setState(() => _recording = false);
    if (pcmData.isEmpty) return;

    final profile = SelectedProfile.instance;
    final householdId = profile.householdId;
    final careRecipientId = profile.careRecipient?.id;
    if (householdId == null || careRecipientId == null) return;

    try {
      await _observationService.submitVoiceLog(
        wrapPcmAsWav(pcmData, sampleRate: _sampleRate, numChannels: _numChannels),
        householdId: householdId,
        careRecipientId: careRecipientId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording saved.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the recording. You can tap the answers instead.')),
      );
    }
  }

  Future<void> _save({bool skipped = false}) async {
    final profile = SelectedProfile.instance;
    final householdId = profile.householdId;
    final careRecipientId = profile.careRecipient?.id;
    if (householdId == null || careRecipientId == null) {
      setState(() => _error = 'Choose who you are caring for first.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.complete(
        householdId: householdId,
        careRecipientId: careRecipientId,
        eventId: widget.eventId,
        answers: skipped ? const {} : _answers,
        note: skipped ? null : _noteController.text,
        status: skipped ? 'skipped' : 'completed',
      );
      if (!mounted) return;
      // pop, not go('/home'): the home tile awaits this push and reloads
      // when it resolves. go() replaces the stack instead, so the awaited
      // future never completes and home keeps showing the reminder as
      // pending until the next cold start — the write had actually landed.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not save it. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final questions = event == null ? const <CheckinQuestion>[] : checkinFormFor(event.taskCategory);
    final title = event?.taskTitle ?? 'Check-in';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 12),
            const AppBackButton(),
            const SizedBox(height: 16),

            Text(title, style: AppTextStyles.heading(fontSize: 30).copyWith(color: Colors.black)),
            const SizedBox(height: 6),
            Text(
              questions.isEmpty
                  ? 'Mark it done, and add a note if you want to.'
                  : 'How did it go? Tap the answers.',
              style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 22),

            for (final question in questions) ...[
              Text(question.text,
                  style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.black87)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final option in question.options)
                  GestureDetector(
                    onTap: () => setState(() => _answers[question.id] = option.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _answers[question.id] == option.id ? _teal : Colors.white,
                        border: Border.all(
                            color: _answers[question.id] == option.id ? _teal : Colors.grey.shade300,
                            width: 1.5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(option.label,
                          style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(
                              color: _answers[question.id] == option.id ? Colors.white : Colors.black87)),
                    ),
                  ),
              ]),
              const SizedBox(height: 22),
            ],

            Text('Anything to add?',
                style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.black87)),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: AppTextStyles.body(fontSize: 15).copyWith(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Optional',
                hintStyle: AppTextStyles.body(fontSize: 15).copyWith(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _teal, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),

            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecordingAndSubmit(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: _recording ? _red : Colors.white,
                  border: Border.all(color: _recording ? _red : Colors.grey.shade300, width: 1.5),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.mic_none_rounded, size: 20, color: _recording ? Colors.white : Colors.black87),
                  const SizedBox(width: 8),
                  Text(_recording ? 'Recording — let go to save' : 'Or hold to speak',
                      style: AppTextStyles.bodyMedium(fontSize: 15)
                          .copyWith(color: _recording ? Colors.white : Colors.black87)),
                ]),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: AppTextStyles.body(fontSize: 13).copyWith(color: _red)),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : () => _save(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _red.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text('Save', style: AppTextStyles.bodyMedium(fontSize: 17).copyWith(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _saving ? null : () => _save(skipped: true),
                child: Text('Skip this one',
                    style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.grey.shade600)),
              ),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}
