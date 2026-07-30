import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import 'auth_token.dart';

class CareRecipient {
  final String id;
  final String displayName;
  final int? age;
  final List<String> preferredLanguages;
  final List<String> conditions;

  CareRecipient({
    required this.id,
    required this.displayName,
    required this.age,
    required this.preferredLanguages,
    required this.conditions,
  });

  factory CareRecipient.fromJson(Map<String, dynamic> json) {
    final careProfile = json['careProfile'] as Map<String, dynamic>? ?? {};
    return CareRecipient(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      age: careProfile['age'] as int?,
      preferredLanguages: List<String>.from(json['preferredLanguages'] as List? ?? []),
      conditions: List<String>.from(careProfile['conditions'] as List? ?? []),
    );
  }

  /// Two-letter initials for the avatar circle, e.g. "Lola Rosa" -> "LR".
  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class ProfileService {
  const ProfileService();

  /// Finds or creates the caller's household. Idempotent — safe to call
  /// every app start.
  Future<String> bootstrapHousehold() async {
    final token = await getIdToken();
    final res = await http.post(
      Uri.parse('$apiBaseUrl/households/bootstrap'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to bootstrap household: ${res.body}');
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['householdId'] as String;
  }

  Future<List<CareRecipient>> listCareRecipients(String householdId) async {
    final token = await getIdToken();
    final res = await http.get(
      Uri.parse('$apiBaseUrl/households/$householdId/care-recipients'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to list care recipients: ${res.body}');
    }
    final list = (jsonDecode(res.body) as Map<String, dynamic>)['careRecipients'] as List;
    return list.map((r) => CareRecipient.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<CareRecipient> createCareRecipient(
    String householdId, {
    required String displayName,
    int? age,
    List<String> preferredLanguages = const [],
    List<String> conditions = const [],
  }) async {
    final token = await getIdToken();
    final res = await http.post(
      Uri.parse('$apiBaseUrl/households/$householdId/care-recipients'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'displayName': displayName,
        'age': age,
        'preferredLanguages': preferredLanguages,
        'conditions': conditions,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to create care recipient: ${res.body}');
    }
    final id = (jsonDecode(res.body) as Map<String, dynamic>)['careRecipientId'] as String;
    return CareRecipient(
      id: id,
      displayName: displayName,
      age: age,
      preferredLanguages: preferredLanguages,
      conditions: conditions,
    );
  }
}
