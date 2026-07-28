/// Models for admin school data reset (SQLite now; Cloud Function later).
library;

/// Confirmation phrase the admin must type exactly.
const kSchoolResetConfirmationPhrase = 'УСТГАХ';

/// Which operational datasets to clear for [schoolId].
class SchoolResetScope {
  const SchoolResetScope({
    this.structurePeople = true,
    this.academicRecords = true,
    this.journalAndComms = true,
    this.scheduleAndAssignments = true,
    this.resetSchoolSettings = false,
  });

  /// Багш, анги, сурагч, хичээл, асран хамгаалагч.
  final bool structurePeople;

  /// Ирц, дүн, даалгавар.
  final bool academicRecords;

  /// Журнал, зарлал, тэмдэглэл.
  final bool journalAndComms;

  /// Хуваарь болон оноолт.
  final bool scheduleAndAssignments;

  /// Сургуулийн үндсэн тохиргоог шинэчлэх (optional).
  final bool resetSchoolSettings;

  SchoolResetScope copyWith({
    bool? structurePeople,
    bool? academicRecords,
    bool? journalAndComms,
    bool? scheduleAndAssignments,
    bool? resetSchoolSettings,
  }) {
    return SchoolResetScope(
      structurePeople: structurePeople ?? this.structurePeople,
      academicRecords: academicRecords ?? this.academicRecords,
      journalAndComms: journalAndComms ?? this.journalAndComms,
      scheduleAndAssignments:
          scheduleAndAssignments ?? this.scheduleAndAssignments,
      resetSchoolSettings: resetSchoolSettings ?? this.resetSchoolSettings,
    );
  }

  bool get hasAnySelection =>
      structurePeople ||
      academicRecords ||
      journalAndComms ||
      scheduleAndAssignments ||
      resetSchoolSettings;
}

/// Live counts shown before deletion (school-scoped).
class ResetPreview {
  const ResetPreview({
    required this.schoolId,
    required this.teacherCount,
    required this.classCount,
    required this.subjectCount,
    required this.studentCount,
    required this.guardianCount,
    required this.attendanceCount,
    required this.gradeCount,
    required this.homeworkCount,
    required this.journalCount,
    required this.announcementCount,
  });

  final String schoolId;
  final int teacherCount;
  final int classCount;
  final int subjectCount;
  final int studentCount;
  final int guardianCount;
  final int attendanceCount;
  final int gradeCount;
  final int homeworkCount;
  final int journalCount;
  final int announcementCount;

  Map<String, int> get labeledCounts => {
    'Багш': teacherCount,
    'Анги': classCount,
    'Хичээл': subjectCount,
    'Сурагч': studentCount,
    'Асран хамгаалагч': guardianCount,
    'Ирцийн бүртгэл': attendanceCount,
    'Дүн': gradeCount,
    'Даалгавар': homeworkCount,
    'Журнал': journalCount,
    'Зарлал': announcementCount,
  };
}

/// How many rows were removed in a successful reset.
class ResetDeletedCounts {
  const ResetDeletedCounts({
    this.teachers = 0,
    this.classes = 0,
    this.subjects = 0,
    this.students = 0,
    this.guardians = 0,
    this.attendance = 0,
    this.grades = 0,
    this.homework = 0,
    this.journals = 0,
    this.announcements = 0,
    this.other = 0,
  });

  final int teachers;
  final int classes;
  final int subjects;
  final int students;
  final int guardians;
  final int attendance;
  final int grades;
  final int homework;
  final int journals;
  final int announcements;
  final int other;

  int get total =>
      teachers +
      classes +
      subjects +
      students +
      guardians +
      attendance +
      grades +
      homework +
      journals +
      announcements +
      other;
}

/// Result of an operational reset (never includes credentials).
class SchoolResetResult {
  const SchoolResetResult({
    required this.schoolId,
    required this.adminUserId,
    required this.scope,
    required this.deleted,
    required this.completedAt,
  });

  final String schoolId;
  final String adminUserId;
  final SchoolResetScope scope;
  final ResetDeletedCounts deleted;
  final DateTime completedAt;
}

/// Audit payload for requested / completed resets (no passwords).
class ResetAuditEntry {
  const ResetAuditEntry({
    required this.actionType,
    required this.schoolId,
    required this.adminUserId,
    required this.requestedAt,
    required this.scope,
    this.completedAt,
    this.deleted,
  });

  final String actionType;
  final String schoolId;
  final String adminUserId;
  final DateTime requestedAt;
  final SchoolResetScope scope;
  final DateTime? completedAt;
  final ResetDeletedCounts? deleted;
}

/// Full school deletion is not available until a protected backend exists.
class SchoolDeleteUnavailableException implements Exception {
  const SchoolDeleteUnavailableException([
    this.message =
        'Энэ үйлдэл онлайн хамгаалалт бүрэн тохирсны дараа идэвхжинэ.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class SchoolResetPermissionException implements Exception {
  const SchoolResetPermissionException([
    this.message = 'Энэ үйлдлийг хийх эрхгүй байна.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class SchoolResetValidationException implements Exception {
  const SchoolResetValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
