import 'package:edubridge/models/announcement.dart';
import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/homework.dart';
import 'package:edubridge/models/school.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/student_homework_status.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/timetable.dart';
import 'package:edubridge/models/user_account.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/announcement_create_screen.dart';
import 'package:edubridge/screens/class_create_screen.dart';
import 'package:edubridge/screens/class_list_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/password_hasher.dart';
import 'package:edubridge/services/pin_rules.dart';
import 'package:edubridge/services/timetable_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PinRules', () {
    test('exactly 4 digits accepted; 3/5 and non-numeric rejected', () {
      expect(PinRules.isValid('2468'), isTrue);
      expect(PinRules.isValid('123'), isFalse);
      expect(PinRules.isValid('12345'), isFalse);
      expect(PinRules.isValid('12ab'), isFalse);
      expect(PinRules.validateNewPin('2468', '2468'), isNull);
      expect(PinRules.validateNewPin('1234', '1234'), isNotNull);
      expect(PinRules.validateNewPin('0000', '0000'), isNotNull);
      expect(PinRules.validateNewPin('2468', '2469'), isNotNull);
    });
  });

  group('DB migration v13', () {
    test('fresh schema and upgrade path include v13 tables', () async {
      final fresh = await DatabaseService.instance.openInMemoryForTest();
      final tables = await fresh.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final names = tables.map((r) => r['name'] as String).toSet();
      expect(names.contains('student_homework_status'), isTrue);
      expect(names.contains('announcement_read_receipts'), isTrue);
      final cols = await fresh.rawQuery('PRAGMA table_info(user_accounts)');
      final colNames = cols.map((r) => r['name'] as String).toSet();
      expect(colNames.contains('failed_pin_attempts'), isTrue);
      expect(colNames.contains('pin_locked_until'), isTrue);
      await fresh.close();

      final upgraded = await DatabaseService.instance.openInMemoryUpgradingFrom(
        3,
      );
      final upgradedTables = await upgraded.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name IN ('student_homework_status','announcement_read_receipts')",
      );
      expect(upgradedTables, hasLength(2));
      await upgraded.close();
    });
  });

  group('stabilization store behavior', () {
    late Database database;
    late AppStore store;

    setUp(() async {
      database = await DatabaseService.instance.openInMemoryForTest();
      store = AppStore(EduBridgeRepository(database));
      await store.load();
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> seedAdmin() async {
      await store.createSchool(
        id: 'sch-stab',
        name: 'Тогтворжуулалт',
        academicYear: SchoolSettings.currentAcademicYear(),
        currentSemester: SchoolSettings.semesterOptions.first,
      );
      await store.createFirstSchoolAdmin(
        schoolId: 'sch-stab',
        fullName: 'А. Админ',
        username: 'stabadmin',
        password: 'admin123',
      );
      await store.addSchoolClass(name: 'ST6А');
      await store.addSubject('StabМат');
    }

    Future<UserAccount> loginTeacher() async {
      final teacher = Teacher(
        id: store.nextTeacherId(),
        schoolId: 'sch-stab',
        fullName: 'Б. Багш',
      );
      await store.addTeacher(teacher);
      await store.addUserAccount(
        UserAccount(
          id: store.nextUserId(),
          username: 'stabteacher',
          passwordHash: '',
          role: AppRole.teacher,
          teacherId: teacher.id,
          createdAt: DateTime.now(),
        ),
        plainPassword: 'teach123',
      );
      final account = store.userByUsername('stabteacher')!;
      final membership = store
          .activeMembershipsForUser(account.id)
          .firstWhere((m) => m.role == AppRole.teacher);
      await store.selectDevelopmentUser(account, rememberMe: false);
      await store.selectSchoolMembership(membership);
      return account;
    }

    test('teacher cannot manage timetable or school structure', () async {
      await seedAdmin();
      final period = LessonPeriod(
        id: store.nextLessonPeriodId(),
        schoolId: 'sch-stab',
        periodNumber: 1,
        startTime: '08:00',
        endTime: '08:45',
      );
      await store.addLessonPeriod(period);
      await loginTeacher();

      expect(store.canManageTimetable, isFalse);
      expect(store.canManageSchoolStructure, isFalse);

      expect(
        () => store.addLessonPeriod(
          LessonPeriod(
            id: store.nextLessonPeriodId(),
            schoolId: 'sch-stab',
            periodNumber: 2,
            startTime: '09:00',
            endTime: '09:45',
          ),
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(
        () => store.addSchoolClass(name: 'ST7Б'),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(
        () => store.addSubject('Физик'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('admin can manage timetable', () async {
      await seedAdmin();
      final period = LessonPeriod(
        id: store.nextLessonPeriodId(),
        schoolId: 'sch-stab',
        periodNumber: 1,
        startTime: '08:00',
        endTime: '08:45',
      );
      await store.addLessonPeriod(period);
      expect(store.lessonPeriods, isNotEmpty);

      final mathId = store.activeSubjects
          .firstWhere((s) => s.name == 'StabМат')
          .id;
      await store.addClassTimetable(
        ClassTimetable(
          id: store.nextClassTimetableId(),
          classId: 'ST6А',
          weekday: DateTime.monday,
          periodId: period.id,
          subjectId: mathId,
        ),
      );
      expect(store.timetableForClass('ST6А'), hasLength(1));
      await store.deleteClassTimetable(
        store.timetableForClass('ST6А').first.id,
      );
      expect(store.timetableForClass('ST6А'), isEmpty);
    });

    test('teacher week lessons only for assigned class/subject', () async {
      await seedAdmin();
      final teacher = Teacher(
        id: store.nextTeacherId(),
        schoolId: 'sch-stab',
        fullName: 'Х. Багш',
      );
      await store.addTeacher(teacher);
      final math = store.activeSubjects.firstWhere((s) => s.name == 'StabМат');
      await store.saveClassAssignments(
        classId: 'ST6А',
        homeroomTeacherId: teacher.id,
        subjectTeacherIds: {math.id: teacher.id},
      );
      await store.addSchoolClass(name: 'ST6Б');
      final period = LessonPeriod(
        id: store.nextLessonPeriodId(),
        schoolId: 'sch-stab',
        periodNumber: 1,
        startTime: '08:00',
        endTime: '08:45',
      );
      await store.addLessonPeriod(period);
      await store.addClassTimetable(
        ClassTimetable(
          id: store.nextClassTimetableId(),
          classId: 'ST6А',
          weekday: DateTime.monday,
          periodId: period.id,
          subjectId: math.id,
        ),
      );
      await store.addClassTimetable(
        ClassTimetable(
          id: store.nextClassTimetableId(),
          classId: 'ST6Б',
          weekday: DateTime.monday,
          periodId: period.id,
          subjectId: math.id,
        ),
      );

      final week = TimetableService.weekLessonsForTeacher(store, teacher.id);
      final flat = week.values.expand((e) => e).toList();
      expect(flat, isNotEmpty);
      expect(flat.every((l) => l.classId == 'ST6А'), isTrue);
    });

    test('PIN lockout after 5 failed attempts; success resets', () async {
      await seedAdmin();
      await store.addStudentWithRequiredGuardian(
        student: Student(
          id: store.nextStudentId('ST6А'),
          className: 'ST6А',
          lastName: 'Бат',
          firstName: 'Болд',
          gender: StudentGender.male,
        ),
        guardianFullName: 'Ээж',
        guardianPhone: '99001122',
        relationship: 'Ээж',
      );
      final student = store.studentsFor('ST6А').first;
      final lookup = store.lookupGuardianActivation(
        phone: '99001122',
        studentCode: student.studentCode!,
      );
      expect(lookup.result, ActivationLookupResult.ok);
      await store.activateAccountWithPin(
        userId: lookup.account!.id,
        pin: '2468',
      );

      for (var i = 0; i < 4; i++) {
        final r = await store.login(
          username: '99001122',
          password: '0000',
          rememberMe: false,
        );
        expect(r, LoginResult.invalidLearnerCredentials);
      }
      final locked = await store.login(
        username: '99001122',
        password: '0000',
        rememberMe: false,
      );
      expect(locked, LoginResult.temporarilyLocked);

      final stillLocked = await store.login(
        username: '99001122',
        password: '2468',
        rememberMe: false,
      );
      expect(stillLocked, LoginResult.temporarilyLocked);

      // Expire lock manually, then reload.
      final user = store.userByUsername('99001122')!;
      await store.repository.updateUserAccount(
        user.copyWith(failedPinAttempts: 0, clearPinLockedUntil: true),
      );
      await store.load();

      final ok = await store.login(
        username: '99001122',
        password: '2468',
        rememberMe: false,
      );
      expect(ok, LoginResult.success);
      expect(store.userByUsername('99001122')!.failedPinAttempts, 0);
      expect(store.userByUsername('99001122')!.pinLockedUntil, isNull);
      expect(
        PasswordHasher.verifyPassword(
          '2468',
          store.userByUsername('99001122')!.passwordHash,
        ),
        isTrue,
      );
      expect(
        store.userByUsername('99001122')!.passwordHash.contains('2468'),
        isFalse,
      );
    });

    test('homework status one per student; teacher can mark', () async {
      await seedAdmin();
      await store.addStudentWithRequiredGuardian(
        student: Student(
          id: store.nextStudentId('ST6А'),
          className: 'ST6А',
          lastName: 'Дорж',
          firstName: 'Ану',
          gender: StudentGender.female,
        ),
        guardianFullName: 'Аав',
        guardianPhone: '99110011',
        relationship: 'Аав',
      );
      final student = store.studentsFor('ST6А').first;
      final teacher = Teacher(
        id: store.nextTeacherId(),
        schoolId: 'sch-stab',
        fullName: 'Г. Багш',
      );
      await store.addTeacher(teacher);
      final subject = store.activeSubjects.firstWhere(
        (s) => s.name == 'StabМат',
      );
      await store.saveClassAssignments(
        classId: 'ST6А',
        homeroomTeacherId: teacher.id,
        subjectTeacherIds: {subject.id: teacher.id},
      );

      final hw = Homework(
        id: store.nextHomeworkId(),
        className: 'ST6А',
        subject: subject.name,
        title: 'Даалгавар 1',
        description: 'Хийх',
        dueDate: '2026-07-30',
        status: HomeworkStatus.pending,
      );
      await store.addHomework(hw);
      expect(store.homeworkStatusesForHomework(hw.id), hasLength(1));
      expect(
        store.effectiveHomeworkStatus(homeworkId: hw.id, studentId: student.id),
        StudentHomeworkStatusValue.pending,
      );

      await store.addUserAccount(
        UserAccount(
          id: store.nextUserId(),
          username: 'hwteacher',
          passwordHash: '',
          role: AppRole.teacher,
          teacherId: teacher.id,
          createdAt: DateTime.now(),
        ),
        plainPassword: 'teach123',
      );
      final account = store.userByUsername('hwteacher')!;
      await store.selectDevelopmentUser(account, rememberMe: false);
      await store.selectSchoolMembership(
        store.activeMembershipsForUser(account.id).first,
      );

      await store.setStudentHomeworkStatus(
        homeworkId: hw.id,
        studentId: student.id,
        status: StudentHomeworkStatusValue.completed,
        teacherComment: 'Сайн',
      );
      final row = store.homeworkStatusForStudent(
        homeworkId: hw.id,
        studentId: student.id,
      )!;
      expect(row.status, StudentHomeworkStatusValue.completed);
      expect(row.teacherComment, 'Сайн');
      expect(store.homeworkStatusesForHomework(hw.id), hasLength(1));
    });

    test('announcement open creates one receipt; no duplicate', () async {
      await seedAdmin();
      await store.addStudentWithRequiredGuardian(
        student: Student(
          id: store.nextStudentId('ST6А'),
          className: 'ST6А',
          lastName: 'Амар',
          firstName: 'Ану',
          gender: StudentGender.female,
        ),
        guardianFullName: 'Ээж',
        guardianPhone: '99223344',
        relationship: 'Ээж',
      );
      final announcement = Announcement(
        id: store.nextAnnouncementId(),
        schoolId: 'sch-stab',
        className: 'ST6А',
        title: 'Зар',
        body: 'Бие',
        date: '2026 оны 7 сарын 24',
        isFeatured: false,
      );
      await store.addAnnouncement(announcement);

      final student = store.studentsFor('ST6А').first;
      final studentAccount = UserAccount(
        id: store.nextUserId(),
        username: student.studentCode ?? 'S-CODE',
        passwordHash: PasswordHasher.hashPassword('2468'),
        role: AppRole.student,
        studentId: student.id,
        createdAt: DateTime.now(),
      );
      await store.repository.insertUserAccount(studentAccount);
      await store.repository.insertMembership(
        UserSchoolMembership(
          id: store.nextMembershipId(),
          userId: studentAccount.id,
          schoolId: 'sch-stab',
          role: AppRole.student,
          studentId: student.id,
        ),
      );
      await store.load();

      await store.selectDevelopmentUser(studentAccount, rememberMe: false);
      await store.selectSchoolMembership(
        store.activeMembershipsForUser(studentAccount.id).first,
      );

      await store.markAnnouncementOpened(announcement.id);
      await store.markAnnouncementOpened(announcement.id);
      final receipts = store.announcementReadReceiptsFor(announcement.id);
      expect(receipts.where((r) => r.role == AppRole.student), hasLength(1));
      expect(
        store.announcementReadCount(announcement.id),
        greaterThanOrEqualTo(1),
      );
    });

    testWidgets('announcement edit prefills title and body', (tester) async {
      await seedAdmin();
      final existing = Announcement(
        id: 'ann-edit-1',
        schoolId: 'sch-stab',
        className: 'ST6А',
        title: 'Хуучин гарчиг',
        body: 'Хуучин бие',
        date: '2026 оны 7 сарын 1',
        isFeatured: true,
      );
      await store.addAnnouncement(existing);

      await tester.pumpWidget(
        MaterialApp(
          home: AnnouncementCreateScreen(
            className: 'ST6А',
            store: store,
            existing: existing,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Зарлал засах'), findsOneWidget);
      expect(find.text('Хуучин гарчиг'), findsOneWidget);
      expect(find.text('Хуучин бие'), findsOneWidget);
    });

    testWidgets('class create pops true and list remains usable', (
      tester,
    ) async {
      await seedAdmin();
      await tester.pumpWidget(MaterialApp(home: ClassListScreen(store: store)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(ClassCreateScreen), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'ST8А');
      await tester.tap(find.text('Нэмэх'));
      await tester.pumpAndSettle();

      expect(find.byType(ClassListScreen), findsOneWidget);
      expect(
        store.schoolClassesForActiveSchool.any((c) => c.name == 'ST8А'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      expect(store.activeSchoolId, 'sch-stab');

      // Open create again and cancel with AppBar back — no crash.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ClassListScreen), findsOneWidget);
    });
  });
}
