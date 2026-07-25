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
  });

  final String id;
  final String className;
  final String subject;
  final String title;
  final String description;
  final String dueDate;
  final HomeworkStatus status;

  Homework copyWith({
    String? subject,
    String? title,
    String? description,
    String? dueDate,
    HomeworkStatus? status,
  }) {
    return Homework(
      id: id,
      className: className,
      subject: subject ?? this.subject,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
    );
  }
}
