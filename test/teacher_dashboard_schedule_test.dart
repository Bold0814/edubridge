import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/timetable.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/class_dashboard_screen.dart';
import 'package:edubridge/screens/timetable_viewer_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/timetable_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;
  late Teacher teacherA;
  late Teacher teacherB;
  late Teacher teacherLonely;
  late int mathId;
  late int physicsId;
  late LessonPeriod period1;
  late LessonPeriod period4;
  const schoolId = 'sch-tt-dash';
  const class12a = 'Tt12a';
  const class10b = 'Tt10b';

  /// Fixed Monday in local calendar fields (not UTC).
  final monday = DateTime(2026, 7, 20, 10, 0);
  final tuesday = DateTime(2026, 7, 21, 10, 0);

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();

    await store.createSchool(
      id: schoolId,
      name: 'Timetable School',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: schoolId,
      fullName: 'Admin',
      username: 'ttadmin',
      password: 'test123',
    );

    await store.addSchoolClass(name: class12a);
    await store.addSchoolClass(name: class10b);
    await store.addSchoolClass(name: 'TtEmpty');
    await store.addSubject('TtMath');
    await store.addSubject('TtPhysics');
    mathId = store.subjectByName('TtMath')!.id;
    physicsId = store.subjectByName('TtPhysics')!.id;

    teacherA = Teacher(
      id: store.nextTeacherId(),
      schoolId: schoolId,
      fullName: 'Bold',
      phone: '99001111',
    );
    await store.createTeacherWithOptionalLogin(
      teacher: teacherA,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );

    teacherB = Teacher(
      id: store.nextTeacherId(),
      schoolId: schoolId,
      fullName: 'Saraa',
      phone: '99002222',
    );
    await store.createTeacherWithOptionalLogin(
      teacher: teacherB,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );

    teacherLonely = Teacher(
      id: store.nextTeacherId(),
      schoolId: schoolId,
      fullName: 'Lonely',
      phone: '99003333',
    );
    await store.createTeacherWithOptionalLogin(
      teacher: teacherLonely,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );

    await store.saveClassAssignments(
      classId: class12a,
      homeroomTeacherId: teacherA.id,
      subjectTeacherIds: {
        mathId: teacherA.id,
        physicsId: teacherB.id,
      },
    );
    await store.saveClassAssignments(
      classId: class10b,
      homeroomTeacherId: teacherB.id,
      subjectTeacherIds: {physicsId: teacherA.id},
    );

    period1 = LessonPeriod(
      id: store.nextLessonPeriodId(),
      schoolId: schoolId,
      periodNumber: 1,
      startTime: '08:00',
      endTime: '08:40',
    );
    period4 = LessonPeriod(
      id: store.nextLessonPeriodId(),
      schoolId: schoolId,
      periodNumber: 4,
      startTime: '10:20',
      endTime: '11:00',
    );
    await store.addLessonPeriod(period1);
    await store.addLessonPeriod(period4);

    // 12a Monday: Math (A) period 1, Physics (B) period 4
    await store.addClassTimetable(
      ClassTimetable(
        id: store.nextClassTimetableId(),
        classId: class12a,
        weekday: DateTime.monday,
        periodId: period1.id,
        subjectId: mathId,
      ),
    );
    await store.addClassTimetable(
      ClassTimetable(
        id: store.nextClassTimetableId(),
        classId: class12a,
        weekday: DateTime.monday,
        periodId: period4.id,
        subjectId: physicsId,
      ),
    );
    // 10b Monday: Physics (A) period 4
    await store.addClassTimetable(
      ClassTimetable(
        id: store.nextClassTimetableId(),
        classId: class10b,
        weekday: DateTime.monday,
        periodId: period4.id,
        subjectId: physicsId,
      ),
    );

    // Also seed today's weekday so widget tests are deterministic.
    final todayWeekday = TimetableService.localWeekday();
    if (todayWeekday != DateTime.monday) {
      await store.addClassTimetable(
        ClassTimetable(
          id: store.nextClassTimetableId(),
          classId: class12a,
          weekday: todayWeekday,
          periodId: period1.id,
          subjectId: mathId,
        ),
      );
      await store.addClassTimetable(
        ClassTimetable(
          id: store.nextClassTimetableId(),
          classId: class12a,
          weekday: todayWeekday,
          periodId: period4.id,
          subjectId: physicsId,
        ),
      );
    }
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> loginAs(Teacher teacher, {required String phone}) async {
    try {
      await store.logout();
    } catch (_) {}
    await store.login(
      username: phone,
      password: 'Teach2026',
      rememberMe: false,
    );
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(store.authenticatedUser!.id).first,
    );
  }

  test('selected class schedule includes lessons taught by other teachers', () async {
    await loginAs(teacherA, phone: '99001111');
    await store.setTeacherWorkspace(classId: class12a, subjectId: mathId);

    final lessons = TimetableService.todayLessonsForClass(
      store,
      class12a,
      now: monday,
    );

    expect(lessons, hasLength(2));
    expect(
      lessons.map((l) => l.subjectName).toSet(),
      {'TtMath', 'TtPhysics'},
    );
    expect(
      lessons.map((l) => l.teacher?.id).toSet(),
      {teacherA.id, teacherB.id},
    );
  });

  test('selected class schedule excludes other classes', () async {
    final lessons = TimetableService.todayLessonsForClass(
      store,
      class12a,
      now: monday,
    );
    expect(lessons.every((l) => l.classId == class12a), isTrue);
    expect(lessons.any((l) => l.classId == class10b), isFalse);
  });

  test('teacher schedule includes lessons from multiple classes', () async {
    await loginAs(teacherA, phone: '99001111');
    final lessons = TimetableService.todayLessonsForTeacher(
      store,
      teacherA.id,
      now: monday,
    );
    expect(lessons, hasLength(2));
    expect(
      lessons.map((l) => '${l.classId}:${l.subjectName}').toSet(),
      {'Tt12a:TtMath', 'Tt10b:TtPhysics'},
    );
  });

  test('teacher schedule excludes lessons of other teachers', () async {
    final lessons = TimetableService.todayLessonsForTeacher(
      store,
      teacherA.id,
      now: monday,
    );
    expect(lessons.any((l) => l.subjectName == 'TtPhysics' && l.classId == class12a), isFalse);
    expect(
      lessons.every((l) {
        final assigned = store.teacherIdForClassSubject(
          l.classId,
          l.subject.id,
        );
        return assigned == teacherA.id;
      }),
      isTrue,
    );
  });

  test('activeSubjectId does not hide other class lessons', () async {
    await loginAs(teacherA, phone: '99001111');
    await store.setTeacherWorkspace(classId: class12a, subjectId: mathId);

    final classLessons = TimetableService.todayLessonsForClass(
      store,
      class12a,
      now: monday,
    );
    // Physics is still listed for the class even though workspace subject is Math.
    expect(classLessons.any((l) => l.subjectName == 'TtPhysics'), isTrue);
    expect(classLessons, hasLength(2));
  });

  test('period number displays correctly from saved periodNumber', () {
    expect(period1.scheduleHeading, '08:00–08:40 · 1-р цаг');
    expect(period4.scheduleHeading, '10:20–11:00 · 4-р цаг');
    expect(period1.periodOrdinalLabel, '1-р цаг');
    expect(period1.scheduleHeading.contains('(1 цаг)'), isFalse);

    final lessons = TimetableService.todayLessonsForClass(
      store,
      class12a,
      now: monday,
    );
    expect(lessons.first.scheduleHeading, '08:00–08:40 · 1-р цаг');
    expect(lessons.last.period.periodNumber, 4);
  });

  test('local weekday is used via AppClock calendar day', () async {
    expect(TimetableService.localWeekday(monday), DateTime.monday);
    expect(TimetableService.localWeekday(tuesday), DateTime.tuesday);

    final mondayLessons = TimetableService.todayLessonsForClass(
      store,
      class12a,
      now: monday,
    );
    final tuesdayLessons = TimetableService.todayLessonsForClass(
      store,
      class12a,
      now: tuesday,
    );
    expect(mondayLessons, isNotEmpty);
    expect(tuesdayLessons, isEmpty);
  });

  testWidgets('empty-state messages are correct for class and teacher', (
    tester,
  ) async {
    await loginAs(teacherA, phone: '99001111');
    await store.setTeacherWorkspace(classId: 'TtEmpty', subjectId: mathId);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassDashboardScreen(
            selectedClass: 'TtEmpty',
            store: store,
            onClassChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(ResolvedLesson.emptyClassTodayMessage), findsOneWidget);

    await loginAs(teacherLonely, phone: '99003333');

    await tester.pumpWidget(
      MaterialApp(
        home: TimetableViewerScreen(
          store: store,
          title: 'Миний хуваарь',
          mode: TimetableViewerMode.teacher,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(ResolvedLesson.emptyTeacherTodayMessage), findsOneWidget);
  });

  testWidgets('dashboard shows class schedule not only teacher lessons', (
    tester,
  ) async {
    await loginAs(teacherA, phone: '99001111');
    await store.setTeacherWorkspace(classId: class12a, subjectId: mathId);

    final classLessons = TimetableService.todayLessonsForClass(
      store,
      class12a,
    );
    expect(classLessons.length, greaterThanOrEqualTo(2));
    expect(
      classLessons.any((l) => l.subjectName == 'TtPhysics'),
      isTrue,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassDashboardScreen(
            selectedClass: class12a,
            store: store,
            onClassChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Өнөөдрийн хичээл'), findsOneWidget);
    expect(find.text('Миний хуваарь'), findsOneWidget);
    expect(find.textContaining('1-р цаг'), findsWidgets);

    // Lazy ListView may not build lower cards until scrolled.
    await tester.scrollUntilVisible(
      find.textContaining('TtPhysics'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('TtPhysics'), findsWidgets);
    expect(find.textContaining('Багш:'), findsWidgets);
  });

  testWidgets('Миний хуваарь opens teacher mode viewer', (tester) async {
    await loginAs(teacherA, phone: '99001111');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassDashboardScreen(
            selectedClass: class12a,
            store: store,
            onClassChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Миний хуваарь'));
    await tester.pumpAndSettle();

    expect(find.byType(TimetableViewerScreen), findsOneWidget);
    expect(find.text('Миний хуваарь'), findsWidgets);
  });
}
