import 'package:edubridge/models/announcement.dart';
import 'package:edubridge/models/attendance_record.dart';
import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/homework.dart';
import 'package:edubridge/models/school_data_reset.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/timetable.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/admin/data_security_screen.dart';
import 'package:edubridge/screens/admin/test_data_reset_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/school_data_reset/school_data_reset_service.dart';
import 'package:edubridge/services/school_data_reset/sqlite_school_data_reset_repository.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;
  late SqliteSchoolDataResetRepository resetRepo;
  late SchoolDataResetService resetService;
  late String adminUserId;
  late Teacher otherTeacher;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();
    await store.createSchool(
      id: 'sch-reset-a',
      name: 'Цэвэрлэх сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-reset-a',
      fullName: 'А. Админ',
      username: 'resetadmin',
      password: 'Admin2026',
    );
    adminUserId = store.authenticatedUser!.id;

    await store.addSchoolClass(name: 'R6А');
    await store.addSubject('RМонгол');
    final subjectId = store.activeSubjects
        .firstWhere((s) => s.name == 'RМонгол')
        .id;

    otherTeacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: 'sch-reset-a',
      fullName: 'Т. Багш',
      phone: '99001100',
    );
    await store.createTeacherWithOptionalLogin(
      teacher: otherTeacher,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );
    await store.saveClassAssignments(
      classId: 'R6А',
      homeroomTeacherId: otherTeacher.id,
      subjectTeacherIds: {subjectId: otherTeacher.id},
    );

    await store.addStudent(
      Student(
        id: store.nextStudentId('R6А'),
        className: 'R6А',
        lastName: 'Бат',
        firstName: 'Болд',
        gender: StudentGender.male,
      ),
    );

    final periodId = store.nextLessonPeriodId();
    await store.addLessonPeriod(
      LessonPeriod(
        id: periodId,
        schoolId: 'sch-reset-a',
        periodNumber: 1,
        startTime: '08:00',
        endTime: '08:40',
      ),
    );
    await store.addClassTimetable(
      ClassTimetable(
        id: store.nextClassTimetableId(),
        classId: 'R6А',
        weekday: DateTime.monday,
        periodId: periodId,
        subjectId: subjectId,
      ),
    );

    await store.setTeacherWorkspace(classId: 'R6А', subjectId: subjectId);
    await store.addAttendance(
      'R6А',
      AttendanceRecord.detailed(
        id: store.nextAttendanceId(),
        date: '2026 оны 7 сарын 28',
        className: 'R6А',
        entries: const [
          StudentAttendanceEntry(
            studentName: 'Бат Болд',
            status: AttendanceStatus.present,
          ),
        ],
      ),
    );
    final student = store.studentsFor('R6А').first;
    await store.addGrade(
      Grade(
        id: store.nextGradeId(),
        className: 'R6А',
        studentId: student.id,
        studentName: student.fullName,
        subject: 'RМонгол',
        score: '90',
        term: '1-р улирал',
      ),
    );
    await store.addHomework(
      Homework(
        id: store.nextHomeworkId(),
        className: 'R6А',
        subject: 'RМонгол',
        title: 'Даалгавар 1',
        description: 'Унших',
        dueDate: '2026 оны 7 сарын 30',
        status: HomeworkStatus.pending,
      ),
    );
    await store.addAnnouncement(
      Announcement(
        id: store.nextAnnouncementId(),
        schoolId: 'sch-reset-a',
        className: 'R6А',
        title: 'Зарлал',
        body: 'Текст',
        date: '2026 оны 7 сарын 28',
        isFeatured: false,
      ),
    );
    await store.ensureLessonOccurrence(
      classId: 'R6А',
      subjectId: subjectId,
      lessonDate: DateTime(2026, 7, 28),
      periodId: periodId,
      teacherId: otherTeacher.id,
    );

    await store.createSchool(
      id: 'sch-reset-b',
      name: 'Бусад сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.selectSchoolMembership(
      store
          .activeMembershipsForUser(adminUserId)
          .firstWhere((m) => m.schoolId == 'sch-reset-a'),
    );

    resetRepo = SqliteSchoolDataResetRepository(database);
    resetService = SchoolDataResetService(store: store, repository: resetRepo);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('only admin can open data reset screens', (tester) async {
    expect(store.hasAdminPermissionForActiveSchool, isTrue);
    await tester.pumpWidget(
      MaterialApp(home: DataSecurityScreen(store: store)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Аюултай үйлдэл'), findsOneWidget);
    expect(find.text('Туршилтын өгөгдөл цэвэрлэх'), findsOneWidget);
  });

  testWidgets('normal teacher cannot open the route directly', (tester) async {
    final account = store.loginAccountForTeacher(otherTeacher.id)!;
    await store.logout();
    await store.login(
      username: account.username,
      password: 'Teach2026',
      rememberMe: false,
    );
    final memberships = store.activeMembershipsForUser(
      store.authenticatedUser!.id,
    );
    if (memberships.isNotEmpty) {
      await store.selectSchoolMembership(memberships.first);
    }

    expect(store.hasAdminPermissionForActiveSchool, isFalse);

    await tester.pumpWidget(
      MaterialApp(home: TestDataResetScreen(store: store)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Энэ үйлдлийг хийх эрхгүй байна.'), findsOneWidget);
    expect(find.text('Устгагдах мэдээлэл'), findsNothing);
  });

  test('preview counts are real and school-scoped', () async {
    final preview = await resetService.getPreview();
    expect(preview.schoolId, 'sch-reset-a');
    expect(preview.classCount, greaterThanOrEqualTo(1));
    expect(preview.teacherCount, greaterThanOrEqualTo(1));
    expect(preview.studentCount, 1);
    expect(preview.attendanceCount, 1);
    expect(preview.gradeCount, 1);
    expect(preview.homeworkCount, 1);
    expect(preview.announcementCount, 1);
    expect(preview.journalCount, 1);
  });

  test('reset deletes operational data and preserves admin', () async {
    final result = await resetService.resetOperationalData(
      scope: const SchoolResetScope(),
      confirmationPhrase: 'УСТГАХ',
      adminPassword: 'Admin2026',
    );

    expect(result.deleted.students, 1);
    expect(store.authenticatedUser?.id, adminUserId);
    expect(store.hasAdminPermissionForActiveSchool, isTrue);
    expect(
      store
          .activeMembershipsForUser(adminUserId)
          .any((m) => m.schoolId == 'sch-reset-a' && m.role.name == 'admin'),
      isTrue,
    );

    expect(store.classes.where((c) => c == 'R6А'), isEmpty);
    expect(store.attendanceFor('R6А'), isEmpty);
    expect(store.gradesFor('R6А'), isEmpty);
    expect(store.homeworkFor('R6А'), isEmpty);
    expect(store.teachers.where((t) => t.id == otherTeacher.id), isEmpty);
    expect(store.loginAccountForTeacher(otherTeacher.id), isNull);
    expect(store.activeContext.classId, isNull);
    expect(store.activeContext.subjectId, isNull);

    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='classes'",
    );
    expect(tables, isNotEmpty);
    expect(store.schools.any((s) => s.id == 'sch-reset-a'), isTrue);
  });

  test('reset does not delete another school’s row', () async {
    expect(store.schools.any((s) => s.id == 'sch-reset-b'), isTrue);

    await resetService.resetOperationalData(
      scope: const SchoolResetScope(),
      confirmationPhrase: 'УСТГАХ',
      adminPassword: 'Admin2026',
    );

    expect(store.schools.any((s) => s.id == 'sch-reset-b'), isTrue);
  });

  test('transaction rollback restores all data after forced failure', () async {
    resetRepo.debugForceFailure = true;
    final studentCountBefore = store.studentsFor('R6А').length;
    final teacherCountBefore = store.teachers
        .where((t) => t.schoolId == 'sch-reset-a')
        .length;

    await expectLater(
      resetService.resetOperationalData(
        scope: const SchoolResetScope(),
        confirmationPhrase: 'УСТГАХ',
        adminPassword: 'Admin2026',
      ),
      throwsA(isA<StateError>()),
    );

    expect(store.studentsFor('R6А'), hasLength(studentCountBefore));
    expect(
      store.teachers.where((t) => t.schoolId == 'sch-reset-a').length,
      teacherCountBefore,
    );
  });

  test('reset requires exact УСТГАХ and valid password', () async {
    expect(
      () => resetService.resetOperationalData(
        scope: const SchoolResetScope(),
        confirmationPhrase: 'устгах',
        adminPassword: 'Admin2026',
      ),
      throwsA(isA<SchoolResetValidationException>()),
    );
    expect(
      () => resetService.resetOperationalData(
        scope: const SchoolResetScope(),
        confirmationPhrase: 'УСТГАХ',
        adminPassword: 'wrong',
      ),
      throwsA(isA<SchoolResetValidationException>()),
    );
  });

  test('full school delete is unavailable', () async {
    expect(
      () => resetService.deleteSchoolCompletely(),
      throwsA(isA<SchoolDeleteUnavailableException>()),
    );
  });

  test('school row survives operational reset', () async {
    await resetService.resetOperationalData(
      scope: const SchoolResetScope(structurePeople: false),
      confirmationPhrase: 'УСТГАХ',
      adminPassword: 'Admin2026',
    );
    final schools = await database.query('schools');
    expect(schools.any((r) => r['id'] == 'sch-reset-a'), isTrue);
  });

  testWidgets('wrong confirmation keeps destructive button disabled', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: TestDataResetScreen(store: store)),
    );
    await tester.pumpAndSettle();

    final continueBtn = find.widgetWithText(FilledButton, 'Үргэлжлүүлэх');
    await tester.ensureVisible(continueBtn.first);
    await tester.tap(continueBtn.first);
    await tester.pumpAndSettle();

    // First warning dialog.
    await tester.tap(find.widgetWithText(FilledButton, 'Үргэлжлүүлэх').last);
    await tester.pumpAndSettle();

    expect(find.text('Бүрмөсөн устгах'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Бүрмөсөн устгах'),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField).at(0), 'WRONG');
    await tester.enterText(find.byType(TextField).at(1), 'Admin2026');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Бүрмөсөн устгах'),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField).at(0), 'УСТГАХ');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Бүрмөсөн устгах'),
          )
          .onPressed,
      isNotNull,
    );
  });
}
