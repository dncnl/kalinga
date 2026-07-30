import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import 'auth_token.dart';

/// Resolves and accepts household invite tokens (family or caregiver role).
/// See apps/api/src/routes/invites.js for the backend — this is a thin
/// HTTP wrapper, no logic lives here.
class InviteDetails {
  final String token;
  final String inviterName;
  final String? patientId;
  final String? patientName;
  final String email;

  const InviteDetails({
    required this.token,
    required this.inviterName,
    required this.patientId,
    required this.patientName,
    required this.email,
  });

  factory InviteDetails.fromJson(Map<String, dynamic> json) => InviteDetails(
        token: json['token'] as String,
        inviterName: json['inviterName'] as String,
        patientId: json['patientId'] as String?,
        patientName: json['patientName'] as String?,
        email: json['email'] as String,
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

  /// POST /households/:householdId/invitations — creates a new invite for
  /// [intendedRole] ('family' or 'caregiver'), optionally scoped to a
  /// single care recipient. Returns the raw token; the caller builds a
  /// shareable link (no email-sending infra exists yet, see PLAN.md).
  Future<String> createInvite({
    required String householdId,
    required String intendedRole,
    required String invitedEmail,
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
        'invitedEmail': invitedEmail,
        if (careRecipientId != null) 'careRecipientId': careRecipientId,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to create invite: ${res.body}');
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['token'] as String;
  }
}
