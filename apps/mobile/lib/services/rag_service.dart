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
}
