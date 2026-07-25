import 'package:flutter/material.dart';

import '../../models/student.dart';
import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/learner_access_gate.dart';

/// Read-only grades for one child.
class GuardianGradesScreen extends StatelessWidget {
  const GuardianGradesScreen({
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
          final grades = store.gradesForStudent(student);

          return Scaffold(
            backgroundColor: const Color(0xFFEEF4FA),
            appBar: AppBar(title: const Text('Дүн')),
            body: grades.isEmpty
                ? const Center(child: Text('Дүн байхгүй'))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    itemCount: grades.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.item),
                    itemBuilder: (context, index) {
                      final grade = grades[index];
                      final teacher =
                          store
                              .teacherForClassSubjectName(
                                student.className,
                                grade.subject,
                              )
                              ?.fullName ??
                          'Багш оноогоогүй';
                      return Card(
                        child: ListTile(
                          title: Text(grade.subject),
                          subtitle: Text(
                            'Улирал: ${grade.term}\n'
                            'Багш: $teacher',
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            grade.scoreWithLetter,
                            style: Theme.of(context).textTheme.titleMedium,
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
