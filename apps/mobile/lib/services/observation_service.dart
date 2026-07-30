import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../week_key.dart';
import 'auth_token.dart';

class ObservationService {
  const ObservationService();

  /// Records → uploads → processes one voice log for [careRecipientId] in
  /// [householdId] — both must come from the caller's currently selected
  /// profile (SelectedProfile), not hardcoded, so every log lands against
  /// the right elder. Returns the extraction result (categories,
  /// comparisonToUsual, safetyAssessment, etc).
  Future<Map<String, dynamic>> submitVoiceLog(
    File audioFile, {
    required String householdId,
    required String careRecipientId,
  }) async {
    final token = await getIdToken();
    const contentType = 'audio/wav';

    final uploadUrlRes = await http.post(
      Uri.parse(
        '$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/observations/upload-url',
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
        '$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/observations/$observationId/process',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'locale': demoLocale}),
    );
    if (processRes.statusCode != 200) {
      throw Exception('Failed to process observation: ${processRes.body}');
    }

    // Trigger rollup in the background — don't await it so the UI
    // shows "Logged" immediately. The chart updates via Firestore
    // real-time listener once the rollup finishes.
    _triggerRollup(token, householdId: householdId, careRecipientId: careRecipientId);

    return jsonDecode(processRes.body) as Map<String, dynamic>;
  }

  Future<void> _triggerRollup(
    String token, {
    required String householdId,
    required String careRecipientId,
  }) async {
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final today = dateKeyOf(DateTime.now());
    final weekStart = currentWeekStartUtc();

    // Run daily and weekly rollup in parallel.
    await Future.wait([
      http.post(
        Uri.parse(
          '$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/rollup/daily',
        ),
        headers: headers,
        body: jsonEncode({'dateKey': today}),
      ),
      http.post(
        Uri.parse(
          '$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/rollup/weekly',
        ),
        headers: headers,
        body: jsonEncode({
          'weekKey': currentWeekKey(),
          'periodStart': weekStart.toIso8601String(),
        }),
      ),
    ]);
  }
}
