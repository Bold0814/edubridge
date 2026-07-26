import 'package:flutter/material.dart';

import '../../models/homework.dart';
import '../../models/student.dart';
import '../../models/student_homework_status.dart';
import '../../state/app_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/learner_access_gate.dart';

/// Read-only homework list for the child's class (guardian / student).
class GuardianHomeworkScreen extends StatelessWidget {
  const GuardianHomeworkScreen({
    super.key,
    required this.store,
    required this.student,
  });

  final AppStore store;
  final Student student;

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
        return AppColors.homework;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LearnerAccessGate(
      store: store,
      student: student,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.homeworkForStudentClass(student);

          return Scaffold(
            backgroundColor: const Color(0xFFEEF4FA),
            appBar: AppBar(title: const Text('Даалгавар')),
            body: items.isEmpty
                ? const Center(child: Text('Даалгавар байхгүй'))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.item),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final teacher =
                          store
                              .teacherForClassSubjectName(
                                student.className,
                                item.subject,
                              )
                              ?.fullName ??
                          'Багш оноогоогүй';
                      final status = store.effectiveHomeworkStatus(
                        homeworkId: item.id,
                        studentId: student.id,
                      );
                      final comment = store
                          .homeworkStatusForStudent(
                            homeworkId: item.id,
                            studentId: student.id,
                          )
                          ?.teacherComment
                          ?.trim();

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.card),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  StatusBadge(
                                    label: status.label,
                                    color: _statusColor(status),
                                    compact: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.itemSm),
                              Text(
                                '${item.subject}\n'
                                '${item.description}\n'
                                'Хугацаа: ${item.dueDate}\n'
                                'Багш: $teacher',
                              ),
                              if (comment != null && comment.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.item),
                                Text(
                                  'Багшийн тайлбар: $comment',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Даалгаврын төлөв: ${item.status.label}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color:
                                          item.status == HomeworkStatus.pending
                                          ? AppColors.homework
                                          : AppColors.success,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
