/// School-wide bell/period template (scoped to a school).
class LessonPeriod {
  const LessonPeriod({
    required this.id,
    required this.schoolId,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final String schoolId;
  final int periodNumber;
  final String startTime;
  final String endTime;

  String get timeLabel => '$startTime – $endTime';

  LessonPeriod copyWith({
    String? schoolId,
    int? periodNumber,
    String? startTime,
    String? endTime,
  }) {
    return LessonPeriod(
      id: id,
      schoolId: schoolId ?? this.schoolId,
      periodNumber: periodNumber ?? this.periodNumber,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

/// One scheduled lesson cell. Teacher is never stored — resolve via class+subject.
class ClassTimetable {
  const ClassTimetable({
    required this.id,
    required this.classId,
    required this.weekday,
    required this.periodId,
    required this.subjectId,
  });

  final String id;

  /// Class identity (= class id / migrated name), e.g. `7А`.
  final String classId;

  /// [DateTime.weekday]: 1 = Monday … 7 = Sunday.
  final int weekday;
  final String periodId;
  final int subjectId;

  ClassTimetable copyWith({
    String? classId,
    int? weekday,
    String? periodId,
    int? subjectId,
  }) {
    return ClassTimetable(
      id: id,
      classId: classId ?? this.classId,
      weekday: weekday ?? this.weekday,
      periodId: periodId ?? this.periodId,
      subjectId: subjectId ?? this.subjectId,
    );
  }
}

/// Mongolian weekday labels for timetable UI (Mon–Sun).
abstract final class TimetableWeekday {
  static const labels = <int, String>{
    DateTime.monday: 'Даваа',
    DateTime.tuesday: 'Мягмар',
    DateTime.wednesday: 'Лхагва',
    DateTime.thursday: 'Пүрэв',
    DateTime.friday: 'Баасан',
    DateTime.saturday: 'Бямба',
    DateTime.sunday: 'Ням',
  };

  static const schoolDays = <int>[
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ];

  static String label(int weekday) => labels[weekday] ?? 'Өдөр $weekday';
}
