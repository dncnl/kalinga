/// Resolves and accepts family-viewer invite tokens (screen 16 → 17).
///
/// `households/{householdId}/invitations/{invitationId}` is `serverOnly` for
/// writes and `householdAdminsOnly` for reads in firestore.rules — an
/// unauthenticated invitee can't look up or accept an invite straight from
/// the Flutter client. The real backend for this is the Node/Express API in
/// apps/api (`GET /invites/:token`, `POST /invites/:token/accept`), which
/// isn't implemented yet (apps/api has no source files, only package.json).
///
/// This class is the seam: it keeps that exact contract so the UI can be
/// built and demoed today, and swapping the two methods below for real HTTP
/// calls later doesn't touch anything else in the app.
class InviteDetails {
  final String token;
  final String inviterName;
  final String patientId;
  final String patientName;
  final String email;

  const InviteDetails({
    required this.token,
    required this.inviterName,
    required this.patientId,
    required this.patientName,
    required this.email,
  });
}

class InviteService {
  /// TODO(api): call `GET /invites/:token` once apps/api exists.
  Future<InviteDetails> fetchInvite(String token) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return InviteDetails(
      token: token,
      inviterName: 'Siti',
      patientId: 'lola-rosa',
      patientName: '羅莎奶奶',
      email: 'meiling.chen@email.com',
    );
  }

  /// TODO(api): call `POST /invites/:token/accept` once apps/api exists.
  /// That request is what actually links [viewerUid] into
  /// `households/{householdId}/members` — only the Admin SDK can write
  /// there, so this step needs an authenticated backend, not just Firebase
  /// Auth on the client.
  Future<void> acceptInvite({
    required String token,
    required String viewerUid,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
}
