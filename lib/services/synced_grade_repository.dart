import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/grade.dart';
import 'grade_repository.dart';

/// Writes grades to Firestore (primary) and SQLite (mirror).
///
/// When the teacher is authorized locally but Firebase Auth / rules are not
/// ready yet, falls back to the SQLite mirror so grade entry keeps working
/// (pre-regression behavior) without opening Firestore to the world.
class SyncedGradeRepository implements GradeRepository {
  SyncedGradeRepository({
    required this.primary,
    required this.mirror,
  });

  final GradeRepository primary;
  final GradeRepository mirror;

  bool _isAuthOrPermissionFailure(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied' ||
          error.code == 'unauthenticated';
    }
    return false;
  }

  @override
  Future<List<Grade>> loadAll() async {
    List<Grade> remote = const [];
    try {
      remote = await primary.loadAll();
    } catch (_) {
      return mirror.loadAll();
    }

    final local = await mirror.loadAll();
    if (remote.isEmpty) return local;

    final byId = <String, Grade>{for (final g in local) g.id: g};
    for (final g in remote) {
      byId[g.id] = g;
    }
    return byId.values.toList(growable: false);
  }

  @override
  Future<void> create(Grade grade) async {
    try {
      await primary.create(grade);
    } catch (e) {
      if (_isAuthOrPermissionFailure(e)) {
        if (kDebugMode) {
          debugPrint(
            'SyncedGradeRepository.create: cloud denied (${e is FirebaseException ? e.code : e}); '
            'falling back to local mirror',
          );
        }
        await mirror.create(grade);
        return;
      }
      rethrow;
    }
    try {
      await mirror.create(grade);
    } catch (_) {
      // Mirror failure must not undo the primary write.
    }
  }

  @override
  Future<void> update(Grade grade) async {
    try {
      await primary.update(grade);
    } on StateError {
      try {
        await primary.create(grade);
      } catch (e) {
        if (_isAuthOrPermissionFailure(e)) {
          await mirror.update(grade);
          return;
        }
        rethrow;
      }
    } catch (e) {
      if (_isAuthOrPermissionFailure(e)) {
        if (kDebugMode) {
          debugPrint(
            'SyncedGradeRepository.update: cloud denied; falling back to local mirror',
          );
        }
        try {
          await mirror.update(grade);
        } catch (_) {
          await mirror.create(grade);
        }
        return;
      }
      rethrow;
    }
    try {
      await mirror.update(grade);
    } catch (_) {
      try {
        await mirror.create(grade);
      } catch (_) {}
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await primary.delete(id);
    } catch (e) {
      if (_isAuthOrPermissionFailure(e)) {
        await mirror.delete(id);
        return;
      }
      rethrow;
    }
    try {
      await mirror.delete(id);
    } catch (_) {}
  }
}
