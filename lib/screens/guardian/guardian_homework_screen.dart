import 'package:flutter/material.dart';

import '../../models/homework.dart';
import '../../models/student.dart';
import '../../state/app_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/learner_access_gate.dart';

/// Read-only homework list for the child's class.
class GuardianHomeworkScreen extends StatelessWidget {
  const GuardianHomeworkScreen({
    super.key,
    required this.store,
    required this.student,
  });

  final AppStore store;
  final Student student;

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
                      return Card(
                        child: ListTile(
                          title: Text(item.title),
                          subtitle: Text(
                            '${item.subject}\n'
                            '${item.description}\n'
                            'Хугацаа: ${item.dueDate}\n'
                            'Багш: $teacher',
                          ),
                          isThreeLine: true,
                          trailing: StatusBadge(
                            label: item.status.label,
                            color: item.status == HomeworkStatus.pending
                                ? AppColors.homework
                                : AppColors.success,
                            compact: true,
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
