import 'package:flutter/material.dart';

enum AttendanceStatus {
  present,
  late,
  absent;

  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return 'Ирсэн';
      case AttendanceStatus.late:
        return 'Хоцорсон';
      case AttendanceStatus.absent:
        return 'Тасалсан';
    }
  }

  Color get color {
    switch (this) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.late:
        return Colors.orange;
      case AttendanceStatus.absent:
        return Colors.red;
    }
  }
}

class StudentAttendanceEntry {
  const StudentAttendanceEntry({
    required this.studentName,
    required this.status,
  });

  final String studentName;
  final AttendanceStatus status;
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.date,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
  });

  final String date;
  final int presentCount;
  final int lateCount;
  final int absentCount;

  String get detailText =>
      'Ирсэн: $presentCount • Хоцорсон: $lateCount • Тасалсан: $absentCount';
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.date,
    required this.className,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    this.entries,
    this.status,
  });

  const AttendanceRecord.legacy({required this.date, required this.status})
    : className = '',
      presentCount = 0,
      lateCount = 0,
      absentCount = 0,
      entries = null;

  factory AttendanceRecord.detailed({
    required String date,
    required String className,
    required List<StudentAttendanceEntry> entries,
  }) {
    final presentCount = entries
        .where((e) => e.status == AttendanceStatus.present)
        .length;
    final lateCount = entries
        .where((e) => e.status == AttendanceStatus.late)
        .length;
    final absentCount = entries
        .where((e) => e.status == AttendanceStatus.absent)
        .length;

    return AttendanceRecord(
      date: date,
      className: className,
      presentCount: presentCount,
      lateCount: lateCount,
      absentCount: absentCount,
      entries: List<StudentAttendanceEntry>.unmodifiable(entries),
    );
  }

  final String date;
  final String className;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final List<StudentAttendanceEntry>? entries;
  final AttendanceStatus? status;

  bool get hasStudentDetails => entries != null && entries!.isNotEmpty;

  bool get isLegacy => !hasStudentDetails && status != null;

  String get summaryText =>
      'Ирсэн: $presentCount • Хоцорсон: $lateCount • Тасалсан: $absentCount';

  AttendanceSummary get asSummary => AttendanceSummary(
    date: date,
    presentCount: presentCount,
    lateCount: lateCount,
    absentCount: absentCount,
  );

  static final RegExp _mongolianDatePattern = RegExp(
    r'^(\d+)\s*оны\s*(\d+)\s*сарын\s*(\d+)$',
  );

  /// Parses dates like `2026 оны 7 сарын 24` into a calendar day (no time).
  static DateTime? tryParseCalendarDate(String rawDate) {
    final match = _mongolianDatePattern.firstMatch(rawDate.trim());
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  /// Compares only year/month/day (ignores time-of-day).
  bool isOnCalendarDay(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    final trimmed = date.trim();
    if (trimmed == 'Өнөөдөр') {
      final now = DateTime.now();
      return target.year == now.year &&
          target.month == now.month &&
          target.day == now.day;
    }

    final parsed = tryParseCalendarDate(date);
    if (parsed == null) return false;
    return parsed.year == target.year &&
        parsed.month == target.month &&
        parsed.day == target.day;
  }
}
