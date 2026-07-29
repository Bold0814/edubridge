import 'package:flutter/material.dart';

import '../services/app_clock.dart';
import '../services/school_date.dart';
import '../theme/app_colors.dart';

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
        return AppColors.present;
      case AttendanceStatus.late:
        return AppColors.late;
      case AttendanceStatus.absent:
        return AppColors.absent;
    }
  }
}

class StudentAttendanceEntry {
  const StudentAttendanceEntry({
    required this.studentName,
    required this.status,
    this.studentId,
    this.note,
  });

  final String studentName;
  final AttendanceStatus status;

  /// Stable student id when known (preferred over name matching).
  final String? studentId;

  /// Optional per-student note for this attendance event.
  final String? note;

  /// Trimmed note, or null when blank.
  String? get normalizedNote {
    final raw = note?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }
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
    required this.id,
    required this.date,
    required this.className,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    this.entries,
    this.status,
    this.dateKey,
    this.schoolId,
    this.recordedAt,
    this.subjectId,
    this.recordedByTeacherId,
    this.note,
    this.createdByUid,
    this.updatedByUid,
  });

  const AttendanceRecord.legacy({
    required this.id,
    required this.date,
    required this.status,
  }) : className = '',
       presentCount = 0,
       lateCount = 0,
       absentCount = 0,
       entries = null,
       dateKey = null,
       schoolId = null,
       recordedAt = null,
       subjectId = null,
       recordedByTeacherId = null,
       note = null,
       createdByUid = null,
       updatedByUid = null;

  factory AttendanceRecord.detailed({
    required String id,
    required String date,
    required String className,
    required List<StudentAttendanceEntry> entries,
    String? dateKey,
    String? schoolId,
    DateTime? recordedAt,
    int? subjectId,
    String? recordedByTeacherId,
    String? note,
    String? createdByUid,
    String? updatedByUid,
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
      id: id,
      date: date,
      className: className,
      presentCount: presentCount,
      lateCount: lateCount,
      absentCount: absentCount,
      entries: List<StudentAttendanceEntry>.unmodifiable(entries),
      dateKey: dateKey,
      schoolId: schoolId,
      recordedAt: recordedAt,
      subjectId: subjectId,
      recordedByTeacherId: recordedByTeacherId,
      note: note,
      createdByUid: createdByUid,
      updatedByUid: updatedByUid,
    );
  }

  final String id;

  /// Display label (Mongolian date text or legacy `Өнөөдөр`).
  final String date;
  final String className;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final List<StudentAttendanceEntry>? entries;
  final AttendanceStatus? status;

  /// Stable local calendar key `yyyy-MM-dd` (preferred for matching).
  final String? dateKey;

  final String? schoolId;
  final DateTime? recordedAt;

  /// Teaching subject for this roll.
  final int? subjectId;

  /// Teacher who recorded this history entry.
  final String? recordedByTeacherId;

  /// Optional note for this attendance change.
  final String? note;

  final String? createdByUid;
  final String? updatedByUid;

  String? get createdByTeacherId => recordedByTeacherId;

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

  AttendanceRecord copyWith({
    String? id,
    String? date,
    String? className,
    int? presentCount,
    int? lateCount,
    int? absentCount,
    List<StudentAttendanceEntry>? entries,
    AttendanceStatus? status,
    String? dateKey,
    String? schoolId,
    DateTime? recordedAt,
    int? subjectId,
    bool clearSubjectId = false,
    String? recordedByTeacherId,
    String? note,
    bool clearNote = false,
    String? createdByUid,
    String? updatedByUid,
  }) {
    final nextEntries = entries ?? this.entries;
    final present =
        presentCount ??
        (nextEntries == null
            ? this.presentCount
            : nextEntries
                  .where((e) => e.status == AttendanceStatus.present)
                  .length);
    final late =
        lateCount ??
        (nextEntries == null
            ? this.lateCount
            : nextEntries.where((e) => e.status == AttendanceStatus.late).length);
    final absent =
        absentCount ??
        (nextEntries == null
            ? this.absentCount
            : nextEntries
                  .where((e) => e.status == AttendanceStatus.absent)
                  .length);
    return AttendanceRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      className: className ?? this.className,
      presentCount: present,
      lateCount: late,
      absentCount: absent,
      entries: nextEntries == null
          ? null
          : List<StudentAttendanceEntry>.unmodifiable(nextEntries),
      status: status ?? this.status,
      dateKey: dateKey ?? this.dateKey,
      schoolId: schoolId ?? this.schoolId,
      recordedAt: recordedAt ?? this.recordedAt,
      subjectId: clearSubjectId ? null : (subjectId ?? this.subjectId),
      recordedByTeacherId: recordedByTeacherId ?? this.recordedByTeacherId,
      note: clearNote ? null : (note ?? this.note),
      createdByUid: createdByUid ?? this.createdByUid,
      updatedByUid: updatedByUid ?? this.updatedByUid,
    );
  }

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

  /// Resolves a stable `yyyy-MM-dd` key, with fallbacks for legacy rows.
  ///
  /// Returns null when the row cannot be mapped to a calendar day
  /// (except legacy `Өнөөдөр`, which is handled in [matchesDateKey]).
  String? get resolvedDateKey {
    final stored = dateKey?.trim();
    if (stored != null && stored.isNotEmpty) {
      return SchoolDate.tryParseDateKey(stored) != null ? stored : null;
    }

    final iso = SchoolDate.tryParseDateKey(date);
    if (iso != null) return SchoolDate.formatDateKey(iso);

    final parsed = tryParseCalendarDate(date);
    if (parsed != null) return SchoolDate.formatDateKey(parsed);

    return null;
  }

  /// True when this record belongs to [dateKey] (`yyyy-MM-dd`, local school day).
  bool matchesDateKey(String dateKey) {
    final target = dateKey.trim();
    final resolved = resolvedDateKey;
    if (resolved != null) return resolved == target;

    // Legacy seed/test rows labeled "Өнөөдөр" only match the current local day.
    if (date.trim() == 'Өнөөдөр') {
      return target == AppClock.todayKey();
    }
    return false;
  }

  /// Compares only year/month/day (ignores time-of-day / zone offset).
  bool isOnCalendarDay(DateTime day) {
    final key = SchoolDate.formatDateKey(
      DateTime(day.year, day.month, day.day),
    );
    return matchesDateKey(key);
  }

  /// Human-readable date for lists (prefers dateKey).
  String get displayDateLabel {
    final key = resolvedDateKey;
    if (key != null) return SchoolDate.displayLabel(key);
    return date;
  }
}
