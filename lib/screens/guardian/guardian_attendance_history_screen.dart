import 'package:flutter/material.dart';

import '../../models/student.dart';
import '../../services/app_clock.dart';
import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/learner_access_gate.dart';

/// Append-only attendance change history for one child (newest first).
///
/// Includes today's changes. Each row is one save event (date + time + status).
class GuardianAttendanceHistoryScreen extends StatelessWidget {
  const GuardianAttendanceHistoryScreen({
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

          return Scaffold(
            backgroundColor: const Color(0xFFEEF4FA),
            appBar: AppBar(title: const Text('Ирцийн түүх')),
            body: rows.isEmpty
                ? const Center(child: Text('Ирцийн бүртгэл байхгүй'))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    itemCount: rows.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.item),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final record = row.record;
                      final dateLabel = record.displayDateLabel;
                      final timeLabel = AppClock.formatTime(record.recordedAt);
                      final teacher = store.teacherNameForAttendance(record);
                      final note = row.note?.trim();
                      final lines = <String>[
                        timeLabel,
                        'Багш: $teacher',
                        if (note != null && note.isNotEmpty) 'Тэмдэглэл: $note',
                      ];
                      return ListTile(
                        title: Text(dateLabel),
                        subtitle: Text(lines.join('\n')),
                        isThreeLine: lines.length >= 3,
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
