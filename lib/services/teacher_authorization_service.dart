import 'package:flutter/foundation.dart';

/// Record kinds managed by [TeacherAuthorizationService].
enum TeacherRecordKind {
  advice,
  attendance,
  grade,
  announcement,
  homework,
}

/// Stable ownership + scope snapshot for a persisted school record.
class RecordOwnership {
  const RecordOwnership({
    this.schoolId,
    this.classId,
    this.subjectId,
    this.createdByUid,
    this.createdByTeacherId,
  });

  final String? schoolId;
  final String? classId;
  final int? subjectId;

  /// Firebase Auth uid of the creator when known.
  final String? createdByUid;

  /// Teacher document id of the creator / assigned author.
  final String? createdByTeacherId;

  bool get hasUidOwnership {
    final uid = createdByUid?.trim();
    return uid != null && uid.isNotEmpty;
  }

  bool get hasTeacherOwnership {
    final id = createdByTeacherId?.trim();
    return id != null && id.isNotEmpty;
  }

  bool get hasAnyOwnership => hasUidOwnership || hasTeacherOwnership;
}

/// Shared teacher/admin authorization for advice, attendance, grades,
/// announcements, and homework.
///
/// Decisions use stable IDs — never display names.
class TeacherAuthorizationService {
  const TeacherAuthorizationService({
    required this.authUid,
    required this.teacherDocId,
    required this.schoolId,
    required this.isAdmin,
    required this.isHomeroomOf,
    required this.isAssignedTo,
    required this.teachesInClass,
  });

  /// Firebase Auth uid of the signed-in user (may be null for local-only login).
  final String? authUid;

  /// Active teacher document id (`tch-…`).
  final String? teacherDocId;

  /// Active school id.
  final String? schoolId;

  final bool isAdmin;

  /// Whether [teacherDocId] is the homeroom teacher of [classId].
  final bool Function(String classId) isHomeroomOf;

  /// Whether [teacherDocId] is assigned to [classId] + [subjectId].
  final bool Function(String classId, int subjectId) isAssignedTo;

  /// Whether the teacher teaches any subject in [classId] (or is homeroom).
  final bool Function(String classId) teachesInClass;

  static const editDeniedMessage = 'Энэ мэдээллийг засах эрхгүй байна.';
  static const deleteDeniedMessage = 'Энэ мэдээллийг устгах эрхгүй байна.';
  static const ownRecordOnlyMessage =
      'Та зөвхөн өөрийн үүсгэсэн мэдээллийг засах боломжтой.';
  static const createDeniedMessage = 'Энэ мэдээллийг үүсгэх эрхгүй байна.';

  bool isSchoolAdmin() => isAdmin;

  bool isHomeroomTeacher(String classId) {
    final tid = teacherDocId?.trim();
    if (tid == null || tid.isEmpty) return false;
    return isHomeroomOf(classId);
  }

  bool isAssignedSubjectTeacher(String classId, int subjectId) {
    final tid = teacherDocId?.trim();
    if (tid == null || tid.isEmpty) return false;
    return isAssignedTo(classId, subjectId);
  }

  bool _sameSchool(String? recordSchoolId) {
    final active = schoolId?.trim();
    if (active == null || active.isEmpty) return false;
    final record = recordSchoolId?.trim();
    if (record == null || record.isEmpty) return true; // legacy: treat as active
    return record == active;
  }

  /// Owner by Firebase uid or teacher document id.
  bool isRecordOwner(RecordOwnership ownership) {
    if (isAdmin) return false; // admin path is separate; not "owner"
    final uid = authUid?.trim();
    final recordUid = ownership.createdByUid?.trim();
    if (uid != null &&
        uid.isNotEmpty &&
        recordUid != null &&
        recordUid.isNotEmpty) {
      return uid == recordUid;
    }
    final tid = teacherDocId?.trim();
    final recordTid = ownership.createdByTeacherId?.trim();
    if (tid != null &&
        tid.isNotEmpty &&
        recordTid != null &&
        recordTid.isNotEmpty) {
      return tid == recordTid;
    }
    return false;
  }

  bool canViewClass(String classId) {
    if (isAdmin) return _sameSchool(schoolId);
    if (isHomeroomTeacher(classId)) return true;
    return teachesInClass(classId);
  }

  bool canViewRecord({
    required TeacherRecordKind kind,
    required RecordOwnership ownership,
  }) {
    if (!_sameSchool(ownership.schoolId)) return false;
    if (isAdmin) return true;

    final classId = ownership.classId?.trim();
    if (classId == null || classId.isEmpty) return false;

    if (isHomeroomTeacher(classId)) return true;

    final subjectId = ownership.subjectId;
    if (subjectId != null && isAssignedSubjectTeacher(classId, subjectId)) {
      return true;
    }

    // Advice without subject: assigned teachers / authors can view if in class
    // scope they teach — fall back to owner or any assignment is checked by
    // screens via class student list. Homeroom already covered.
    if (kind == TeacherRecordKind.advice ||
        kind == TeacherRecordKind.announcement) {
      return canViewClass(classId);
    }
    return false;
  }

  bool canCreateRecord({
    required TeacherRecordKind kind,
    required String classId,
    int? subjectId,
    String? recordSchoolId,
  }) {
    if (!_sameSchool(recordSchoolId ?? schoolId)) return false;
    if (isAdmin) return true;

    switch (kind) {
      case TeacherRecordKind.grade:
      case TeacherRecordKind.homework:
      case TeacherRecordKind.attendance:
        if (subjectId == null) return false;
        return isAssignedSubjectTeacher(classId, subjectId);
      case TeacherRecordKind.advice:
        if (isHomeroomTeacher(classId)) return true;
        if (subjectId != null) {
          return isAssignedSubjectTeacher(classId, subjectId);
        }
        return false;
      case TeacherRecordKind.announcement:
        return teachesInClass(classId);
    }
  }

  bool canEditRecord({
    required TeacherRecordKind kind,
    required RecordOwnership ownership,
  }) {
    return _canModify(
      kind: kind,
      ownership: ownership,
      denyMessage: editDeniedMessage,
    );
  }

  bool canDeleteRecord({
    required TeacherRecordKind kind,
    required RecordOwnership ownership,
  }) {
    return _canModify(
      kind: kind,
      ownership: ownership,
      denyMessage: deleteDeniedMessage,
    );
  }

  bool _canModify({
    required TeacherRecordKind kind,
    required RecordOwnership ownership,
    required String denyMessage,
  }) {
    if (!_sameSchool(ownership.schoolId)) return false;
    if (isAdmin) return true;

    if (!ownership.hasAnyOwnership) {
      if (kDebugMode) {
        debugPrint(
          'OWNERSHIP_MISSING kind=$kind '
          'classId=${ownership.classId} subjectId=${ownership.subjectId} '
          '— teacher edit/delete denied',
        );
      }
      return false;
    }

    if (!isRecordOwner(ownership)) return false;

    final classId = ownership.classId?.trim();
    if (classId == null || classId.isEmpty) return false;

    // Owner must still be in a valid scope for the record kind.
    switch (kind) {
      case TeacherRecordKind.grade:
      case TeacherRecordKind.homework:
      case TeacherRecordKind.attendance:
        final subjectId = ownership.subjectId;
        if (subjectId == null) return false;
        return isAssignedSubjectTeacher(classId, subjectId);
      case TeacherRecordKind.advice:
        if (isHomeroomTeacher(classId)) return true;
        final subjectId = ownership.subjectId;
        if (subjectId != null) {
          return isAssignedSubjectTeacher(classId, subjectId);
        }
        return true;
      case TeacherRecordKind.announcement:
        return teachesInClass(classId);
    }
  }
}
