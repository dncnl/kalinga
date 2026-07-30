import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../api_config.dart';
import 'auth_token.dart';

class Medication {
  final String id;
  final String name;
  final String? strength;
  final String dosageText;
  final String? route;
  final List<String> times;
  final String? specialInstructions;
  final String verificationStatus; // unverified | familyConfirmed | clinicianConfirmed
  final String sourceType; // familyEntry | clinicianDocument | labelOcrDraft

  Medication({
    required this.id,
    required this.name,
    required this.strength,
    required this.dosageText,
    required this.route,
    required this.times,
    required this.specialInstructions,
    required this.verificationStatus,
    required this.sourceType,
  });

  bool get needsConfirmation => verificationStatus == 'unverified';

  factory Medication.fromJson(Map<String, dynamic> json) {
    final schedule = json['schedule'] as Map<String, dynamic>? ?? {};
    return Medication(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unlabeled medication',
      strength: json['strength'] as String?,
      dosageText: json['dosageText'] as String? ?? '',
      route: json['route'] as String?,
      times: List<String>.from(schedule['times'] as List? ?? []),
      specialInstructions: json['specialInstructions'] as String?,
      verificationStatus: json['verificationStatus'] as String? ?? 'unverified',
      sourceType: json['sourceType'] as String? ?? 'familyEntry',
    );
  }
}

class MedicationEvent {
  final String id;
  final String medicationId;
  final DateTime scheduledAt;
  final String status;

  MedicationEvent({
    required this.id,
    required this.medicationId,
    required this.scheduledAt,
    required this.status,
  });

  factory MedicationEvent.fromJson(Map<String, dynamic> json) {
    return MedicationEvent(
      id: json['id'] as String,
      medicationId: json['medicationId'] as String,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      status: json['status'] as String,
    );
  }
}

class MedicationService {
  const MedicationService();

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<List<Medication>> listMedications(String householdId, String careRecipientId) async {
    final token = await getIdToken();
    final res = await http.get(
      Uri.parse('$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/medications'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to list medications: ${res.body}');
    }
    final list = (jsonDecode(res.body) as Map<String, dynamic>)['medications'] as List;
    return list.map((m) => Medication.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<String> createMedication(
    String householdId,
    String careRecipientId, {
    required String name,
    required String dosageText,
    String? strength,
    String? route,
    List<String> times = const [],
    String? specialInstructions,
  }) async {
    final token = await getIdToken();
    final res = await http.post(
      Uri.parse('$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/medications'),
      headers: _headers(token),
      body: jsonEncode({
        'name': name,
        'dosageText': dosageText,
        'strength': strength,
        'route': route,
        'schedule': {'times': times},
        'specialInstructions': specialInstructions,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to create medication: ${res.body}');
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['medicationId'] as String;
  }

  Future<void> deleteMedication(String householdId, String careRecipientId, String medicationId) async {
    final token = await getIdToken();
    final res = await http.delete(
      Uri.parse(
        '$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/medications/$medicationId',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to delete medication: ${res.body}');
    }
  }

  /// Uploads → scans a medication label photo. Returns an *unverified* draft
  /// medication ID — the schema never trusts a photo scan without a human
  /// confirming it via [confirmMedication], so the caller must show the
  /// draft for review, not treat this as a finished medication.
  Future<Medication> scanLabel(
    XFile photoFile, {
    required String householdId,
    required String careRecipientId,
  }) async {
    final token = await getIdToken();
    // The picker (especially on web) may hand back PNG/webp, not just JPEG —
    // trust its reported mimeType over assuming JPEG, falling back only if
    // it didn't report one.
    final contentType = photoFile.mimeType ?? 'image/jpeg';

    final uploadUrlRes = await http.post(
      Uri.parse(
        '$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/medications/upload-url',
      ),
      headers: _headers(token),
      body: jsonEncode({'contentType': contentType}),
    );
    if (uploadUrlRes.statusCode != 200) {
      throw Exception('Failed to get upload URL: ${uploadUrlRes.body}');
    }
    final uploadInfo = jsonDecode(uploadUrlRes.body) as Map<String, dynamic>;
    final medicationId = uploadInfo['medicationId'] as String;
    final uploadUrl = uploadInfo['uploadUrl'] as String;

    final bytes = await photoFile.readAsBytes();
    final putRes = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (putRes.statusCode != 200) {
      throw Exception('Failed to upload label photo: ${putRes.statusCode}');
    }

    final processRes = await http.post(
      Uri.parse(
        '$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/medications/$medicationId/process',
      ),
      headers: _headers(token),
      body: jsonEncode({}),
    );
    if (processRes.statusCode != 200) {
      throw Exception('Failed to scan label: ${processRes.body}');
    }

    return listMedications(householdId, careRecipientId)
        .then((meds) => meds.firstWhere((m) => m.id == medicationId));
  }

  /// Caregiver reviews (optionally editing) an OCR draft and confirms it —
  /// the only way a scanned medication's verificationStatus becomes
  /// 'familyConfirmed'. Never called automatically.
  Future<void> confirmMedication(
    String householdId,
    String careRecipientId,
    String medicationId, {
    required String name,
    required String dosageText,
    String? strength,
    String? route,
    List<String> times = const [],
    String? specialInstructions,
  }) async {
    final token = await getIdToken();
    final res = await http.post(
      Uri.parse(
        '$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/medications/$medicationId/confirm',
      ),
      headers: _headers(token),
      body: jsonEncode({
        'name': name,
        'dosageText': dosageText,
        'strength': strength,
        'route': route,
        'schedule': {'times': times},
        'specialInstructions': specialInstructions,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to confirm medication: ${res.body}');
    }
  }

  Future<List<MedicationEvent>> todaysEvents(String householdId, String careRecipientId) async {
    final token = await getIdToken();
    await http.post(
      Uri.parse(
        '$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/medication-events/generate-today',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    final res = await http.get(
      Uri.parse('$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/medication-events'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to list medication events: ${res.body}');
    }
    final list = (jsonDecode(res.body) as Map<String, dynamic>)['events'] as List;
    return list.map((e) => MedicationEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> markEvent(
    String householdId,
    String careRecipientId,
    String eventId, {
    required String status,
    String? caregiverNote,
    String? refusalReason,
  }) async {
    final token = await getIdToken();
    final res = await http.patch(
      Uri.parse(
        '$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId/medication-events/$eventId',
      ),
      headers: _headers(token),
      body: jsonEncode({
        'status': status,
        'caregiverNote': caregiverNote,
        'refusalReason': refusalReason,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update medication event: ${res.body}');
    }
  }
}
