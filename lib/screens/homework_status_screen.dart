import 'package:flutter/material.dart';

import '../models/homework.dart';
import '../models/student.dart';
import '../models/student_homework_status.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Teacher: per-student homework completion chips + optional comment.
class HomeworkStatusScreen extends StatelessWidget {
  const HomeworkStatusScreen({
    super.key,
    required this.store,
    required this.homework,
  });

  final AppStore store;
  final Homework homework;

  static const _writableStatuses = <StudentHomeworkStatusValue>[
    StudentHomeworkStatusValue.completed,
    StudentHomeworkStatusValue.incomplete,
    StudentHomeworkStatusValue.late,
    StudentHomeworkStatusValue.excused,
  ];

  Future<void> _setStatus(
    BuildContext context, {
    required Student student,
    required StudentHomeworkStatusValue status,
  }) async {
    try {
      final existing = store.homeworkStatusForStudent(
        homeworkId: homework.id,
        studentId: student.id,
      );
      await store.setStudentHomeworkStatus(
        homeworkId: homework.id,
        studentId: student.id,
        status: status,
        teacherComment: existing?.teacherComment,
      );
    } on PermissionDeniedException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Энэ үйлдлийг хийх эрхгүй байна')),
      );
    }
  }

  Future<void> _editComment(BuildContext context, Student student) async {
    final existing = store.homeworkStatusForStudent(
      homeworkId: homework.id,
      studentId: student.id,
    );
    final controller = TextEditingController(
      text: existing?.teacherComment ?? '',
    );
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${student.fullName} · Тайлбар'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Багшийн тайлбар',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Болих'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Хадгалах'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (saved == null || !context.mounted) return;

    final status = store.effectiveHomeworkStatus(
      homeworkId: homework.id,
      studentId: student.id,
    );
    try {
      await store.setStudentHomeworkStatus(
        homeworkId: homework.id,
        studentId: student.id,
        status: status,
        teacherComment: saved,
      );
    } on PermissionDeniedException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Энэ үйлдлийг хийх эрхгүй байна')),
      );
    }
  }

  Color _statusColor(StudentHomeworkStatusValue status) {
    switch (status) {
      case StudentHomeworkStatusValue.completed:
        return AppColors.success;
      case StudentHomeworkStatusValue.incomplete:
        return AppColors.absent;
      case StudentHomeworkStatusValue.late:
        return AppColors.late;
      case StudentHomeworkStatusValue.excused:
        return AppColors.warning;
      case StudentHomeworkStatusValue.pending:
        return AppColors.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final students = store.studentsFor(homework.className);

        return Scaffold(
          appBar: AppBar(title: const Text('Гүйцэтгэл'), centerTitle: true),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text(
                homework.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${homework.subject} · ${homework.dueDate}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              if (students.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Сурагч бүртгэлгүй')),
                )
              else
                ...students.map((student) {
                  final status = store.effectiveHomeworkStatus(
                    homeworkId: homework.id,
                    studentId: student.id,
                  );
                  final row = store.homeworkStatusForStudent(
                    homeworkId: homework.id,
                    studentId: student.id,
                  );
                  final comment = row?.teacherComment?.trim();

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.item),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.card),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  student.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                status.label,
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.item),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final value in _writableStatuses)
                                ChoiceChip(
                                  label: Text(value.label),
                                  selected: status == value,
                                  onSelected: (_) => _setStatus(
                                    context,
                                    student: student,
                                    status: value,
                                  ),
                                  selectedColor: _statusColor(
                                    value,
                                  ).withValues(alpha: 0.2),
                                  labelStyle: TextStyle(
                                    color: status == value
                                        ? _statusColor(value)
                                        : null,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.itemSm),
                          if (comment != null && comment.isNotEmpty)
                            Text(
                              comment,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _editComment(context, student),
                              icon: const Icon(
                                Icons.comment_outlined,
                                size: 18,
                              ),
                              label: Text(
                                comment == null || comment.isEmpty
                                    ? 'Тайлбар нэмэх'
                                    : 'Тайлбар засах',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
