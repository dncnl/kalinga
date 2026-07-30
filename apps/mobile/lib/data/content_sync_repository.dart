import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContentSyncRepository<T> {
  final FirebaseFirestore _firestore;
  final String collectionPath;
  final String cacheKey;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;
  final List<T> bundledSeed;

  ContentSyncRepository({
    required this.collectionPath,
    required this.cacheKey,
    required this.fromJson,
    required this.toJson,
    required this.bundledSeed,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Returns immediately from local cache (or bundled seed on first-ever
  /// launch), then triggers a background sync.
  Future<List<T>> getInitial() async {
    final cached = await _loadCache();
    if (cached != null) return cached;
    await _saveCache(bundledSeed);
    return bundledSeed;
  }

  Future<List<T>?> syncInBackground() async {
    try {
      final snapshot = await _firestore.collection(collectionPath).get();
      if (snapshot.docs.isEmpty) return null;
      final entries = snapshot.docs.map((d) => fromJson(d.data())).toList();
      await _saveCache(entries);
      return entries;
    } catch (_) {
      return null; // silent — keep showing what is already rendered
    }
  }

  Future<void> _saveCache(List<T> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cacheKey, jsonEncode(entries.map(toJson).toList()));
  }

  Future<List<T>?> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheKey);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }
}
