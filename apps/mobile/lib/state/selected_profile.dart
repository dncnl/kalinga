import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';

const _prefsHouseholdIdKey = 'kalinga.householdId';
const _prefsCareRecipientIdKey = 'kalinga.careRecipientId';

/// App-wide "who am I logging for right now" state. Every feature that
/// scopes data to a patient (voice-log, chart, viewer, meds, ...) should
/// read from this instead of hardcoding an id — that's the entire point of
/// Feature 5. Persisted across restarts via SharedPreferences; in-memory
/// reactive via ChangeNotifier so widgets update the moment the caregiver
/// switches profiles.
class SelectedProfile extends ChangeNotifier {
  SelectedProfile._();
  static final instance = SelectedProfile._();

  final _profileService = const ProfileService();

  String? householdId;
  CareRecipient? careRecipient;
  List<CareRecipient> careRecipients = [];
  bool isLoading = true;
  String? error;

  bool get hasProfile => careRecipient != null;

  Completer<void> _readyCompleter = Completer<void>();

  /// Resolves once the in-flight (or most recent) [initialize] call has
  /// finished, success or failure. `main.dart` fires [initialize]
  /// unawaited so app startup isn't blocked on a network round trip — any
  /// screen that needs householdId/careRecipients populated before acting
  /// (e.g. a "create profile" submit button) should `await` this first
  /// rather than assume initialize() already completed.
  Future<void> get ready => _readyCompleter.future;

  /// Call once at app start: bootstraps the household, loads all its care
  /// recipients, and restores the last-selected one (or picks the first
  /// available if the persisted id no longer exists / none was ever set).
  Future<void> initialize() async {
    if (_readyCompleter.isCompleted) _readyCompleter = Completer<void>();
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final id = await _profileService.bootstrapHousehold();
      householdId = id;
      await prefs.setString(_prefsHouseholdIdKey, id);

      careRecipients = await _profileService.listCareRecipients(id);

      final persistedRecipientId = prefs.getString(_prefsCareRecipientIdKey);
      final matches = careRecipients.where((r) => r.id == persistedRecipientId);
      careRecipient = matches.isNotEmpty
          ? matches.first
          : (careRecipients.isNotEmpty ? careRecipients.first : null);

      if (careRecipient != null) {
        await prefs.setString(_prefsCareRecipientIdKey, careRecipient!.id);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> select(CareRecipient recipient) async {
    careRecipient = recipient;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsCareRecipientIdKey, recipient.id);
  }

  Future<void> createAndSelect({
    required String displayName,
    int? age,
    List<String> preferredLanguages = const [],
    List<String> conditions = const [],
  }) async {
    final id = householdId;
    if (id == null) {
      throw StateError('SelectedProfile.initialize() must complete before creating a profile');
    }
    final recipient = await _profileService.createCareRecipient(
      id,
      displayName: displayName,
      age: age,
      preferredLanguages: preferredLanguages,
      conditions: conditions,
    );
    careRecipients = [...careRecipients, recipient];
    await select(recipient);
  }

  Future<void> updateSelected({
    required String displayName,
    int? age,
    List<String> preferredLanguages = const [],
    List<String> conditions = const [],
  }) async {
    final id = householdId;
    final recipient = careRecipient;
    if (id == null || recipient == null) {
      throw StateError('No profile selected to update');
    }
    await _profileService.updateCareRecipient(
      id,
      recipient.id,
      displayName: displayName,
      age: age,
      preferredLanguages: preferredLanguages,
      conditions: conditions,
    );
    final updated = CareRecipient(
      id: recipient.id,
      displayName: displayName,
      age: age,
      preferredLanguages: preferredLanguages,
      conditions: conditions,
    );
    careRecipients = [
      for (final r in careRecipients) if (r.id == updated.id) updated else r,
    ];
    careRecipient = updated;
    notifyListeners();
  }

  /// Deletes (archives) the currently selected profile, then selects
  /// whichever profile is next in the list, or null if none remain.
  Future<void> deleteSelected() async {
    final id = householdId;
    final recipient = careRecipient;
    if (id == null || recipient == null) {
      throw StateError('No profile selected to delete');
    }
    await _profileService.deleteCareRecipient(id, recipient.id);
    careRecipients = careRecipients.where((r) => r.id != recipient.id).toList();
    if (careRecipients.isNotEmpty) {
      await select(careRecipients.first);
    } else {
      careRecipient = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsCareRecipientIdKey);
      notifyListeners();
    }
  }

  /// Switches the active household (must already be a member — see
  /// apps/api's POST /households/switch) and reloads its recipients.
  Future<void> switchHousehold(String newHouseholdId) async {
    await _profileService.switchHousehold(newHouseholdId);
    householdId = newHouseholdId;
    careRecipients = await _profileService.listCareRecipients(newHouseholdId);
    careRecipient = careRecipients.isNotEmpty ? careRecipients.first : null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsHouseholdIdKey, newHouseholdId);
    if (careRecipient != null) {
      await prefs.setString(_prefsCareRecipientIdKey, careRecipient!.id);
    } else {
      await prefs.remove(_prefsCareRecipientIdKey);
    }
    notifyListeners();
  }
}
