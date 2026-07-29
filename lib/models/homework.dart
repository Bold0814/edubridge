enum HomeworkStatus {
  pending,
  done;

  String get label {
    switch (this) {
      case HomeworkStatus.pending:
        return 'Шинэ';
      case HomeworkStatus.done:
        return 'Дууссан';
    }
  }

  static HomeworkStatus fromStorage(String raw) {
    return raw == 'done' ? HomeworkStatus.done : HomeworkStatus.pending;
  }

  String get storageValue => name;
}

class Homework {
  const Homework({
    required this.id,
    required this.className,
    required this.subject,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    this.schoolId,
    this.subjectId,
    this.createdByUid,
    this.createdByTeacherId,
    this.createdAt,
    this.updatedAt,
    this.updatedByUid,
  });

  final String id;
  final String className;
  final String subject;
  final String title;
  final String description;
  final String dueDate;
  final HomeworkStatus status;

  final String? schoolId;
  final int? subjectId;
  final String? createdByUid;
  final String? createdByTeacherId;
  final String? createdAt;
  final String? updatedAt;
  final String? updatedByUid;

  String get classId => className;

  Homework copyWith({
    String? subject,
    String? title,
    String? description,
    String? dueDate,
    HomeworkStatus? status,
    String? schoolId,
    int? subjectId,
    String? createdByUid,
    String? createdByTeacherId,
    String? createdAt,
    String? updatedAt,
    String? updatedByUid,
  }) {
    return Homework(
      id: id,
      className: className,
      subject: subject ?? this.subject,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      schoolId: schoolId ?? this.schoolId,
      subjectId: subjectId ?? this.subjectId,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByTeacherId: createdByTeacherId ?? this.createdByTeacherId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUid: updatedByUid ?? this.updatedByUid,
    );
  }
}
