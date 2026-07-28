import 'package:sqflite/sqflite.dart';

import '../../models/school_data_reset.dart';
import 'school_data_reset_repository.dart';

/// Local SQLite implementation of school-scoped operational reset.
///
/// Every DELETE is scoped by [schoolId] or by class/teacher/student IDs that
/// were first resolved for that school. Never uses unscoped `DELETE FROM table`.
class SqliteSchoolDataResetRepository implements SchoolDataResetRepository {
  SqliteSchoolDataResetRepository(this._db);

  final Database _db;

  /// Test-only: when true, aborts the transaction after deletes start.
  bool debugForceFailure = false;

  @override
  Future<ResetPreview> getPreview(String schoolId) async {
    final classNames = await _classNamesForSchool(schoolId);
    final classIds = await _classIdsForSchool(schoolId);

    return ResetPreview(
      schoolId: schoolId,
      teacherCount: await _count(
        'teachers',
        where: 'school_id = ?',
        whereArgs: [schoolId],
      ),
      classCount: classIds.length,
      subjectCount: await _count(
        'subjects',
        where: 'school_id = ?',
        whereArgs: [schoolId],
      ),
      studentCount: await _countIn(
        'students',
        column: 'class_name',
        values: classNames,
      ),
      guardianCount: await _count(
        'guardians',
        where: 'school_id = ?',
        whereArgs: [schoolId],
      ),
      attendanceCount: await _countIn(
        'attendance',
        column: 'class_name',
        values: classNames,
      ),
      gradeCount: await _countIn(
        'grades',
        column: 'class_name',
        values: classNames,
      ),
      homeworkCount: await _countIn(
        'homework',
        column: 'class_name',
        values: classNames,
      ),
      journalCount: await _count(
        'lesson_occurrences',
        where: 'school_id = ?',
        whereArgs: [schoolId],
      ),
      announcementCount: await _count(
        'announcements',
        where: 'school_id = ?',
        whereArgs: [schoolId],
      ),
    );
  }

  @override
  Future<ResetDeletedCounts> resetOperationalData({
    required String schoolId,
    required String preserveAdminUserId,
    String? preserveTeacherId,
    required SchoolResetScope scope,
  }) async {
    if (schoolId.trim().isEmpty) {
      throw const SchoolResetValidationException('Сургууль сонгогдоогүй.');
    }
    if (!scope.hasAnySelection) {
      throw const SchoolResetValidationException('Устгах хэсэг сонгоогүй.');
    }

    return _db.transaction((txn) async {
      if (debugForceFailure) {
        throw StateError('DEBUG_FORCE_FAILURE');
      }

      final classNames = await _classNamesForSchoolTxn(txn, schoolId);
      final classIds = await _classIdsForSchoolTxn(txn, schoolId);
      final studentIds = await _idsWhereIn(
        txn,
        'students',
        idColumn: 'id',
        filterColumn: 'class_name',
        values: classNames,
      );
      final teacherIds = await _teacherIdsForSchool(
        txn,
        schoolId,
        exceptTeacherId: preserveTeacherId,
      );
      final guardianIds = await _idsWhere(
        txn,
        'guardians',
        where: 'school_id = ?',
        whereArgs: [schoolId],
      );
      final announcementIds = await _idsWhere(
        txn,
        'announcements',
        where: 'school_id = ?',
        whereArgs: [schoolId],
      );
      final homeworkIds = await _idsWhereIn(
        txn,
        'homework',
        idColumn: 'id',
        filterColumn: 'class_name',
        values: classNames,
      );

      var other = 0;
      var attendance = 0;
      var grades = 0;
      var homework = 0;
      var journals = 0;
      var announcements = 0;
      var teachers = 0;
      var classes = 0;
      var subjects = 0;
      var students = 0;
      var guardians = 0;

      // Cascade safety: deleting people/classes requires clearing dependents.
      final clearClassScoped =
          scope.structurePeople ||
          scope.academicRecords ||
          scope.scheduleAndAssignments;
      final clearJournal = scope.journalAndComms || scope.structurePeople;
      final clearAcademic = scope.academicRecords || scope.structurePeople;
      final clearSchedule =
          scope.scheduleAndAssignments || scope.structurePeople;

      if (clearJournal) {
        other += await _deleteIn(
          txn,
          'announcement_read_receipts',
          column: 'announcement_id',
          values: announcementIds,
        );
        // Prefer school_id when present on receipts.
        other += await txn.delete(
          'announcement_read_receipts',
          where: 'school_id = ?',
          whereArgs: [schoolId],
        );
        other += await _deleteIn(
          txn,
          'guardian_read_announcements',
          column: 'announcement_id',
          values: announcementIds,
        );
        other += await _deleteIn(
          txn,
          'teacher_notes',
          column: 'student_id',
          values: studentIds,
        );
        other += await _deleteIn(
          txn,
          'teacher_notes',
          column: 'teacher_id',
          values: teacherIds,
        );
        journals += await txn.delete(
          'lesson_occurrences',
          where: 'school_id = ?',
          whereArgs: [schoolId],
        );
        announcements += await txn.delete(
          'announcements',
          where: 'school_id = ?',
          whereArgs: [schoolId],
        );
      }

      if (clearAcademic) {
        other += await txn.delete(
          'student_homework_status',
          where: 'school_id = ?',
          whereArgs: [schoolId],
        );
        other += await _deleteIn(
          txn,
          'student_homework_status',
          column: 'homework_id',
          values: homeworkIds,
        );
        attendance += await _deleteIn(
          txn,
          'attendance',
          column: 'class_name',
          values: classNames,
        );
        grades += await _deleteIn(
          txn,
          'grades',
          column: 'class_name',
          values: classNames,
        );
        homework += await _deleteIn(
          txn,
          'homework',
          column: 'class_name',
          values: classNames,
        );
      }

      if (clearSchedule) {
        other += await _deleteIn(
          txn,
          'class_timetable',
          column: 'class_id',
          values: classIds,
        );
        other += await _deleteIn(
          txn,
          'class_subject_teachers',
          column: 'class_id',
          values: classIds,
        );
        if (scope.scheduleAndAssignments || scope.structurePeople) {
          other += await txn.delete(
            'lesson_periods',
            where: 'school_id = ?',
            whereArgs: [schoolId],
          );
        }
      }

      if (scope.structurePeople) {
        other += await _deleteIn(
          txn,
          'guardian_students',
          column: 'student_id',
          values: studentIds,
        );
        other += await _deleteIn(
          txn,
          'guardian_students',
          column: 'guardian_id',
          values: guardianIds,
        );
        students += await _deleteIn(
          txn,
          'students',
          column: 'class_name',
          values: classNames,
        );
        other += await txn.delete(
          'used_student_codes',
          where: 'school_id = ?',
          whereArgs: [schoolId],
        );

        // Memberships for this school except the primary admin.
        other += await txn.delete(
          'user_school_memberships',
          where: 'school_id = ? AND user_id != ?',
          whereArgs: [schoolId, preserveAdminUserId],
        );

        // Login accounts for removed teachers / students / guardians.
        other += await _deleteUserAccountsForLinks(
          txn,
          teacherIds: teacherIds,
          studentIds: studentIds,
          guardianIds: guardianIds,
          preserveAdminUserId: preserveAdminUserId,
        );

        guardians += await txn.delete(
          'guardians',
          where: 'school_id = ?',
          whereArgs: [schoolId],
        );

        if (preserveTeacherId != null && preserveTeacherId.isNotEmpty) {
          teachers += await txn.delete(
            'teachers',
            where: 'school_id = ? AND id != ?',
            whereArgs: [schoolId, preserveTeacherId],
          );
        } else {
          teachers += await txn.delete(
            'teachers',
            where: 'school_id = ?',
            whereArgs: [schoolId],
          );
        }

        subjects += await txn.delete(
          'subjects',
          where: 'school_id = ?',
          whereArgs: [schoolId],
        );

        // Clear homeroom refs then delete classes.
        await txn.rawUpdate(
          'UPDATE classes SET homeroom_teacher_id = NULL WHERE school_id = ?',
          [schoolId],
        );
        classes += await txn.delete(
          'classes',
          where: 'school_id = ?',
          whereArgs: [schoolId],
        );
      } else if (clearClassScoped && classIds.isNotEmpty) {
        // Assignments / timetable already handled when clearSchedule.
      }

      if (scope.resetSchoolSettings) {
        other += await txn.update(
          'school_settings',
          {
            'school_name': 'Сургууль',
            'academic_year': '',
            'current_semester': '',
          },
          where: 'school_id = ?',
          whereArgs: [schoolId],
        );
      }

      // School row itself is never deleted here.
      final schoolStillExists = await txn.query(
        'schools',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [schoolId],
        limit: 1,
      );
      if (schoolStillExists.isEmpty) {
        throw StateError('SCHOOL_ROW_MISSING');
      }

      final adminMembership = await txn.query(
        'user_school_memberships',
        where: 'school_id = ? AND user_id = ? AND role = ?',
        whereArgs: [schoolId, preserveAdminUserId, 'admin'],
        limit: 1,
      );
      if (adminMembership.isEmpty) {
        throw StateError('ADMIN_MEMBERSHIP_MISSING');
      }

      final adminAccount = await txn.query(
        'user_accounts',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [preserveAdminUserId],
        limit: 1,
      );
      if (adminAccount.isEmpty) {
        throw StateError('ADMIN_ACCOUNT_MISSING');
      }

      return ResetDeletedCounts(
        teachers: teachers,
        classes: classes,
        subjects: subjects,
        students: students,
        guardians: guardians,
        attendance: attendance,
        grades: grades,
        homework: homework,
        journals: journals,
        announcements: announcements,
        other: other,
      );
    });
  }

  @override
  Future<void> deleteSchoolCompletely({
    required String schoolId,
    required String preserveAdminUserId,
  }) async {
    throw const SchoolDeleteUnavailableException();
  }

  Future<int> _count(
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $table WHERE $where',
      whereArgs,
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<int> _countIn(
    String table, {
    required String column,
    required List<String> values,
  }) async {
    if (values.isEmpty) return 0;
    final placeholders = List.filled(values.length, '?').join(',');
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $table WHERE $column IN ($placeholders)',
      values,
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<List<String>> _classNamesForSchool(String schoolId) async {
    final rows = await _db.query(
      'classes',
      columns: ['name'],
      where: 'school_id = ?',
      whereArgs: [schoolId],
    );
    return [for (final row in rows) row['name']! as String];
  }

  Future<List<String>> _classIdsForSchool(String schoolId) async {
    // Class PK is `name` (also used as id in AppStore).
    return _classNamesForSchool(schoolId);
  }

  Future<List<String>> _classNamesForSchoolTxn(
    Transaction txn,
    String schoolId,
  ) async {
    final rows = await txn.query(
      'classes',
      columns: ['name'],
      where: 'school_id = ?',
      whereArgs: [schoolId],
    );
    return [for (final row in rows) row['name']! as String];
  }

  Future<List<String>> _classIdsForSchoolTxn(
    Transaction txn,
    String schoolId,
  ) => _classNamesForSchoolTxn(txn, schoolId);

  Future<List<String>> _teacherIdsForSchool(
    Transaction txn,
    String schoolId, {
    String? exceptTeacherId,
  }) async {
    final rows = exceptTeacherId == null || exceptTeacherId.isEmpty
        ? await txn.query(
            'teachers',
            columns: ['id'],
            where: 'school_id = ?',
            whereArgs: [schoolId],
          )
        : await txn.query(
            'teachers',
            columns: ['id'],
            where: 'school_id = ? AND id != ?',
            whereArgs: [schoolId, exceptTeacherId],
          );
    return [for (final row in rows) row['id']! as String];
  }

  Future<List<String>> _idsWhere(
    Transaction txn,
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final rows = await txn.query(
      table,
      columns: ['id'],
      where: where,
      whereArgs: whereArgs,
    );
    return [for (final row in rows) row['id']! as String];
  }

  Future<List<String>> _idsWhereIn(
    Transaction txn,
    String table, {
    required String idColumn,
    required String filterColumn,
    required List<String> values,
  }) async {
    if (values.isEmpty) return const [];
    final placeholders = List.filled(values.length, '?').join(',');
    final rows = await txn.rawQuery(
      'SELECT $idColumn AS id FROM $table WHERE $filterColumn IN ($placeholders)',
      values,
    );
    return [for (final row in rows) row['id']! as String];
  }

  Future<int> _deleteIn(
    Transaction txn,
    String table, {
    required String column,
    required List<String> values,
  }) async {
    if (values.isEmpty) return 0;
    final placeholders = List.filled(values.length, '?').join(',');
    return txn.rawDelete(
      'DELETE FROM $table WHERE $column IN ($placeholders)',
      values,
    );
  }

  Future<int> _deleteUserAccountsForLinks(
    Transaction txn, {
    required List<String> teacherIds,
    required List<String> studentIds,
    required List<String> guardianIds,
    required String preserveAdminUserId,
  }) async {
    var deleted = 0;
    if (teacherIds.isNotEmpty) {
      final placeholders = List.filled(teacherIds.length, '?').join(',');
      deleted += await txn.rawDelete(
        'DELETE FROM user_accounts WHERE teacher_id IN ($placeholders) '
        'AND id != ?',
        [...teacherIds, preserveAdminUserId],
      );
    }
    if (studentIds.isNotEmpty) {
      final placeholders = List.filled(studentIds.length, '?').join(',');
      deleted += await txn.rawDelete(
        'DELETE FROM user_accounts WHERE student_id IN ($placeholders) '
        'AND id != ?',
        [...studentIds, preserveAdminUserId],
      );
    }
    if (guardianIds.isNotEmpty) {
      final placeholders = List.filled(guardianIds.length, '?').join(',');
      deleted += await txn.rawDelete(
        'DELETE FROM user_accounts WHERE guardian_id IN ($placeholders) '
        'AND id != ?',
        [...guardianIds, preserveAdminUserId],
      );
    }
    final stillThere = await txn.query(
      'user_accounts',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [preserveAdminUserId],
      limit: 1,
    );
    if (stillThere.isEmpty) {
      throw StateError('ADMIN_ACCOUNT_DELETED');
    }
    return deleted;
  }
}
