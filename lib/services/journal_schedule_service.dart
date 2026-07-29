import '../models/lesson_occurrence.dart';
import '../models/timetable.dart';
import '../state/app_store.dart';
import 'app_clock.dart';
import 'timetable_service.dart';

/// A concrete lesson slot on a calendar day (from timetable ± persisted rows).
class ScheduledJournalLesson {
  const ScheduledJournalLesson({
    required this.lessonDate,
    required this.classId,
    required this.subjectId,
    required this.periodId,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    required this.teacherId,
    this.timetableEntryId,
    this.occurrenceId,
  });

  final DateTime lessonDate;
  final String classId;
  final int subjectId;
  final String periodId;
  final int periodNumber;
  final String startTime;
  final String endTime;
  final String teacherId;
  final String? timetableEntryId;
  final String? occurrenceId;

  String get timeLabel => '$startTime–$endTime';

  String get lessonDateKey {
    final day = LessonOccurrence.dateOnly(lessonDate);
    return AppClock.formatDateKey(day);
  }

  /// Stable occurrence identity shared by timetable slots and persisted rows.
  ///
  /// Must use calendar `YYYY-MM-DD`, never [DateTime.toIso8601String], so that
  /// scheduled and persisted copies of the same lesson collapse to one entry.
  String get identityKey => datePeriodKey(lessonDate, periodId);

  /// Dropdown / navigation key: date + period + optional timetable entry.
  String get occurrenceKey {
    final entry = timetableEntryId?.trim();
    if (entry != null && entry.isNotEmpty) {
      return '$identityKey|$entry';
    }
    return identityKey;
  }

  static String datePeriodKey(DateTime date, String periodId) {
    final day = LessonOccurrence.dateOnly(date);
    return '${AppClock.formatDateKey(day)}|$periodId';
  }

  ScheduledJournalLesson copyWith({
    String? teacherId,
    String? timetableEntryId,
    String? occurrenceId,
  }) {
    return ScheduledJournalLesson(
      lessonDate: lessonDate,
      classId: classId,
      subjectId: subjectId,
      periodId: periodId,
      periodNumber: periodNumber,
      startTime: startTime,
      endTime: endTime,
      teacherId: teacherId ?? this.teacherId,
      timetableEntryId: timetableEntryId ?? this.timetableEntryId,
      occurrenceId: occurrenceId ?? this.occurrenceId,
    );
  }
}

/// Resolves schedule-driven journal occurrences from timetable + store data.
abstract final class JournalScheduleService {
  static List<ResolvedLesson> lessonsForClassSubjectOnWeekday(
    AppStore store, {
    required String classId,
    required int subjectId,
    required int weekday,
    String? teacherId,
  }) {
    return TimetableService.lessonsForClassOnWeekday(store, classId, weekday)
        .where((lesson) {
          if (lesson.subject.id != subjectId) return false;
          if (teacherId == null || teacherId.isEmpty) return true;
          final assigned = store.teacherIdForClassSubject(classId, subjectId);
          return assigned == teacherId;
        })
        .toList(growable: false);
  }

  static List<ScheduledJournalLesson> lessonsOnDate(
    AppStore store, {
    required String classId,
    required int subjectId,
    required DateTime date,
    String? teacherId,
  }) {
    final day = LessonOccurrence.dateOnly(date);
    final resolved = lessonsForClassSubjectOnWeekday(
      store,
      classId: classId,
      subjectId: subjectId,
      weekday: day.weekday,
      teacherId: teacherId,
    );
    // Deduplicate by periodId: one dropdown/timeline slot per period on a day.
    final byPeriod = <String, ScheduledJournalLesson>{};
    for (final lesson in resolved) {
      byPeriod.putIfAbsent(
        lesson.period.id,
        () => ScheduledJournalLesson(
          lessonDate: day,
          classId: classId,
          subjectId: subjectId,
          periodId: lesson.period.id,
          periodNumber: lesson.period.periodNumber,
          startTime: lesson.period.startTime,
          endTime: lesson.period.endTime,
          teacherId:
              teacherId ??
              lesson.teacher?.id ??
              store.teacherIdForClassSubject(classId, subjectId) ??
              '',
          timetableEntryId: lesson.entry.id,
        ),
      );
    }
    return byPeriod.values.toList(growable: false);
  }

  /// Deduplicates lessons that share the same date+period (or occurrence key).
  static List<ScheduledJournalLesson> dedupeLessons(
    Iterable<ScheduledJournalLesson> lessons,
  ) {
    final byKey = <String, ScheduledJournalLesson>{};
    for (final lesson in lessons) {
      // Prefer period-level identity so ISO vs date-key mismatches cannot
      // produce two DropdownMenuItems with the same periodId.
      byKey.putIfAbsent(lesson.identityKey, () => lesson);
    }
    final list = byKey.values.toList()
      ..sort((a, b) {
        final byDate = a.lessonDate.compareTo(b.lessonDate);
        if (byDate != 0) return byDate;
        return a.periodNumber.compareTo(b.periodNumber);
      });
    return list;
  }

  /// Builds a timeline of scheduled slots (± weeks) merged with persisted rows.
  static List<ScheduledJournalLesson> buildTimeline(
    AppStore store, {
    required String classId,
    required int subjectId,
    String? teacherId,
    DateTime? around,
    int weeksBack = 16,
    int weeksForward = 8,
  }) {
    final center = LessonOccurrence.dateOnly(around ?? AppClock.today());
    final start = center.subtract(Duration(days: weeksBack * 7));
    final end = center.add(Duration(days: weeksForward * 7));

    final byKey = <String, ScheduledJournalLesson>{};

    for (
      var day = start;
      !day.isAfter(end);
      day = day.add(const Duration(days: 1))
    ) {
      for (final lesson in lessonsOnDate(
        store,
        classId: classId,
        subjectId: subjectId,
        date: day,
        teacherId: teacherId,
      )) {
        byKey[lesson.identityKey] = lesson;
      }
    }

    // Keep historical persisted occurrences even if timetable later changes.
    // Keys must match [ScheduledJournalLesson.identityKey] (YYYY-MM-DD|periodId).
    for (final row in store.lessonOccurrencesFor(
      classId: classId,
      subjectId: subjectId,
      teacherId: teacherId,
    )) {
      final period = store.periodById(row.periodId);
      final key = ScheduledJournalLesson.datePeriodKey(
        row.lessonDate,
        row.periodId,
      );
      final existing = byKey[key];
      if (existing != null) {
        byKey[key] = existing.copyWith(
          occurrenceId: row.id,
          timetableEntryId: existing.timetableEntryId ?? row.timetableEntryId,
          teacherId: existing.teacherId.isNotEmpty
              ? existing.teacherId
              : row.teacherId,
        );
      } else {
        byKey[key] = ScheduledJournalLesson(
          lessonDate: LessonOccurrence.dateOnly(row.lessonDate),
          classId: row.classId,
          subjectId: row.subjectId,
          periodId: row.periodId,
          periodNumber: period?.periodNumber ?? 0,
          startTime: period?.startTime ?? '--:--',
          endTime: period?.endTime ?? '--:--',
          teacherId: row.teacherId,
          timetableEntryId: row.timetableEntryId,
          occurrenceId: row.id,
        );
      }
    }

    return dedupeLessons(byKey.values);
  }

  /// Picks the default occurrence when opening the journal.
  ///
  /// Returns only a lesson on the Asia/Ulaanbaatar calendar day of [now].
  /// Never opens yesterday (or any other day) as a silent fallback.
  static ScheduledJournalLesson? resolveDefault(
    AppStore store, {
    required String classId,
    required int subjectId,
    String? teacherId,
    DateTime? now,
    String? preferredPeriodId,
  }) {
    final moment = now ?? AppClock.nowInUlaanbaatar();
    final today = LessonOccurrence.dateOnly(moment);
    final todayLessons = lessonsOnDate(
      store,
      classId: classId,
      subjectId: subjectId,
      date: today,
      teacherId: teacherId,
    );

    if (todayLessons.isEmpty) return null;

    if (preferredPeriodId != null) {
      for (final lesson in todayLessons) {
        if (lesson.periodId == preferredPeriodId) return lesson;
      }
    }
    return pickCurrentOrFirst(todayLessons, moment);
  }

  static ScheduledJournalLesson pickCurrentOrFirst(
    List<ScheduledJournalLesson> todayLessons,
    DateTime now,
  ) {
    if (todayLessons.length == 1) return todayLessons.first;
    final minutes = now.hour * 60 + now.minute;
    ScheduledJournalLesson? current;
    ScheduledJournalLesson? upcoming;
    for (final lesson in todayLessons) {
      final start = _parseMinutes(lesson.startTime);
      final end = _parseMinutes(lesson.endTime);
      if (start == null || end == null) continue;
      if (minutes >= start && minutes < end) {
        current = lesson;
        break;
      }
      if (minutes < start && upcoming == null) {
        upcoming = lesson;
      }
    }
    return current ?? upcoming ?? todayLessons.first;
  }

  static String mongolianDateLabel(DateTime date) {
    final weekday = TimetableWeekday.labels[date.weekday] ?? '';
    return '${AppClock.mongolianLabel(date)}, $weekday';
  }

  static int? _parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}
