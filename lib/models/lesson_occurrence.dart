import '../services/app_clock.dart';

/// One scheduled lesson occurrence used by the class journal.
///
/// Identity: school + class + subject + date + period (teacher is a snapshot).
class LessonOccurrence {
  const LessonOccurrence({
    required this.id,
    required this.schoolId,
    required this.classId,
    required this.subjectId,
    required this.teacherId,
    required this.lessonDate,
    required this.periodId,
    this.timetableEntryId,
    this.topic,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String schoolId;
  final String classId;
  final int subjectId;
  final String teacherId;

  /// Calendar day only (time stripped).
  final DateTime lessonDate;
  final String periodId;
  final String? timetableEntryId;
  final String? topic;
  final String? note;
  final DateTime createdAt;

  String get lessonDateKey => AppClock.formatDateKey(lessonDate);

  LessonOccurrence copyWith({
    String? teacherId,
    String? timetableEntryId,
    String? topic,
    String? note,
    bool clearTopic = false,
    bool clearNote = false,
  }) {
    return LessonOccurrence(
      id: id,
      schoolId: schoolId,
      classId: classId,
      subjectId: subjectId,
      teacherId: teacherId ?? this.teacherId,
      lessonDate: lessonDate,
      periodId: periodId,
      timetableEntryId: timetableEntryId ?? this.timetableEntryId,
      topic: clearTopic ? null : (topic ?? this.topic),
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt,
    );
  }

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime? tryParseDateKey(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}
