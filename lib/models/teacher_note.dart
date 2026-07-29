/// Priority for a short teacher note left for a student.
enum NotePriority {
  normal,
  high,
  urgent;

  String get label {
    switch (this) {
      case NotePriority.normal:
        return 'Энгийн';
      case NotePriority.high:
        return 'Чухал';
      case NotePriority.urgent:
        return 'Яаралтай';
    }
  }

  static NotePriority fromStorage(String raw) {
    return NotePriority.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => NotePriority.normal,
    );
  }

  String get storageValue => name;
}

/// Short advice / note from a teacher to one student.
class TeacherNote {
  const TeacherNote({
    required this.id,
    required this.studentId,
    required this.teacherId,
    this.subjectId,
    required this.createdAt,
    required this.title,
    required this.message,
    required this.priority,
    required this.isVisibleToGuardian,
    required this.isVisibleToStudent,
    this.schoolId,
    this.classId,
    this.createdByUid,
    this.updatedAt,
    this.updatedByUid,
  });

  final String id;
  final String studentId;

  /// Teacher document id of the author (canonical ownership teacher id).
  final String teacherId;
  final int? subjectId;
  final String createdAt;
  final String title;
  final String message;
  final NotePriority priority;
  final bool isVisibleToGuardian;
  final bool isVisibleToStudent;

  final String? schoolId;
  final String? classId;
  final String? createdByUid;
  final String? updatedAt;
  final String? updatedByUid;

  String get createdByTeacherId => teacherId;

  DateTime? get createdAtDate => DateTime.tryParse(createdAt);

  TeacherNote copyWith({
    String? studentId,
    String? teacherId,
    int? subjectId,
    bool clearSubjectId = false,
    String? createdAt,
    String? title,
    String? message,
    NotePriority? priority,
    bool? isVisibleToGuardian,
    bool? isVisibleToStudent,
    String? schoolId,
    String? classId,
    String? createdByUid,
    String? updatedAt,
    String? updatedByUid,
  }) {
    return TeacherNote(
      id: id,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      subjectId: clearSubjectId ? null : (subjectId ?? this.subjectId),
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      message: message ?? this.message,
      priority: priority ?? this.priority,
      isVisibleToGuardian: isVisibleToGuardian ?? this.isVisibleToGuardian,
      isVisibleToStudent: isVisibleToStudent ?? this.isVisibleToStudent,
      schoolId: schoolId ?? this.schoolId,
      classId: classId ?? this.classId,
      createdByUid: createdByUid ?? this.createdByUid,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUid: updatedByUid ?? this.updatedByUid,
    );
  }
}
