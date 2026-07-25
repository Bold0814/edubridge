import '../models/subject.dart';
import '../models/teacher.dart';
import '../models/timetable.dart';
import '../state/app_store.dart';

/// Resolved lesson for display: period + subject + optional teacher from assignment.
class ResolvedLesson {
  const ResolvedLesson({
    required this.entry,
    required this.period,
    required this.subject,
    this.teacher,
  });

  final ClassTimetable entry;
  final LessonPeriod period;
  final Subject subject;
  final Teacher? teacher;

  String get classId => entry.classId;
  String get timeLabel => period.timeLabel;
  String get subjectName => subject.name;
}

/// Builds today's (or a weekday's) lessons from AppStore timetable data.
abstract final class TimetableService {
  static List<ResolvedLesson> lessonsForClassOnWeekday(
    AppStore store,
    String classId,
    int weekday,
  ) {
    return _resolve(store, store.timetableForClassWeekday(classId, weekday));
  }

  static List<ResolvedLesson> todayLessonsForClass(
    AppStore store,
    String classId, {
    DateTime? now,
  }) {
    final day = (now ?? DateTime.now()).weekday;
    return lessonsForClassOnWeekday(store, classId, day);
  }

  /// Lessons for a teacher today, across all classes (assignment-resolved).
  static List<ResolvedLesson> todayLessonsForTeacher(
    AppStore store,
    String teacherId, {
    DateTime? now,
  }) {
    final day = (now ?? DateTime.now()).weekday;
    final entries = store.timetableEntriesForWeekday(day).where((entry) {
      final assigned = store.teacherIdForClassSubject(
        entry.classId,
        entry.subjectId,
      );
      return assigned == teacherId;
    });
    return _resolve(store, entries);
  }

  /// Prefer linked teacher account; else show selected class timetable.
  static List<ResolvedLesson> todayLessonsForTeacherDashboard(
    AppStore store,
    String selectedClass, {
    DateTime? now,
  }) {
    final teacherId = store.selectedDevelopmentUser?.teacherId;
    if (teacherId != null &&
        teacherId.isNotEmpty &&
        store.teacherById(teacherId) != null) {
      return todayLessonsForTeacher(store, teacherId, now: now);
    }
    return todayLessonsForClass(store, selectedClass, now: now);
  }

  static List<ResolvedLesson> _resolve(
    AppStore store,
    Iterable<ClassTimetable> entries,
  ) {
    final lessons = <ResolvedLesson>[];
    for (final entry in entries) {
      final period = store.periodById(entry.periodId);
      final subject = store.subjectById(entry.subjectId);
      if (period == null || subject == null) continue;
      lessons.add(
        ResolvedLesson(
          entry: entry,
          period: period,
          subject: subject,
          teacher: store.teacherForClassSubject(entry.classId, entry.subjectId),
        ),
      );
    }
    lessons.sort((a, b) {
      final byPeriod = a.period.periodNumber.compareTo(b.period.periodNumber);
      if (byPeriod != 0) return byPeriod;
      return a.classId.compareTo(b.classId);
    });
    return lessons;
  }
}
