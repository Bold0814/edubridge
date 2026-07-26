/// Per-student homework completion tracked by teachers.
enum StudentHomeworkStatusValue {
  pending,
  completed,
  incomplete,
  late,
  excused;

  String get label {
    switch (this) {
      case StudentHomeworkStatusValue.pending:
        return 'Хүлээгдэж буй';
      case StudentHomeworkStatusValue.completed:
        return 'Хийсэн';
      case StudentHomeworkStatusValue.incomplete:
        return 'Хийгээгүй';
      case StudentHomeworkStatusValue.late:
        return 'Хоцорсон';
      case StudentHomeworkStatusValue.excused:
        return 'Чөлөөлсөн';
    }
  }

  String get storageValue => name;

  static StudentHomeworkStatusValue fromStorage(String? raw) {
    return StudentHomeworkStatusValue.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => StudentHomeworkStatusValue.pending,
    );
  }
}

class StudentHomeworkStatus {
  const StudentHomeworkStatus({
    required this.id,
    required this.schoolId,
    required this.classId,
    required this.homeworkId,
    required this.studentId,
    required this.status,
    this.checkedByTeacherId,
    this.checkedAt,
    this.teacherComment,
    required this.updatedAt,
    this.isActive = true,
  });

  final String id;
  final String schoolId;
  final String classId;
  final String homeworkId;
  final String studentId;
  final StudentHomeworkStatusValue status;
  final String? checkedByTeacherId;
  final DateTime? checkedAt;
  final String? teacherComment;
  final DateTime updatedAt;
  final bool isActive;

  StudentHomeworkStatus copyWith({
    StudentHomeworkStatusValue? status,
    String? checkedByTeacherId,
    DateTime? checkedAt,
    String? teacherComment,
    DateTime? updatedAt,
    bool? isActive,
    bool clearCheckedBy = false,
    bool clearCheckedAt = false,
    bool clearComment = false,
  }) {
    return StudentHomeworkStatus(
      id: id,
      schoolId: schoolId,
      classId: classId,
      homeworkId: homeworkId,
      studentId: studentId,
      status: status ?? this.status,
      checkedByTeacherId: clearCheckedBy
          ? null
          : (checkedByTeacherId ?? this.checkedByTeacherId),
      checkedAt: clearCheckedAt ? null : (checkedAt ?? this.checkedAt),
      teacherComment: clearComment
          ? null
          : (teacherComment ?? this.teacherComment),
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
