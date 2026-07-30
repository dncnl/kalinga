// ignore_for_file: subtype_of_sealed_class, override_on_non_overriding_member, avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/data/content_sync_repository.dart';

class FakeCollectionReference extends Fake implements CollectionReference<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> mockDocs;

  FakeCollectionReference(this.mockDocs);

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    return FakeQuerySnapshot(mockDocs);
  }
}

class FakeQuerySnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  FakeQuerySnapshot(this.docs);

  @override
  bool get isEmpty => docs.isEmpty;
}

class FakeFirebaseFirestore extends Fake implements FirebaseFirestore {
  final Map<String, FakeCollectionReference> collections;

  FakeFirebaseFirestore(this.collections);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return collections[collectionPath] ?? FakeCollectionReference([]);
  }
}

class TestItem {
  final String id;
  final String val;
  TestItem(this.id, this.val);

  factory TestItem.fromJson(Map<String, dynamic> json) => TestItem(json['id'] as String, json['val'] as String);
  Map<String, dynamic> toJson() => {'id': id, 'val': val};
}

void main() {
  group('ContentSyncRepository Tests', () {
    const cacheKey = 'test_cache_key';
    final bundledSeed = [TestItem('1', 'Bundled')];

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getInitial() returns bundled seed when SharedPreferences is empty and Firestore is unreachable', () async {
      final firestore = FakeFirebaseFirestore({});
      
      final repo = ContentSyncRepository<TestItem>(
        collectionPath: 'test_path',
        cacheKey: cacheKey,
        fromJson: TestItem.fromJson,
        toJson: (t) => t.toJson(),
        bundledSeed: bundledSeed,
        firestore: firestore,
      );

      final initial = await repo.getInitial();
      expect(initial.length, 1);
      expect(initial.first.id, '1');
      expect(initial.first.val, 'Bundled');
    });
  });
}
