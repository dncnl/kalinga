import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import 'auth_token.dart';

/// F1 · Structured symptom check-in.
///
/// The question tree is mirrored here so the UI can render without a round
/// trip, but **the server is authoritative on urgency** — it recomputes the
/// assessment from the answers rather than trusting anything sent from the
/// phone (see apps/api/src/lib/symptomTriage.js). If these two ever drift,
/// the server's answer is the one that reaches the family.
class SymptomQuestion {
  final String id;
  final String text;

  const SymptomQuestion({required this.id, required this.text});
}

class Symptom {
  final String key;
  final String label;
  final String hint;
  final List<SymptomQuestion> questions;

  const Symptom({
    required this.key,
    required this.label,
    required this.hint,
    required this.questions,
  });
}

/// The six red flags that change what a caregiver should do in the next
/// hour. Anything else belongs in the general voice log.
const kSymptoms = <Symptom>[
  Symptom(
    key: 'breathing',
    label: 'Hard to breathe',
    hint: 'Breathing fast, gasping, or short of breath',
    questions: [
      SymptomQuestion(id: 'atRest', text: 'Is she struggling to breathe even while sitting still?'),
      SymptomQuestion(id: 'blueLips', text: 'Are her lips, face, or fingertips turning blue or grey?'),
      SymptomQuestion(id: 'cannotSpeak', text: 'Is she too breathless to finish a sentence?'),
    ],
  ),
  Symptom(
    key: 'chestPain',
    label: 'Chest pain',
    hint: 'Pain, pressure, or tightness in the chest',
    questions: [
      SymptomQuestion(id: 'now', text: 'Is the chest pain happening right now?'),
      SymptomQuestion(id: 'spreading', text: 'Does the pain spread to the arm, neck, or jaw?'),
      SymptomQuestion(id: 'sweatingPale', text: 'Is she sweating, very pale, or vomiting?'),
    ],
  ),
  Symptom(
    key: 'fall',
    label: 'She fell down',
    hint: 'A fall, slip, or found on the floor',
    questions: [
      SymptomQuestion(id: 'hitHead', text: 'Did she hit her head?'),
      SymptomQuestion(id: 'cannotStand', text: 'Is she unable to stand or move an arm or leg?'),
      SymptomQuestion(id: 'severePain', text: 'Is she in severe pain, or is a limb bent oddly?'),
    ],
  ),
  Symptom(
    key: 'confusion',
    label: 'More confused than usual',
    hint: 'Not making sense, not recognising people',
    questions: [
      SymptomQuestion(id: 'suddenToday', text: 'Did this start suddenly, today?'),
      SymptomQuestion(id: 'faceArmSpeech', text: 'Is her face drooping, one arm weak, or her speech slurred?'),
      SymptomQuestion(id: 'hardToWake', text: 'Is she very sleepy or hard to wake?'),
    ],
  ),
  Symptom(
    key: 'fever',
    label: 'Fever / very hot',
    hint: 'Hot to touch, shivering, or a high temperature',
    questions: [
      SymptomQuestion(id: 'hardToWake', text: 'Is she very sleepy or hard to wake?'),
      SymptomQuestion(id: 'breathingFast', text: 'Is she breathing much faster than usual?'),
      SymptomQuestion(id: 'moreThanTwoDays', text: 'Has the fever lasted more than two days?'),
    ],
  ),
  Symptom(
    key: 'notEating',
    label: 'Not eating or drinking',
    hint: 'Refusing food or drink, or eating far less',
    questions: [
      SymptomQuestion(id: 'noDrinkOneDay', text: 'Has she had almost nothing to drink for a whole day?'),
      SymptomQuestion(id: 'weakDizzy', text: 'Is she very weak, dizzy, or confused with it?'),
      SymptomQuestion(id: 'cannotSwallow', text: 'Does she cough or choke when swallowing?'),
    ],
  ),
];

/// What the server decided. `urgency` is one of emergency / today / watch.
class SymptomCheckResult {
  final String observationId;
  final String urgency;
  final String action;
  final List<String> concerns;
  final String summaryText;

  /// Null when translation failed — the check-in is still saved (see the
  /// route), so the UI shows the original text rather than an error.
  final String? translatedText;

  const SymptomCheckResult({
    required this.observationId,
    required this.urgency,
    required this.action,
    required this.concerns,
    required this.summaryText,
    required this.translatedText,
  });

  bool get isEmergency => urgency == 'emergency';
  bool get isToday => urgency == 'today';

  factory SymptomCheckResult.fromJson(Map<String, dynamic> json) => SymptomCheckResult(
        observationId: json['observationId'] as String,
        urgency: json['urgency'] as String,
        action: json['action'] as String,
        concerns: List<String>.from(json['concerns'] as List? ?? const []),
        summaryText: json['summaryText'] as String,
        translatedText: json['translatedText'] as String?,
      );
}

class SymptomCheckService {
  const SymptomCheckService();

  Future<SymptomCheckResult> submit({
    required String householdId,
    required String careRecipientId,
    required String symptomKey,
    required Map<String, bool> answers,
    String? note,
  }) async {
    final token = await getIdToken();
    final res = await http.post(
      Uri.parse(
        '$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/observations/symptom-check',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'symptomKey': symptomKey,
        'answers': answers,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'locale': demoLocale,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Could not save the check-in: ${res.body}');
    }
    return SymptomCheckResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
