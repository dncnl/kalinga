import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import 'auth_token.dart';

/// Resolves and accepts household invite tokens (family or caregiver role).
/// See apps/api/src/routes/invites.js for the backend — this is a thin
/// HTTP wrapper, no logic lives here.
/// Shape of GET /invites/:code — a pure shared-secret join code since
/// b10bcd9: no invitee identity (email) is attached, and the raw code is
/// never echoed back (only its hash is stored server-side).
class InviteDetails {
  final String intendedRole;
  final String inviterName;
  final String? patientId;
  final String? patientName;

  const InviteDetails({
    required this.intendedRole,
    required this.inviterName,
    required this.patientId,
    required this.patientName,
  });

  factory InviteDetails.fromJson(Map<String, dynamic> json) => InviteDetails(
        intendedRole: json['intendedRole'] as String? ?? 'family',
        inviterName: json['inviterName'] as String? ?? 'A caregiver',
        patientId: json['patientId'] as String?,
        patientName: json['patientName'] as String?,
      );
}

class InviteService {
  /// GET /invites/:token — public, no auth (the invitee has no Firebase
  /// account yet at this point). Throws if the invite doesn't exist, has
  /// expired, or was already used.
  Future<InviteDetails> fetchInvite(String token) async {
    final res = await http.get(Uri.parse('$apiBaseUrl/invites/$token'));
    if (res.statusCode != 200) {
      throw Exception('Invite not found');
    }
    return InviteDetails.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// POST /invites/:token/accept — the invitee just created their Firebase
  /// account client-side (FamilyRegisterPage); this call is what actually
  /// links them into households/{id}/members via the Admin SDK. [viewerUid]
  /// is accepted for API-shape compatibility with the caller but isn't
  /// sent — the backend identifies the caller from the ID token itself.
  Future<void> acceptInvite({
    required String token,
    required String viewerUid,
  }) async {
    final idToken = await getIdToken();
    final res = await http.post(
      Uri.parse('$apiBaseUrl/invites/$token/accept'),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to accept invite: ${res.body}');
    }
  }

  /// POST /households/:householdId/invitations — creates a new join code
  /// for [intendedRole] ('family' or 'caregiver'), optionally scoped to a
  /// single care recipient. Returns the raw code for the caregiver to share
  /// verbally/by message; the backend doesn't tie it to any invitee email.
  Future<String> createInvite({
    required String householdId,
    required String intendedRole,
    String? careRecipientId,
  }) async {
    final idToken = await getIdToken();
    final res = await http.post(
      Uri.parse('$apiBaseUrl/households/$householdId/invitations'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'intendedRole': intendedRole,
        if (careRecipientId != null) 'careRecipientId': careRecipientId,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to create invite: ${res.body}');
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['code'] as String;
  }
}
