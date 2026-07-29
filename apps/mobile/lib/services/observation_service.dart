import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../week_key.dart';

class ObservationService {
  const ObservationService();

  Future<String> _idToken() async {
    var user = FirebaseAuth.instance.currentUser;
    // No real sign-in flow exists yet (see PLAN.md) — anonymous auth is a
    // stopgap so the API's requireAuth middleware has a real token to check.
    user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
    final token = await user?.getIdToken();
    if (token == null) {
      throw Exception('Could not obtain a Firebase ID token');
    }
    return token;
  }

  /// Records → uploads → processes one voice log. Returns the extraction
  /// result (categories, comparisonToUsual, safetyAssessment, etc).
  Future<Map<String, dynamic>> submitVoiceLog(File audioFile) async {
    final token = await _idToken();
    const contentType = 'audio/wav';

    final uploadUrlRes = await http.post(
      Uri.parse(
        '$apiBaseUrl/households/$demoHouseholdId/care-recipients/$demoCareRecipientId/observations/upload-url',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'contentType': contentType}),
    );
    if (uploadUrlRes.statusCode != 200) {
      throw Exception('Failed to get upload URL: ${uploadUrlRes.body}');
    }
    final uploadInfo = jsonDecode(uploadUrlRes.body) as Map<String, dynamic>;
    final observationId = uploadInfo['observationId'] as String;
    final uploadUrl = uploadInfo['uploadUrl'] as String;
    final storagePath = uploadInfo['storagePath'] as String;

    final bytes = await audioFile.readAsBytes();
    final putRes = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (putRes.statusCode != 200) {
      throw Exception('Failed to upload audio: ${putRes.statusCode}');
    }

    final processRes = await http.post(
      Uri.parse(
        '$apiBaseUrl/households/$demoHouseholdId/care-recipients/$demoCareRecipientId/observations/$observationId/process',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'storagePath': storagePath, 'locale': demoLocale}),
    );
    if (processRes.statusCode != 200) {
      throw Exception('Failed to process observation: ${processRes.body}');
    }

    // No scheduler exists yet (see PLAN.md) — trigger the rollup inline so
    // the chart has something fresh to show right after logging.
    await _triggerRollup(token);

    return jsonDecode(processRes.body) as Map<String, dynamic>;
  }

  Future<void> _triggerRollup(String token) async {
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final today = dateKeyOf(DateTime.now());
    await http.post(
      Uri.parse(
        '$apiBaseUrl/households/$demoHouseholdId/care-recipients/$demoCareRecipientId/rollup/daily',
      ),
      headers: headers,
      body: jsonEncode({'dateKey': today}),
    );

    final weekStart = currentWeekStartUtc();
    await http.post(
      Uri.parse(
        '$apiBaseUrl/households/$demoHouseholdId/care-recipients/$demoCareRecipientId/rollup/weekly',
      ),
      headers: headers,
      body: jsonEncode({
        'weekKey': currentWeekKey(),
        'periodStart': weekStart.toIso8601String(),
      }),
    );
  }
}
