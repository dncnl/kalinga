import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'profile_service.dart';

/// A care recipient a family-role account can view, paired with the
/// household it lives in (needed to build Firestore paths — CareRecipient
/// itself doesn't carry a householdId).
class ViewableCareRecipient {
  final String householdId;
  final CareRecipient careRecipient;
  const ViewableCareRecipient({required this.householdId, required this.careRecipient});
}

/// Resolves which care recipient(s) the signed-in user can view as family,
/// across every household they belong to. Pure composition of existing
/// endpoints (GET /households/mine, GET /households/:id/care-recipients —
/// both role-blind, confirmed to accept family-role callers) plus one
/// direct households/{id}/members/{uid} Firestore read per household
/// (self-read, always allowed by firestore.rules) to get that household's
/// careRecipientIds scoping. No new backend endpoints.
class FamilyViewerService {
  const FamilyViewerService({this.profileService = const ProfileService()});

  final ProfileService profileService;

  Future<List<ViewableCareRecipient>> resolveViewableRecipients() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];

    final households = await profileService.listMyHouseholds();
    final result = <ViewableCareRecipient>[];

    for (final household in households) {
      final memberDoc = await FirebaseFirestore.instance.doc('households/${household.id}/members/$uid').get();
      final ids = List<String>.from(memberDoc.data()?['careRecipientIds'] as List? ?? []);
      if (ids.isEmpty) continue;

      final recipients = await profileService.listCareRecipients(household.id);
      result.addAll(
        recipients.where((r) => ids.contains(r.id)).map(
              (r) => ViewableCareRecipient(householdId: household.id, careRecipient: r),
            ),
      );
    }
    return result;
  }
}
