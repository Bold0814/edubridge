import 'package:flutter/material.dart';

import '../../models/attendance_record.dart';
import '../../models/student.dart';
import '../../services/app_clock.dart';
import '../../services/school_date.dart';
import '../../state/app_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/learner_access_gate.dart';
import 'guardian_attendance_history_screen.dart';

/// Today's attendance only (Asia/Ulaanbaatar dateKey).
///
/// Never shows yesterday or other history when today is missing.
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
          final todayKey = AppClock.todayKey();
          // Same history source as Түүх — latest entry for today only.
          final today = store.todaysAttendanceForStudent(student);
          final teacher = today != null
              ? store.teacherNameForAttendance(today.record)
              : (store.homeroomTeacherForClass(student.className)?.fullName ??
                    'Багш оноогоогүй');
          final note = today?.note?.trim();
          final subtitleLines = <String>[
            'Багш: $teacher',
            if (note != null && note.isNotEmpty) 'Тэмдэглэл: $note',
          ];

          final status = today?.status;
          final present = status == AttendanceStatus.present ? 1 : 0;
          final late = status == AttendanceStatus.late ? 1 : 0;
          final absent = status == AttendanceStatus.absent ? 1 : 0;

          return Scaffold(
            backgroundColor: const Color(0xFFEEF4FA),
            appBar: AppBar(
              title: const Text('Өнөөдрийн ирц'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => GuardianAttendanceHistoryScreen(
                          store: store,
                          student: student,
                        ),
                      ),
                    );
                  },
                  child: const Text('Түүх'),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                Text(
                  SchoolDate.displayLabel(todayKey),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.gap),
                Card(
                  child: ListTile(
                    title: Text(
                      status?.label ?? 'Бүртгэгдээгүй',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: status?.color ?? AppColors.onSurfaceVariant,
                      ),
                    ),
                    subtitle: Text(subtitleLines.join('\n')),
                    isThreeLine: subtitleLines.length > 1,
                    trailing: status == null
                        ? null
                        : StatusBadge(label: status.label, color: status.color),
                  ),
                ),
                const SizedBox(height: AppSpacing.gap),
                Text(
                  'Ирсэн: $present · Хоцорсон: $late · Тасалсан: $absent',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
