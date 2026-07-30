import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import 'auth_token.dart';

class ObservationService {
  const ObservationService();

  /// Records → uploads → kicks off processing for one voice log for
  /// [careRecipientId] in [householdId] — both must come from the caller's
  /// currently selected profile (SelectedProfile), not hardcoded, so every
  /// log lands against the right elder.
  ///
  /// Returns as soon as the upload is confirmed and processing has started
  /// server-side — NOT once transcription/extraction/rollup finish. Those
  /// (Speech-to-Text + LLM extraction) were slow enough that waiting for
  /// the full result before showing "Logged" made this feel stuck; the
  /// backend now runs that as a background job (see apps/api's
  /// processObservationJob.js) and updates the observation doc + the chart
  /// (via the existing weeklySummaries Firestore listener) once it's done.
  Future<void> submitVoiceLog(
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
      throw Exception('Failed to start processing observation: ${processRes.body}');
    }
  }
}
