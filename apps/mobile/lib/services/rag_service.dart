import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import 'auth_token.dart';

class RagSource {
  final int n;
  final String title;
  final String publisher;
  final String url;
  final String excerpt;

  RagSource({
    required this.n,
    required this.title,
    required this.publisher,
    required this.url,
    required this.excerpt,
  });

  factory RagSource.fromJson(Map<String, dynamic> json) => RagSource(
        n: json['n'] as int,
        title: json['title'] as String,
        publisher: json['publisher'] as String,
        url: json['url'] as String,
        excerpt: json['excerpt'] as String,
      );
}

class RagAnswer {
  final String answer;
  final List<RagSource> sources;

  RagAnswer({required this.answer, required this.sources});
}

/// Result of a household/care-recipient-scoped symptom check — unlike the
/// bare [RagAnswer], this always knows whether family/doctor were flagged.
class SymptomCheckResult {
  final String symptomCheckId;
  final String answer;
  final List<RagSource> sources;
  final String urgency; // none|information|attention|urgent|emergency
  final String familySummaryZh;
  final bool flaggedToFamily;

  SymptomCheckResult({
    required this.symptomCheckId,
    required this.answer,
    required this.sources,
    required this.urgency,
    required this.familySummaryZh,
    required this.flaggedToFamily,
  });
}

class RagService {
  const RagService();

  /// Asks apps/api's RAG endpoint a question. Answers are grounded in
  /// real cited sources (Taiwan health authority / WHO / research docs —
  /// see apps/api/src/rag/sources/) rather than the model's own guesses;
  /// see PLAN.md's "Backend: RAG Component" section for how that's enforced.
  Future<RagAnswer> ask(String question) async {
    final token = await getIdToken();

    final res = await http.post(
      Uri.parse('$apiBaseUrl/rag/ask'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'question': question}),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to get an answer: ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final sources = (body['sources'] as List)
        .map((s) => RagSource.fromJson(s as Map<String, dynamic>))
        .toList();

    return RagAnswer(answer: body['answer'] as String, sources: sources);
  }

  /// Symptom-checker: RAG-grounded, answered directly in [locale], and
  /// urgency-classified — flags family/doctor with a Mandarin summary when
  /// urgency comes back urgent/emergency. Unlike [ask], this is scoped to
  /// a specific care recipient since the flag has to reach the right family.
  Future<SymptomCheckResult> checkSymptom(
    String message, {
    required String householdId,
    required String careRecipientId,
    required String locale,
  }) async {
    final token = await getIdToken();

    final res = await http.post(
      Uri.parse('$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/symptom-check'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'message': message, 'locale': locale}),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to check symptom: ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final sources = (body['sources'] as List)
        .map((s) => RagSource.fromJson(s as Map<String, dynamic>))
        .toList();

    return SymptomCheckResult(
      symptomCheckId: body['symptomCheckId'] as String,
      answer: body['answer'] as String,
      sources: sources,
      urgency: body['urgency'] as String,
      familySummaryZh: body['familySummaryZh'] as String,
      flaggedToFamily: body['flaggedToFamily'] as bool,
    );
  }
}
