import 'package:edubridge/models/attendance_record.dart';
import 'package:edubridge/models/homework.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/timetable.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/class_journal_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/journal_schedule_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;
  late Teacher teacher;
  late int mongolId;
  late String period1Id;
  late String period2Id;
  late String period3Id;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();
    await store.createSchool(
      id: 'sch-jl',
      name: 'Журнал сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-jl',
      fullName: 'А. Админ',
      username: 'jladmin',
      password: 'Admin2026',
    );

    await store.addSchoolClass(name: 'JL6А');
    await store.addSubject('JLМонгол');
    mongolId = store.activeSubjects.firstWhere((s) => s.name == 'JLМонгол').id;

    teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: 'sch-jl',
      fullName: 'М. Багш',
      phone: '99001122',
    );
    await store.createTeacherWithOptionalLogin(
      teacher: teacher,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );
    await store.saveClassAssignments(
      classId: 'JL6А',
      homeroomTeacherId: teacher.id,
      subjectTeacherIds: {mongolId: teacher.id},
    );

    period1Id = store.nextLessonPeriodId();
    period2Id = store.nextLessonPeriodId();
    period3Id = store.nextLessonPeriodId();
    await store.addLessonPeriod(
      LessonPeriod(
        id: period1Id,
        schoolId: 'sch-jl',
        periodNumber: 1,
        startTime: '08:00',
        endTime: '08:40',
      ),
    );
    await store.addLessonPeriod(
      LessonPeriod(
        id: period2Id,
        schoolId: 'sch-jl',
        periodNumber: 2,
        startTime: '08:50',
        endTime: '09:30',
      ),
    );
    await store.addLessonPeriod(
      LessonPeriod(
        id: period3Id,
        schoolId: 'sch-jl',
        periodNumber: 3,
        startTime: '10:20',
        endTime: '11:00',
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  /// Timetable writes require admin; keep the admin session for scheduling.
  Future<void> scheduleOnWeekday(int weekday, List<String> periodIds) async {
    for (final periodId in periodIds) {
      await store.addClassTimetable(
        ClassTimetable(
          id: store.nextClassTimetableId(),
          classId: 'JL6А',
          weekday: weekday,
          periodId: periodId,
          subjectId: mongolId,
        ),
      );
    }
  }

  Future<void> loginAsTeacher() async {
    await store.logout();
    final result = await store.login(
      username: '99001122',
      password: 'Teach2026',
      rememberMe: false,
    );
    expect(result, LoginResult.success);
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(store.authenticatedUser!.id).first,
    );
    await store.setTeacherWorkspace(classId: 'JL6А', subjectId: mongolId);
  }

  test('today’s scheduled lesson opens as default occurrence', () async {
    final friday = DateTime(2026, 7, 24); // Friday
    await scheduleOnWeekday(DateTime.friday, [period3Id]);

    final resolved = JournalScheduleService.resolveDefault(
      store,
      classId: 'JL6А',
      subjectId: mongolId,
      teacherId: teacher.id,
      now: DateTime(2026, 7, 24, 10, 30),
    );

    expect(resolved, isNotNull);
    expect(resolved!.lessonDate, DateTime(2026, 7, 24));
    expect(resolved.periodId, period3Id);
    expect(resolved.periodNumber, 3);
    expect(friday.weekday, DateTime.friday);
  });

  test('multiple lessons today pick current period by time', () async {
    await scheduleOnWeekday(DateTime.friday, [period1Id, period3Id]);

    final duringThird = JournalScheduleService.resolveDefault(
      store,
      classId: 'JL6А',
      subjectId: mongolId,
      teacherId: teacher.id,
      now: DateTime(2026, 7, 24, 10, 35),
    );
    expect(duringThird?.periodId, period3Id);

    final beforeFirst = JournalScheduleService.resolveDefault(
      store,
      classId: 'JL6А',
      subjectId: mongolId,
      teacherId: teacher.id,
      now: DateTime(2026, 7, 24, 7, 30),
    );
    expect(beforeFirst?.periodId, period1Id);
  });

  test('no lesson today does not open yesterday', () async {
    await scheduleOnWeekday(DateTime.monday, [period2Id]);

    final monday = DateTime(2026, 7, 20);
    await store.ensureLessonOccurrence(
      classId: 'JL6А',
      subjectId: mongolId,
      lessonDate: monday,
      periodId: period2Id,
      teacherId: teacher.id,
    );

    final fridayNow = DateTime(2026, 7, 24, 12, 0);
    final resolved = JournalScheduleService.resolveDefault(
      store,
      classId: 'JL6А',
      subjectId: mongolId,
      teacherId: teacher.id,
      now: fridayNow,
    );

    expect(resolved, isNull);
    expect(
      JournalScheduleService.lessonsOnDate(
        store,
        classId: 'JL6А',
        subjectId: mongolId,
        date: fridayNow,
        teacherId: teacher.id,
      ),
      isEmpty,
    );
  });

  test('previous/next navigation uses scheduled occurrences only', () async {
    await scheduleOnWeekday(DateTime.monday, [period1Id]);
    await scheduleOnWeekday(DateTime.wednesday, [period1Id]);
    await scheduleOnWeekday(DateTime.friday, [period1Id]);

    final timeline = JournalScheduleService.buildTimeline(
      store,
      classId: 'JL6А',
      subjectId: mongolId,
      teacherId: teacher.id,
      around: DateTime(2026, 7, 22),
      weeksBack: 1,
      weeksForward: 1,
    );

    final dates = timeline.map((e) => e.lessonDate).toSet();
    // Only Mon/Wed/Fri in the window — no Tue/Thu filler days.
    for (final day in dates) {
      expect(
        day.weekday == DateTime.monday ||
            day.weekday == DateTime.wednesday ||
            day.weekday == DateTime.friday,
        isTrue,
      );
    }

    final wed = timeline.firstWhere(
      (e) => e.lessonDate == DateTime(2026, 7, 22),
    );
    final index = timeline.indexWhere((e) => e.identityKey == wed.identityKey);
    expect(timeline[index - 1].lessonDate.weekday, DateTime.monday);
    expect(timeline[index + 1].lessonDate.weekday, DateTime.friday);
  });

  test('duplicate journal occurrence is prevented', () async {
    await scheduleOnWeekday(DateTime.friday, [period3Id]);
    final day = DateTime(2026, 7, 24);

    final first = await store.ensureLessonOccurrence(
      classId: 'JL6А',
      subjectId: mongolId,
      lessonDate: day,
      periodId: period3Id,
      teacherId: teacher.id,
    );
    final second = await store.ensureLessonOccurrence(
      classId: 'JL6А',
      subjectId: mongolId,
      lessonDate: day,
      periodId: period3Id,
      teacherId: teacher.id,
    );

    expect(first.id, second.id);
    expect(
      store
          .lessonOccurrencesFor(classId: 'JL6А', subjectId: mongolId)
          .where(
            (o) =>
                o.periodId == period3Id &&
                o.lessonDate == DateTime(2026, 7, 24),
          ),
      hasLength(1),
    );
  });

  test('historical occurrence remains after timetable changes', () async {
    await scheduleOnWeekday(DateTime.monday, [period1Id]);
    final monday = DateTime(2026, 7, 20);
    final occurrence = await store.ensureLessonOccurrence(
      classId: 'JL6А',
      subjectId: mongolId,
      lessonDate: monday,
      periodId: period1Id,
      teacherId: teacher.id,
    );
    await store.updateLessonOccurrenceNote(
      occurrenceId: occurrence.id,
      topic: 'Эхний сэдэв',
    );

    final entry = store.timetableForClass('JL6А').first;
    await store.deleteClassTimetable(entry.id);

    final timeline = JournalScheduleService.buildTimeline(
      store,
      classId: 'JL6А',
      subjectId: mongolId,
      teacherId: teacher.id,
      around: monday,
      weeksBack: 1,
      weeksForward: 0,
    );
    expect(
      timeline.any((e) => e.lessonDate == monday && e.periodId == period1Id),
      isTrue,
    );
    expect(
      store
          .findLessonOccurrence(
            classId: 'JL6А',
            subjectId: mongolId,
            lessonDate: monday,
            periodId: period1Id,
          )
          ?.topic,
      'Эхний сэдэв',
    );
  });

  test('teacher cannot edit unrelated assignment', () async {
    await store.addSubject('JLМатематик');
    final mathId = store.activeSubjects
        .firstWhere((s) => s.name == 'JLМатематик')
        .id;
    await loginAsTeacher();
    expect(
      store.teacherCanEditClassSubject(classId: 'JL6А', subjectId: mathId),
      isFalse,
    );
    expect(
      store.teacherCanEditClassSubject(classId: 'JL6А', subjectId: mongolId),
      isTrue,
    );
  });

  test('attendance summary is occurrence-day specific', () async {
    await scheduleOnWeekday(DateTime.friday, [period3Id]);
    await store.setTeacherWorkspace(classId: 'JL6А', subjectId: mongolId);
    final friday = DateTime(2026, 7, 24);
    final monday = DateTime(2026, 7, 20);

    await store.addAttendance(
      'JL6А',
      AttendanceRecord.detailed(
        id: store.nextAttendanceId(),
        date: '2026 оны 7 сарын 24',
        className: 'JL6А',
        entries: const [
          StudentAttendanceEntry(
            studentName: 'А. Сурагч',
            status: AttendanceStatus.present,
          ),
        ],
      ),
    );
    await store.addAttendance(
      'JL6А',
      AttendanceRecord.detailed(
        id: store.nextAttendanceId(),
        date: '2026 оны 7 сарын 20',
        className: 'JL6А',
        entries: const [
          StudentAttendanceEntry(
            studentName: 'А. Сурагч',
            status: AttendanceStatus.absent,
          ),
        ],
      ),
    );

    final fridayRows = store
        .attendanceFor('JL6А')
        .where((r) => r.isOnCalendarDay(friday))
        .toList();
    final mondayRows = store
        .attendanceFor('JL6А')
        .where((r) => r.isOnCalendarDay(monday))
        .toList();
    expect(fridayRows.single.presentCount, 1);
    expect(mondayRows.single.absentCount, 1);
  });

  test('homework summary is class/subject scoped', () async {
    await store.addSubject('JLМатематик');
    await store.addHomework(
      Homework(
        id: store.nextHomeworkId(),
        className: 'JL6А',
        subject: 'JLМонгол',
        title: 'Монгол даалгавар',
        description: 'Унших',
        dueDate: '2026 оны 7 сарын 28',
        status: HomeworkStatus.pending,
      ),
    );
    await store.addHomework(
      Homework(
        id: store.nextHomeworkId(),
        className: 'JL6А',
        subject: 'JLМатематик',
        title: 'Математик даалгавар',
        description: 'Бодлого',
        dueDate: '2026 оны 7 сарын 28',
        status: HomeworkStatus.pending,
      ),
    );

    final scoped = store.homeworkFor('JL6А', subjectId: mongolId);
    expect(scoped, hasLength(1));
    expect(scoped.single.title, 'Монгол даалгавар');
  });

  testWidgets('journal UI: actions above summaries, no primary date picker', (
    tester,
  ) async {
    await scheduleOnWeekday(DateTime.friday, [period3Id]);
    await loginAsTeacher();

    await tester.pumpWidget(
      MaterialApp(
        home: ClassJournalScreen(
          selectedClass: 'JL6А',
          store: store,
          subjectId: mongolId,
          initialDate: DateTime(2026, 7, 24, 10, 30),
          initialPeriodId: period3Id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Хичээлийн журнал'), findsOneWidget);
    expect(find.text('Ирц авах'), findsOneWidget);
    expect(find.text('Өнөөдрийн бүртгэл'), findsOneWidget);

    // Large primary date field removed.
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(find.text('Огноо'), findsNothing);

    final actionsY = tester.getTopLeft(find.text('Ирц авах')).dy;
    final summaryY = tester.getTopLeft(find.text('Өнөөдрийн бүртгэл')).dy;
    expect(actionsY < summaryY, isTrue);

    expect(find.textContaining('3-р цаг'), findsWidgets);
    expect(find.textContaining('JL6А анги'), findsOneWidget);

    // Prev/next sit below the fold on the default test surface.
    await tester.scrollUntilVisible(find.text('Өмнөх хичээл'), 200);
    expect(find.text('Өмнөх хичээл'), findsOneWidget);
    expect(find.text('Дараагийн хичээл'), findsOneWidget);
  });

  testWidgets('no lesson today shows Mongolian message', (tester) async {
    await scheduleOnWeekday(DateTime.monday, [period1Id]);
    await loginAsTeacher();

    await tester.pumpWidget(
      MaterialApp(
        home: ClassJournalScreen(
          selectedClass: 'JL6А',
          store: store,
          subjectId: mongolId,
          initialDate: DateTime(2026, 7, 24, 10, 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Өнөөдөр энэ хичээл хуваарьгүй байна.'), findsOneWidget);
  });

  testWidgets('action context keeps fixed class and subject', (tester) async {
    await scheduleOnWeekday(DateTime.friday, [period3Id]);
    await loginAsTeacher();

    await tester.pumpWidget(
      MaterialApp(
        home: ClassJournalScreen(
          selectedClass: 'JL6А',
          store: store,
          subjectId: mongolId,
          initialDate: DateTime(2026, 7, 24, 10, 30),
          initialPeriodId: period3Id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(store.activeContext.classId, 'JL6А');
    expect(store.activeContext.subjectId, mongolId);
    expect(find.textContaining('JLМонгол'), findsWidgets);
  });

  test('one period produces one timeline item after persistence', () async {
    await scheduleOnWeekday(DateTime.friday, [period3Id]);
    final day = DateTime(2026, 7, 24);
    await store.ensureLessonOccurrence(
      classId: 'JL6А',
      subjectId: mongolId,
      lessonDate: day,
      periodId: period3Id,
      teacherId: teacher.id,
    );

    final timeline = JournalScheduleService.buildTimeline(
      store,
      classId: 'JL6А',
      subjectId: mongolId,
      teacherId: teacher.id,
      around: day,
      weeksBack: 1,
      weeksForward: 0,
    );
    final friday = timeline
        .where((e) => e.lessonDate == day && e.periodId == period3Id)
        .toList();
    expect(friday, hasLength(1));
    expect(friday.single.identityKey, '2026-07-24|$period3Id');
  });

  test('duplicate source rows are deduplicated by date|periodId', () {
    final day = DateTime(2026, 7, 24);
    final a = ScheduledJournalLesson(
      lessonDate: day,
      classId: 'JL6А',
      subjectId: mongolId,
      periodId: period3Id,
      periodNumber: 3,
      startTime: '10:20',
      endTime: '11:00',
      teacherId: teacher.id,
      timetableEntryId: 'ct-1',
    );
    final b = ScheduledJournalLesson(
      lessonDate: day,
      classId: 'JL6А',
      subjectId: mongolId,
      periodId: period3Id,
      periodNumber: 3,
      startTime: '10:20',
      endTime: '11:00',
      teacherId: teacher.id,
      timetableEntryId: 'ct-2',
      occurrenceId: 'lo-1',
    );
    // Simulate the old ISO-key duplicate that crashed DropdownButton.
    final legacyIsoClone = ScheduledJournalLesson(
      lessonDate: day,
      classId: 'JL6А',
      subjectId: mongolId,
      periodId: period3Id,
      periodNumber: 3,
      startTime: '10:20',
      endTime: '11:00',
      teacherId: teacher.id,
    );

    final deduped = JournalScheduleService.dedupeLessons([
      a,
      b,
      legacyIsoClone,
    ]);
    expect(deduped, hasLength(1));
    expect(deduped.single.periodId, period3Id);

    final values = deduped.map((e) => e.occurrenceKey).toList();
    expect(values.toSet(), hasLength(1));
  });

  test('stale selected value becomes null safely', () {
    final day = DateTime(2026, 7, 24);
    final items = [
      ScheduledJournalLesson(
        lessonDate: day,
        classId: 'JL6А',
        subjectId: mongolId,
        periodId: period1Id,
        periodNumber: 1,
        startTime: '08:00',
        endTime: '08:40',
        teacherId: teacher.id,
        timetableEntryId: 'ct-a',
      ),
    ];
    final valid = items.map((e) => e.occurrenceKey).toSet();
    const stale = 'missing-key';
    final safeValue = valid.contains(stale) ? stale : null;
    expect(safeValue, isNull);
    expect(valid.contains(items.single.occurrenceKey), isTrue);
  });

  test('multiple same-day periods use unique occurrence keys', () async {
    await scheduleOnWeekday(DateTime.friday, [period1Id, period3Id]);
    final day = DateTime(2026, 7, 24);
    final lessons = JournalScheduleService.lessonsOnDate(
      store,
      classId: 'JL6А',
      subjectId: mongolId,
      date: day,
      teacherId: teacher.id,
    );
    expect(lessons, hasLength(2));
    final keys = lessons.map((e) => e.occurrenceKey).toSet();
    expect(keys, hasLength(2));
    final periodIds = lessons.map((e) => e.periodId).toSet();
    expect(periodIds, {period1Id, period3Id});
  });

  testWidgets('opening Class Journal never throws DropdownButton assertion', (
    tester,
  ) async {
    await scheduleOnWeekday(DateTime.friday, [period3Id]);
    await store.ensureLessonOccurrence(
      classId: 'JL6А',
      subjectId: mongolId,
      lessonDate: DateTime(2026, 7, 24),
      periodId: period3Id,
      teacherId: teacher.id,
    );
    await loginAsTeacher();

    await tester.pumpWidget(
      MaterialApp(
        home: ClassJournalScreen(
          selectedClass: 'JL6А',
          store: store,
          subjectId: mongolId,
          initialDate: DateTime(2026, 7, 24, 10, 30),
          initialPeriodId: period3Id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ClassJournalScreen), findsOneWidget);
    // Single period → no period dropdown (read-only header text only).
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.textContaining('3-р цаг · 10:20–11:00'), findsWidgets);
  });

  testWidgets('multiple periods show one dropdown item each', (tester) async {
    await scheduleOnWeekday(DateTime.friday, [period1Id, period3Id]);
    await store.ensureLessonOccurrence(
      classId: 'JL6А',
      subjectId: mongolId,
      lessonDate: DateTime(2026, 7, 24),
      periodId: period1Id,
      teacherId: teacher.id,
    );
    await store.ensureLessonOccurrence(
      classId: 'JL6А',
      subjectId: mongolId,
      lessonDate: DateTime(2026, 7, 24),
      periodId: period3Id,
      teacherId: teacher.id,
    );
    await loginAsTeacher();

    await tester.pumpWidget(
      MaterialApp(
        home: ClassJournalScreen(
          selectedClass: 'JL6А',
          store: store,
          subjectId: mongolId,
          initialDate: DateTime(2026, 7, 24, 10, 30),
          initialPeriodId: period3Id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    // Open the menu and confirm each period appears once.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('1-р цаг · 08:00–08:40').evaluate().length, 1);
    expect(
      find.text('3-р цаг · 10:20–11:00').evaluate().length,
      greaterThan(0),
    );
  });
}
