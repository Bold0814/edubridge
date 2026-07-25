import 'package:flutter/material.dart';

import '../../models/student.dart';
import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/learner_access_gate.dart';

/// Read-only attendance history for one child.
class GuardianAttendanceScreen extends StatelessWidget {
  const GuardianAttendanceScreen({
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
          final rows = store.attendanceEntriesForStudent(student);
          final teacher =
              store.homeroomTeacherForClass(student.className)?.fullName ??
              'Багш оноогоогүй';

          return Scaffold(
            backgroundColor: const Color(0xFFEEF4FA),
            appBar: AppBar(title: const Text('Ирц')),
            body: rows.isEmpty
                ? const Center(child: Text('Ирцийн бүртгэл байхгүй'))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    itemCount: rows.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.item),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return ListTile(
                        title: Text(row.record.date),
                        subtitle: Text('Багш: $teacher\nТэмдэглэл: —'),
                        isThreeLine: true,
                        trailing: StatusBadge(
                          label: row.status.label,
                          color: row.status.color,
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
