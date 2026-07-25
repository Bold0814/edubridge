import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/timetable.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/timetable_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;
  late Teacher teacher;
  late int mathId;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();

    teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: AppStore.defaultSchoolId,
      fullName: 'Д.Эрдэнэ',
    );
    await store.addTeacher(teacher);
    mathId = store.activeSubjects.firstWhere((s) => s.name == 'Математик').id;
    await store.saveClassAssignments(
      classId: '7А',
      homeroomTeacherId: teacher.id,
      subjectTeacherIds: {mathId: teacher.id},
    );

    await store.addLessonPeriod(
      LessonPeriod(
        id: store.nextLessonPeriodId(),
        schoolId: AppStore.defaultSchoolId,
        periodNumber: 1,
        startTime: '08:00',
        endTime: '08:45',
      ),
    );
    await store.addLessonPeriod(
      LessonPeriod(
        id: store.nextLessonPeriodId(),
        schoolId: AppStore.defaultSchoolId,
        periodNumber: 2,
        startTime: '08:55',
        endTime: '09:40',
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('periods and timetable CRUD via AppStore', () async {
    final period = store.lessonPeriods.first;
    await store.addClassTimetable(
      ClassTimetable(
        id: store.nextClassTimetableId(),
        classId: '7А',
        weekday: DateTime.monday,
        periodId: period.id,
        subjectId: mathId,
      ),
    );

    expect(store.timetableForClassWeekday('7А', DateTime.monday), hasLength(1));

    await store.updateLessonPeriod(
      period.copyWith(startTime: '08:10', endTime: '08:55'),
    );
    expect(store.periodById(period.id)?.startTime, '08:10');

    final entry = store.timetableForClass('7А').first;
    await store.deleteClassTimetable(entry.id);
    expect(store.timetableForClass('7А'), isEmpty);
  });

  test('teacher is resolved from class + subject assignment', () async {
    final period = store.lessonPeriods.first;
    await store.addClassTimetable(
      ClassTimetable(
        id: store.nextClassTimetableId(),
        classId: '7А',
        weekday: DateTime.monday,
        periodId: period.id,
        subjectId: mathId,
      ),
    );

    final monday = DateTime(2026, 7, 20); // Monday
    final lessons = TimetableService.todayLessonsForTeacher(
      store,
      teacher.id,
      now: monday,
    );

    expect(lessons, hasLength(1));
    expect(lessons.first.subjectName, 'Математик');
    expect(lessons.first.classId, '7А');
    expect(lessons.first.teacher?.id, teacher.id);
    // Teacher is never persisted on the timetable row.
    expect(lessons.first.entry.subjectId, mathId);
  });

  test('student and guardian see class timetable for today', () async {
    final p1 = store.lessonPeriods[0];
    final p2 = store.lessonPeriods[1];
    await store.addClassTimetable(
      ClassTimetable(
        id: store.nextClassTimetableId(),
        classId: '7А',
        weekday: DateTime.wednesday,
        periodId: p2.id,
        subjectId: mathId,
      ),
    );
    await store.addClassTimetable(
      ClassTimetable(
        id: store.nextClassTimetableId(),
        classId: '7А',
        weekday: DateTime.wednesday,
        periodId: p1.id,
        subjectId: mathId,
      ),
    );

    final wed = DateTime(2026, 7, 22); // Wednesday
    final lessons = TimetableService.todayLessonsForClass(
      store,
      '7А',
      now: wed,
    );

    expect(lessons, hasLength(2));
    expect(lessons.first.period.periodNumber, 1);
    expect(lessons.last.period.periodNumber, 2);
  });

  test('SQLite migration creates timetable tables from v7', () async {
    final upgraded = await DatabaseService.instance.openInMemoryUpgradingFrom(
      7,
    );
    final periods = await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='lesson_periods'",
    );
    final timetable = await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='class_timetable'",
    );
    expect(periods, isNotEmpty);
    expect(timetable, isNotEmpty);
    await upgraded.close();
  });

  test('duplicate class/weekday/period slot is rejected', () async {
    final period = store.lessonPeriods.first;
    await store.addClassTimetable(
      ClassTimetable(
        id: store.nextClassTimetableId(),
        classId: '7А',
        weekday: DateTime.monday,
        periodId: period.id,
        subjectId: mathId,
      ),
    );

    expect(
      () => store.addClassTimetable(
        ClassTimetable(
          id: store.nextClassTimetableId(),
          classId: '7А',
          weekday: DateTime.monday,
          periodId: period.id,
          subjectId: mathId,
        ),
      ),
      throwsA(
        isA<ArgumentError>().having((e) => e.message, 'message', 'SLOT_TAKEN'),
      ),
    );
  });
}
