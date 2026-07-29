import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/firestore_class_subject_teacher.dart';
import '../models/firestore_teacher.dart';
import 'firestore_grade_repository.dart';

/// Syncs teacher + class/subject assignment docs used by grade security rules.
class FirestoreStaffRepository {
  FirestoreStaffRepository({
    FirebaseFirestore? firestore,
    GradeDocumentStore? store,
    Object Function()? serverTimestamp,
  }) : _store = store ?? FirestoreGradeDocumentStore(firestore),
       _serverTimestamp =
           serverTimestamp ?? (() => FieldValue.serverTimestamp());

  final GradeDocumentStore _store;
  final Object Function() _serverTimestamp;

  @visibleForTesting
  GradeDocumentStore get store => _store;

  Future<FirestoreTeacher?> getTeacher(String teacherId) async {
    final data = await _store.get(FirestoreTeacher.pathFor(teacherId));
    if (data == null) return null;
    return FirestoreTeacher.fromMap(teacherId.trim(), data);
  }

  Future<void> upsertTeacher(FirestoreTeacher teacher) async {
    final path = FirestoreTeacher.pathFor(teacher.id);
    final existing = await _store.get(path);
    final stamp = _serverTimestamp();
    if (existing == null) {
      await _store.set(
        path,
        teacher.toCreateMap(createdAt: stamp, updatedAt: stamp),
      );
    } else {
      await _store.set(
        path,
        teacher.toUpdateMap(updatedAt: stamp),
        merge: true,
      );
    }
  }

  Future<FirestoreClassSubjectTeacher?> getAssignment({
    required String schoolId,
    required String classId,
    required int subjectId,
  }) async {
    final path = FirestoreClassSubjectTeacher.pathFor(
      schoolId: schoolId,
      classId: classId,
      subjectId: subjectId,
    );
    final data = await _store.get(path);
    if (data == null) return null;
    return FirestoreClassSubjectTeacher.fromMap(
      FirestoreClassSubjectTeacher.documentId(
        schoolId: schoolId,
        classId: classId,
        subjectId: subjectId,
      ),
      data,
    );
  }

  Future<void> upsertAssignment(FirestoreClassSubjectTeacher assignment) async {
    final path = FirestoreClassSubjectTeacher.pathFor(
      schoolId: assignment.schoolId,
      classId: assignment.classId,
      subjectId: assignment.subjectId,
    );
    final existing = await _store.get(path);
    final stamp = _serverTimestamp();
    if (existing == null) {
      await _store.set(
        path,
        assignment.toCreateMap(createdAt: stamp, updatedAt: stamp),
      );
    } else {
      await _store.set(
        path,
        assignment.toUpdateMap(updatedAt: stamp),
        merge: true,
      );
    }
  }
}
