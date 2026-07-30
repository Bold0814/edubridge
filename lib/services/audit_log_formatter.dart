import '../models/attendance_record.dart';
import '../models/grade.dart';

/// Display helpers for audit log old/new values.
abstract final class AuditLogFormatter {
  static String attendanceSummary(AttendanceRecord record) {
    final present = record.presentCount;
    final late = record.lateCount;
    final absent = record.absentCount;
    return 'Ирсэн $present · Хоцорсон $late · Тасалсан $absent';
  }

  /// Prefer a single-student status change label when exactly one differs.
  static ({String? oldValue, String? newValue, String? studentId})
  attendanceChange(AttendanceRecord? before, AttendanceRecord after) {
    if (before == null) {
      return (
        oldValue: null,
        newValue: attendanceSummary(after),
        studentId: null,
      );
    }
    final beforeMap = <String, AttendanceStatus>{};
    for (final e in before.entries ?? const <StudentAttendanceEntry>[]) {
      final key = (e.studentId != null && e.studentId!.isNotEmpty)
          ? e.studentId!
          : e.studentName;
      beforeMap[key] = e.status;
    }
    final changes = <({String key, AttendanceStatus from, AttendanceStatus to})>[];
    for (final e in after.entries ?? const <StudentAttendanceEntry>[]) {
      final key = (e.studentId != null && e.studentId!.isNotEmpty)
          ? e.studentId!
          : e.studentName;
      final prior = beforeMap[key];
      if (prior != null && prior != e.status) {
        changes.add((key: key, from: prior, to: e.status));
      }
    }
    if (changes.length == 1) {
      final only = changes.first;
      return (
        oldValue: only.from.label,
        newValue: only.to.label,
        studentId: only.key.startsWith('stu') || only.key.contains('-')
            ? only.key
            : null,
      );
    }
    return (
      oldValue: attendanceSummary(before),
      newValue: attendanceSummary(after),
      studentId: null,
    );
  }

  static String gradeValue(Grade grade) => grade.scoreWithLetter;

  static String? truncate(String? raw, {int max = 120}) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    if (text.length <= max) return text;
    return '${text.substring(0, max)}…';
  }
}
