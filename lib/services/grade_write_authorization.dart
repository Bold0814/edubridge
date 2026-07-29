import '../models/firestore_class_subject_teacher.dart';
import '../models/firestore_teacher.dart';

/// Result of a grade permission check (shared by all grade screens).
class GradePermissionResult {
  const GradePermissionResult.allowed()
    : allowed = true,
      denialReason = null;

  const GradePermissionResult.denied(this.denialReason) : allowed = false;

  final bool allowed;

  /// Stable internal reason key for debug UI (never a secret).
  final String? denialReason;

  static const notSignedInTeacher = 'teacher_session_missing';
  static const teacherProfileMissing = 'teacher_profile_not_found';
  static const teacherNotLinked = 'teacher_profile_not_linked';
  static const subjectMissing = 'subject_not_found';
  static const assignmentMissing = 'subject_assignment_not_found';
  static const schoolMismatch = 'school_mismatch';
  static const firestoreDenied = 'firestore_rule_denied';

  String get debugLabel {
    switch (denialReason) {
      case notSignedInTeacher:
        return 'teacher session missing';
      case teacherProfileMissing:
        return 'teacher profile not found';
      case teacherNotLinked:
        return 'teacher profile not linked';
      case subjectMissing:
        return 'subject not found';
      case assignmentMissing:
        return 'subject assignment not found';
      case schoolMismatch:
        return 'school mismatch';
      case firestoreDenied:
        return 'Firestore rule denied';
      default:
        return denialReason ?? 'unknown';
    }
  }
}

/// Mirrors Firestore security rule checks for grade create (unit-testable).
///
/// Authorization is by Firebase Auth uid ↔ teacher.authUid and by
/// class/subject assignment documents — never by display name.
class GradeWriteAuthorization {
  const GradeWriteAuthorization();

  /// Whether [authUid] may create a grade for [schoolId]/[classId]/[subjectId].
  bool canCreateGrade({
    required String? authUid,
    required String schoolId,
    required String classId,
    required int subjectId,
    required String gradeTeacherId,
    required FirestoreTeacher? teacherDoc,
    required FirestoreClassSubjectTeacher? assignmentDoc,
    required String? membershipRole,
    required bool membershipActive,
    required String? membershipSchoolId,
  }) {
    return evaluateCreateGrade(
          authUid: authUid,
          schoolId: schoolId,
          classId: classId,
          subjectId: subjectId,
          gradeTeacherId: gradeTeacherId,
          teacherDoc: teacherDoc,
          assignmentDoc: assignmentDoc,
          membershipRole: membershipRole,
          membershipActive: membershipActive,
          membershipSchoolId: membershipSchoolId,
        ).allowed;
  }

  GradePermissionResult evaluateCreateGrade({
    required String? authUid,
    required String schoolId,
    required String classId,
    required int subjectId,
    required String gradeTeacherId,
    required FirestoreTeacher? teacherDoc,
    required FirestoreClassSubjectTeacher? assignmentDoc,
    required String? membershipRole,
    required bool membershipActive,
    required String? membershipSchoolId,
  }) {
    if (authUid == null || authUid.trim().isEmpty) {
      return const GradePermissionResult.denied(
        GradePermissionResult.notSignedInTeacher,
      );
    }
    if (schoolId.trim().isEmpty || classId.trim().isEmpty) {
      return const GradePermissionResult.denied(
        GradePermissionResult.schoolMismatch,
      );
    }
    if (!membershipActive || membershipSchoolId != schoolId) {
      return const GradePermissionResult.denied(
        GradePermissionResult.schoolMismatch,
      );
    }

    if (membershipRole == 'schoolAdmin') {
      return const GradePermissionResult.allowed();
    }

    if (membershipRole != 'teacher') {
      return const GradePermissionResult.denied(
        GradePermissionResult.firestoreDenied,
      );
    }

    if (teacherDoc == null) {
      return const GradePermissionResult.denied(
        GradePermissionResult.teacherProfileMissing,
      );
    }
    if (assignmentDoc == null) {
      return const GradePermissionResult.denied(
        GradePermissionResult.assignmentMissing,
      );
    }
    if (teacherDoc.id != gradeTeacherId) {
      return const GradePermissionResult.denied(
        GradePermissionResult.assignmentMissing,
      );
    }
    if (teacherDoc.schoolId != schoolId) {
      return const GradePermissionResult.denied(
        GradePermissionResult.schoolMismatch,
      );
    }
    final linked = teacherDoc.authUid?.trim();
    if (linked == null || linked.isEmpty || linked != authUid) {
      return const GradePermissionResult.denied(
        GradePermissionResult.teacherNotLinked,
      );
    }
    if (assignmentDoc.schoolId != schoolId ||
        assignmentDoc.classId != classId ||
        assignmentDoc.subjectId != subjectId ||
        assignmentDoc.teacherId != gradeTeacherId) {
      return const GradePermissionResult.denied(
        GradePermissionResult.assignmentMissing,
      );
    }
    return const GradePermissionResult.allowed();
  }

  /// Display-name matching must never grant access.
  bool canCreateByDisplayNameAlone({
    required String authUid,
    required String teacherFullName,
    required String requestedName,
  }) {
    return false;
  }
}
