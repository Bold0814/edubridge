import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/grade.dart';
import 'grade_repository.dart';

/// Narrow document store so grade/staff writes can be unit-tested without live Firebase.
abstract class GradeDocumentStore {
  Future<Map<String, dynamic>?> get(String path);

  Future<void> set(
    String path,
    Map<String, Object?> data, {
    bool merge = false,
  });

  Future<void> delete(String path);

  Future<List<({String id, Map<String, dynamic> data})>> listCollection(
    String collection,
  );
}

class FirestoreGradeDocumentStore implements GradeDocumentStore {
  FirestoreGradeDocumentStore([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<Map<String, dynamic>?> get(String path) async {
    final snap = await _db.doc(path).get();
    if (!snap.exists || snap.data() == null) return null;
    return Map<String, dynamic>.from(snap.data()!);
  }

  @override
  Future<void> set(
    String path,
    Map<String, Object?> data, {
    bool merge = false,
  }) async {
    await _db
        .doc(path)
        .set(Map<String, dynamic>.from(data), SetOptions(merge: merge));
  }

  @override
  Future<void> delete(String path) async {
    await _db.doc(path).delete();
  }

  @override
  Future<List<({String id, Map<String, dynamic> data})>> listCollection(
    String collection,
  ) async {
    final snap = await _db.collection(collection).get();
    return [
      for (final doc in snap.docs)
        (id: doc.id, data: Map<String, dynamic>.from(doc.data())),
    ];
  }
}

/// In-memory store for grade repository unit tests.
@visibleForTesting
class MemoryGradeDocumentStore implements GradeDocumentStore {
  final Map<String, Map<String, dynamic>> documents = {};
  int setCount = 0;
  int deleteCount = 0;

  @override
  Future<Map<String, dynamic>?> get(String path) async {
    final data = documents[path];
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<void> set(
    String path,
    Map<String, Object?> data, {
    bool merge = false,
  }) async {
    setCount++;
    final incoming = Map<String, dynamic>.from(data);
    for (final entry in incoming.entries.toList()) {
      if (entry.value is FieldValue) {
        incoming[entry.key] = DateTime.fromMillisecondsSinceEpoch(
          setCount,
          isUtc: true,
        );
      }
    }
    if (merge && documents.containsKey(path)) {
      documents[path] = {...documents[path]!, ...incoming};
    } else {
      documents[path] = incoming;
    }
  }

  @override
  Future<void> delete(String path) async {
    deleteCount++;
    documents.remove(path);
  }

  @override
  Future<List<({String id, Map<String, dynamic> data})>> listCollection(
    String collection,
  ) async {
    final prefix = '$collection/';
    final result = <({String id, Map<String, dynamic> data})>[];
    for (final entry in documents.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final id = entry.key.substring(prefix.length);
      if (id.contains('/')) continue;
      result.add((id: id, data: Map<String, dynamic>.from(entry.value)));
    }
    return result;
  }
}

/// Firestore-backed shared grade repository (`grades/{id}`).
class FirestoreGradeRepository implements GradeRepository {
  FirestoreGradeRepository({
    FirebaseFirestore? firestore,
    GradeDocumentStore? store,
    Object Function()? serverTimestamp,
  }) : _store = store ?? FirestoreGradeDocumentStore(firestore),
       _serverTimestamp =
           serverTimestamp ?? (() => FieldValue.serverTimestamp());

  final GradeDocumentStore _store;
  final Object Function() _serverTimestamp;

  static String pathFor(String id) => '${Grade.collection}/${id.trim()}';

  @visibleForTesting
  GradeDocumentStore get store => _store;

  @override
  Future<List<Grade>> loadAll() async {
    final docs = await _store.listCollection(Grade.collection);
    final grades = <Grade>[];
    for (final doc in docs) {
      try {
        grades.add(Grade.fromFirestore(doc.id, doc.data));
      } catch (_) {
        // Skip unreadable legacy documents rather than failing the whole load.
      }
    }
    return grades;
  }

  @override
  Future<void> create(Grade grade) async {
    Grade.parseAndValidateScore(grade.score);
    final id = grade.id.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(grade.id, 'id', 'Grade id must not be empty');
    }
    if (grade.studentId.trim().isEmpty) {
      throw const GradeSaveException(Grade.missingStudentIdMessage);
    }
    if (grade.subjectId == null) {
      throw const GradeSaveException(Grade.missingSubjectIdMessage);
    }
    if (grade.resolvedTermId.isEmpty) {
      throw const GradeSaveException(Grade.missingTermIdMessage);
    }
    if ((grade.schoolId ?? '').trim().isEmpty) {
      throw const GradeSaveException(Grade.missingSchoolIdMessage);
    }
    if ((grade.teacherId ?? '').trim().isEmpty) {
      throw const GradeSaveException(Grade.missingTeacherIdMessage);
    }
    final path = pathFor(id);
    Map<String, dynamic>? existing;
    try {
      existing = await _store.get(path);
    } catch (_) {
      existing = null;
    }
    if (existing != null) {
      throw StateError('Grade document already exists: $path');
    }
    final stamp = _serverTimestamp();
    await _store.set(
      path,
      grade.toFirestoreCreateMap(createdAt: stamp, updatedAt: stamp),
    );
  }

  @override
  Future<void> update(Grade grade) async {
    Grade.parseAndValidateScore(grade.score);
    final id = grade.id.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(grade.id, 'id', 'Grade id must not be empty');
    }
    final path = pathFor(id);
    Map<String, dynamic>? existing;
    try {
      existing = await _store.get(path);
    } catch (_) {
      existing = null;
    }
    if (existing == null) {
      throw StateError('Grade document not found for update: $path');
    }
    // Merge update — preserves createdAt on the existing document.
    await _store.set(
      path,
      grade.toFirestoreUpdateMap(updatedAt: _serverTimestamp()),
      merge: true,
    );
  }

  @override
  Future<void> delete(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return;
    await _store.delete(pathFor(trimmed));
  }
}
