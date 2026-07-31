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

/// A soft, deterministic nudge toward the tap-based symptom check
/// (`/symptom-check`) — never an urgency call. See
/// apps/api/src/lib/chatConcern.js: it only ever suggests the tap-based flow
/// or 119, it never itself decides how urgent something is.
class RagConcern {
  final String symptomKey;
  final String label;
  final String message;

  RagConcern({required this.symptomKey, required this.label, required this.message});

  factory RagConcern.fromJson(Map<String, dynamic> json) => RagConcern(
        symptomKey: json['symptomKey'] as String,
        label: json['label'] as String,
        message: json['message'] as String,
      );
}

class RagAnswer {
  final String answer;
  final List<RagSource> sources;

  /// Only populated by [RagService.askForRecipient] — the household-scoped
  /// call. Null for the unscoped [ask].
  final String? translatedText;
  final RagConcern? concern;

  RagAnswer({
    required this.answer,
    required this.sources,
    this.translatedText,
    this.concern,
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

  /// F1 · Free-text chat, scoped to a care recipient. Coexists with the
  /// tap-based triage in symptom_check_page.dart — this endpoint never
  /// decides urgency itself (see apps/api/src/routes/rag.js); it records
  /// the exchange with a Mandarin translation for the family and returns an
  /// optional [RagConcern] nudge toward the tap-based flow.
  Future<RagAnswer> askForRecipient({
    required String householdId,
    required String careRecipientId,
    required String question,
    required String locale,
  }) async {
    final token = await getIdToken();

    final res = await http.post(
      Uri.parse(
        '$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/rag/ask',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'question': question, 'locale': locale}),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to get an answer: ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final sources = (body['sources'] as List)
        .map((s) => RagSource.fromJson(s as Map<String, dynamic>))
        .toList();

    return RagAnswer(
      answer: body['answer'] as String,
      sources: sources,
      translatedText: body['translatedText'] as String?,
      concern: body['concern'] == null
          ? null
          : RagConcern.fromJson(body['concern'] as Map<String, dynamic>),
    );
  }
}
