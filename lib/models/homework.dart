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
}

class Homework {
  const Homework({
    required this.className,
    required this.subject,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
  });

  final String className;
  final String subject;
  final String title;
  final String description;
  final String dueDate;
  final HomeworkStatus status;
}
