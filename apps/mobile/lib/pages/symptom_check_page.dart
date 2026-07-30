import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/observation_service.dart';
import '../services/rag_service.dart';
import '../services/symptom_check_service.dart';
import '../state/selected_profile.dart';
import '../theme.dart';
import '../wav.dart';
import '../widgets/back_button.dart';

const _sampleRate = 16000;
const _numChannels = 1;

/// F1 · Structured symptom check-in (`/symptom-check`).
///
/// Tap-based triage, deliberately not a chatbot: the caregiver picks one of
/// six red-flag symptoms and answers fixed yes/no questions about **the
/// elder**. Urgency is decided by a fixed rule table on the server
/// (symptomTriage.js) — never by a model — because the failure mode of a
/// hallucinated "that sounds fine" here is somebody not calling 119.
///
/// The RAG knowledge base is still used, but only for "what to do while you
/// wait", shown with its sources and clearly separated from the urgency.
class SymptomCheckPage extends StatefulWidget {
  const SymptomCheckPage({super.key});

  @override
  State<SymptomCheckPage> createState() => _SymptomCheckPageState();
}

enum _Step { pickSymptom, questions, note, result }

class _SymptomCheckPageState extends State<SymptomCheckPage> {
  static const _red = Color(0xFFEF3E23);
  static const _amber = Color(0xFFFBBF24);
  static const _teal = Color(0xFF2BBFB3);

  final _service = const SymptomCheckService();
  final _ragService = const RagService();
  final _observationService = const ObservationService();
  final _noteController = TextEditingController();
  final _recorder = AudioRecorder();
  final _pcmChunks = BytesBuilder();
  StreamSubscription<Uint8List>? _pcmSubscription;

  _Step _step = _Step.pickSymptom;
  Symptom? _symptom;
  int _questionIndex = 0;
  final Map<String, bool> _answers = {};

  bool _submitting = false;
  bool _recording = false;
  String? _error;
  SymptomCheckResult? _result;

  RagAnswer? _guidance;
  bool _guidanceLoading = false;

  @override
  void dispose() {
    _noteController.dispose();
    _pcmSubscription?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _pickSymptom(Symptom symptom) {
    setState(() {
      _symptom = symptom;
      _questionIndex = 0;
      _answers.clear();
      _step = _Step.questions;
    });
  }

  void _answer(bool value) {
    final symptom = _symptom!;
    _answers[symptom.questions[_questionIndex].id] = value;
    setState(() {
      if (_questionIndex < symptom.questions.length - 1) {
        _questionIndex++;
      } else {
        _step = _Step.note;
      }
    });
  }

  Future<void> _submit() async {
    final profile = SelectedProfile.instance;
    final householdId = profile.householdId;
    final careRecipientId = profile.careRecipient?.id;
    if (householdId == null || careRecipientId == null) {
      setState(() => _error = 'Choose who you are caring for first.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await _service.submit(
        householdId: householdId,
        careRecipientId: careRecipientId,
        symptomKey: _symptom!.key,
        answers: _answers,
        note: _noteController.text,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _step = _Step.result;
      });
      _loadGuidance(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not save the check-in. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Grounded "while you wait" guidance. Deliberately fired AFTER the
  /// urgency is already on screen and stored — it is extra help, and the
  /// check-in must never depend on it being available.
  Future<void> _loadGuidance(SymptomCheckResult result) async {
    setState(() => _guidanceLoading = true);
    try {
      final answered = _symptom!.questions
          .where((q) => _answers[q.id] == true)
          .map((q) => q.text)
          .join(' ');
      final answer = await _ragService.ask(
        'An older adult being cared for at home has this problem: ${_symptom!.label}. '
        '${answered.isEmpty ? '' : 'Also: $answered '}'
        'What should the home caregiver do right now, before and while help arrives? '
        'Give short practical steps only.',
      );
      if (!mounted) return;
      setState(() => _guidance = answer);
    } catch (_) {
      // Silent: the urgency and the action line above are what matter, and
      // they are already on screen. No alarming error for optional extras.
    } finally {
      if (mounted) setState(() => _guidanceLoading = false);
    }
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    _pcmChunks.clear();
    // Same raw-PCM streaming path as the daily voice log (see
    // prototype_log_page.dart) — one recording pipeline, not two.
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
      // Goes through the existing voice-log pipeline unchanged: it is
      // transcribed, translated and extracted server-side and lands as its
      // own observation for the same elder on the same day, next to this
      // check-in. No second speech pipeline.
      await _observationService.submitVoiceLog(
        wrapPcmAsWav(pcmData, sampleRate: _sampleRate, numChannels: _numChannels),
        householdId: householdId,
        careRecipientId: careRecipientId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording saved as a note.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the recording. You can type instead.')),
      );
    }
  }

  Future<void> _call119() async {
    await launchUrl(Uri(scheme: 'tel', path: '119'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 12),
            if (_step != _Step.result) const AppBackButton(),
            const SizedBox(height: 12),
            switch (_step) {
              _Step.pickSymptom => _buildPickSymptom(),
              _Step.questions => _buildQuestion(),
              _Step.note => _buildNote(),
              _Step.result => _buildResult(),
            },
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  Widget _buildPickSymptom() {
    final name = SelectedProfile.instance.careRecipient?.displayName ?? 'her';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('What are you worried about?',
          style: AppTextStyles.heading(fontSize: 30).copyWith(color: Colors.black)),
      const SizedBox(height: 8),
      Text('Pick the one thing about $name that worries you most right now.',
          style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600, height: 1.5)),
      const SizedBox(height: 20),
      ...kSymptoms.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => _pickSymptom(s),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.label, style: AppTextStyles.bodyMedium(fontSize: 17).copyWith(color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(s.hint, style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade500)),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 22),
                ]),
              ),
            ),
          )),
      const SizedBox(height: 8),
      Text('If something else is wrong, use the daily log instead.',
          style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500)),
    ]);
  }

  Widget _buildQuestion() {
    final symptom = _symptom!;
    final question = symptom.questions[_questionIndex];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${symptom.label.toUpperCase()} · ${_questionIndex + 1} OF ${symptom.questions.length}',
          style: AppTextStyles.bodyMedium(fontSize: 11)
              .copyWith(color: Colors.grey.shade500, letterSpacing: 0.8)),
      const SizedBox(height: 16),
      Text(question.text, style: AppTextStyles.heading(fontSize: 26).copyWith(color: Colors.black, height: 1.3)),
      const SizedBox(height: 32),
      Row(children: [
        Expanded(child: _AnswerButton(label: 'Yes', filled: true, onTap: () => _answer(true))),
        const SizedBox(width: 12),
        Expanded(child: _AnswerButton(label: 'No', filled: false, onTap: () => _answer(false))),
      ]),
      const SizedBox(height: 16),
      Text('If you are not sure, answer No. You can add details next.',
          style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500)),
    ]);
  }

  Widget _buildNote() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Anything else?', style: AppTextStyles.heading(fontSize: 30).copyWith(color: Colors.black)),
      const SizedBox(height: 8),
      Text('Optional. Type it, or hold the microphone and say it in your own language.',
          style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600, height: 1.5)),
      const SizedBox(height: 18),
      TextField(
        controller: _noteController,
        maxLines: 4,
        style: AppTextStyles.body(fontSize: 15).copyWith(color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'She was fine this morning...',
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
      const SizedBox(height: 14),
      GestureDetector(
        onLongPressStart: (_) => _startRecording(),
        onLongPressEnd: (_) => _stopRecordingAndSubmit(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _recording ? _red : Colors.white,
            border: Border.all(color: _recording ? _red : Colors.grey.shade300, width: 1.5),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.mic_none_rounded, size: 20, color: _recording ? Colors.white : Colors.black87),
            const SizedBox(width: 8),
            Text(_recording ? 'Recording — let go to save' : 'Hold to speak',
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
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _red.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            elevation: 0,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text('See what to do',
                  style: AppTextStyles.bodyMedium(fontSize: 17).copyWith(color: Colors.white)),
        ),
      ),
    ]);
  }

  Widget _buildResult() {
    final result = _result!;
    final (Color color, String title) = switch (result.urgency) {
      'emergency' => (_red, 'Call 119 now'),
      'today' => (_amber, 'See a doctor today'),
      _ => (_teal, 'Keep watching her'),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.heading(fontSize: 26).copyWith(color: Colors.black)),
          const SizedBox(height: 8),
          Text(result.action,
              style: AppTextStyles.body(fontSize: 15).copyWith(color: Colors.black87, height: 1.5)),
        ]),
      ),

      if (result.isEmergency) ...[
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _call119,
            icon: const Icon(Icons.phone_rounded, size: 20),
            label: Text('Call 119',
                style: AppTextStyles.bodyMedium(fontSize: 17).copyWith(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              elevation: 0,
            ),
          ),
        ),
      ],

      const SizedBox(height: 24),

      // ── What the family sees ────────────────────────────────────────
      Text('The family sees this', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(result.translatedText ?? result.summaryText,
              style: AppTextStyles.body(fontSize: 15).copyWith(color: Colors.black87, height: 1.6)),
          if (result.translatedText == null) ...[
            const SizedBox(height: 8),
            Text('Saved, but could not be translated right now.',
                style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade600)),
          ],
        ]),
      ),
      const SizedBox(height: 6),
      Text('Already saved to her record.',
          style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade500)),

      // ── Grounded guidance ───────────────────────────────────────────
      if (_guidanceLoading) ...[
        const SizedBox(height: 24),
        Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text('Looking up what to do while you wait...',
              style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade600)),
        ]),
      ],
      if (_guidance != null) ...[
        const SizedBox(height: 24),
        Text('While you wait', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_guidance!.answer,
                style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.black87, height: 1.6)),
            if (_guidance!.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'From: ${_guidance!.sources.map((s) => s.publisher).toSet().join(', ')}',
                style: AppTextStyles.body(fontSize: 11).copyWith(color: Colors.grey.shade500),
              ),
            ],
          ]),
        ),
      ],

      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => context.go('/home'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: Colors.black87, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          ),
          child: Text('Done', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
        ),
      ),
    ]);
  }
}

class _AnswerButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _AnswerButton({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: filled ? Colors.black87 : Colors.white,
          border: Border.all(color: Colors.black87, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(label,
              style: AppTextStyles.bodyMedium(fontSize: 19)
                  .copyWith(color: filled ? Colors.white : Colors.black87)),
        ),
      ),
    );
  }
}
