import 'app_role.dart';

/// Root school entity for multi-school context.
class School {
  const School({
    required this.id,
    required this.name,
    this.code,
    this.address,
    this.isActive = true,
    this.loginPrefix,
    this.studentCodeSeq = 0,
  });

  final String id;
  final String name;
  final String? code;
  final String? address;
  final bool isActive;

  /// Stable prefix for generated student codes (e.g. `133` → `133-S0001`).
  final String? loginPrefix;

  /// Last allocated student-code sequence for this school (never decreases).
  final int studentCodeSeq;

  School copyWith({
    String? name,
    String? code,
    String? address,
    bool? isActive,
    String? loginPrefix,
    int? studentCodeSeq,
    bool clearCode = false,
    bool clearAddress = false,
    bool clearLoginPrefix = false,
  }) {
    return School(
      id: id,
      name: name ?? this.name,
      code: clearCode ? null : (code ?? this.code),
      address: clearAddress ? null : (address ?? this.address),
      isActive: isActive ?? this.isActive,
      loginPrefix: clearLoginPrefix ? null : (loginPrefix ?? this.loginPrefix),
      studentCodeSeq: studentCodeSeq ?? this.studentCodeSeq,
    );
  }
}

/// Links a user account to a school with a concrete role.
class UserSchoolMembership {
  const UserSchoolMembership({
    required this.id,
    required this.userId,
    required this.schoolId,
    required this.role,
    this.teacherId,
    this.guardianId,
    this.studentId,
    this.isActive = true,
  });

  final String id;
  final String userId;
  final String schoolId;
  final AppRole role;
  final String? teacherId;
  final String? guardianId;
  final String? studentId;
  final bool isActive;

  String? get linkedEntityId {
    switch (role) {
      case AppRole.admin:
        return teacherId;
      case AppRole.teacher:
        return teacherId;
      case AppRole.guardian:
        return guardianId;
      case AppRole.student:
        return studentId;
    }
  }

  UserSchoolMembership copyWith({bool? isActive}) {
    return UserSchoolMembership(
      id: id,
      userId: userId,
      schoolId: schoolId,
      role: role,
      teacherId: teacherId,
      guardianId: guardianId,
      studentId: studentId,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Single active session context — lives inside [AppStore], not a second store.
class ActiveAppContext {
  const ActiveAppContext({
    this.userId,
    this.schoolId,
    this.role,
    this.teacherId,
    this.guardianId,
    this.studentId,
    this.selectedChildId,
    this.classId,
    this.subjectId,
  });

  static const empty = ActiveAppContext();

  final String? userId;
  final String? schoolId;
  final AppRole? role;
  final String? teacherId;
  final String? guardianId;
  final String? studentId;
  final String? selectedChildId;
  final String? classId;
  final int? subjectId;

  ActiveAppContext copyWith({
    String? userId,
    String? schoolId,
    AppRole? role,
    String? teacherId,
    String? guardianId,
    String? studentId,
    String? selectedChildId,
    String? classId,
    int? subjectId,
    bool clearUserId = false,
    bool clearSchoolId = false,
    bool clearRole = false,
    bool clearTeacherId = false,
    bool clearGuardianId = false,
    bool clearStudentId = false,
    bool clearSelectedChildId = false,
    bool clearClassId = false,
    bool clearSubjectId = false,
  }) {
    return ActiveAppContext(
      userId: clearUserId ? null : (userId ?? this.userId),
      schoolId: clearSchoolId ? null : (schoolId ?? this.schoolId),
      role: clearRole ? null : (role ?? this.role),
      teacherId: clearTeacherId ? null : (teacherId ?? this.teacherId),
      guardianId: clearGuardianId ? null : (guardianId ?? this.guardianId),
      studentId: clearStudentId ? null : (studentId ?? this.studentId),
      selectedChildId: clearSelectedChildId
          ? null
          : (selectedChildId ?? this.selectedChildId),
      classId: clearClassId ? null : (classId ?? this.classId),
      subjectId: clearSubjectId ? null : (subjectId ?? this.subjectId),
    );
  }
}
