import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/subject_create_screen.dart';
import 'package:edubridge/screens/subjects_settings_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();
    await store.createSchool(
      id: 'sch-subj',
      name: 'Хичээл сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-subj',
      fullName: 'А. Админ',
      username: 'subjadmin',
      password: 'Admin2026',
    );
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('opening SubjectCreateScreen does not throw', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SubjectCreateScreen(store: store)),
    );
    await tester.pump();
    expect(find.text('Хичээл нэмэх'), findsOneWidget);
    expect(find.text('Хичээлийн нэр'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving a subject returns true and list refreshes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SubjectsSettingsScreen(store: store)),
    );
    await tester.pump();

    await tester.tap(find.text('Хичээл нэмэх'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SubjectCreateScreen), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'SetupБиологи');
    await tester.tap(find.text('Хадгалах'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SubjectCreateScreen), findsNothing);
    expect(find.text('SetupБиологи'), findsOneWidget);
    expect(
      store.allSubjects.where((s) => s.name == 'SetupБиологи'),
      hasLength(1),
    );
  });

  test('valid school admin can create a subject', () async {
    await store.addSubject('AdminМат');
    expect(store.allSubjects.any((s) => s.name == 'AdminМат'), isTrue);
    expect(
      store.allSubjects.firstWhere((s) => s.name == 'AdminМат').schoolId,
      'sch-subj',
    );
  });

  test('same subject name allowed in different schools', () async {
    await store.addSubject('Математик');
    await store.createSchool(
      id: 'sch-subj-b',
      name: 'Хоёрдугаар сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-subj-b',
      fullName: 'Б. Админ',
      username: 'subjadmin2',
      password: 'Admin2026',
    );
    await store.addSubject('Математик');
    expect(store.allSubjects.where((s) => s.name == 'Математик'), hasLength(1));
    expect(
      store.allSubjects.singleWhere((s) => s.name == 'Математик').schoolId,
      'sch-subj-b',
    );
  });

  test('admin creates subjects only for active schoolId', () async {
    await store.createSchool(
      id: 'sch-other',
      name: 'Бусад',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.addSubject('StillOwnSchool');
    expect(store.allSubjects.every((s) => s.schoolId == 'sch-subj'), isTrue);
    expect(store.allSubjects.any((s) => s.schoolId == 'sch-other'), isFalse);
  });

  test('teacher cannot create a subject', () async {
    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: 'sch-subj',
      fullName: 'Т. Багш',
      phone: '99110001',
    );
    await store.createTeacherWithOptionalLogin(
      teacher: teacher,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );
    await store.logout();
    final login = await store.login(
      username: '99110001',
      password: 'Teach2026',
      rememberMe: false,
    );
    expect(login, LoginResult.success);
    final membership = store
        .activeMembershipsForUser(store.authenticatedUser!.id)
        .firstWhere((m) => m.schoolId == 'sch-subj');
    await store.selectSchoolMembership(membership);

    expect(
      () => store.addSubject('TeacherBlocked'),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  test('student and guardian cannot create a subject', () async {
    await store.addSchoolClass(name: 'SC12А');
    final student = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('SC12А'),
        className: 'SC12А',
        lastName: 'С',
        firstName: 'Сурагч',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Г. Эцэг',
      guardianPhone: '88001111',
      relationship: 'Эцэг',
    );
    final studentAccount = store.accountForStudentId(student.id)!;
    await store.activateAccountWithPin(userId: studentAccount.id, pin: '2468');
    await store.logout();
    expect(
      await store.login(
        username: studentAccount.username,
        password: '2468',
        rememberMe: false,
      ),
      LoginResult.success,
    );
    expect(
      () => store.addSubject('StudentBlocked'),
      throwsA(isA<PermissionDeniedException>()),
    );

    final guardian = store.guardiansForStudent(student.id).first;
    final guardianAccount = store.accountForGuardianId(guardian.id)!;
    await store.activateAccountWithPin(userId: guardianAccount.id, pin: '1357');
    await store.logout();
    expect(
      await store.login(
        username: guardianAccount.username,
        password: '1357',
        rememberMe: false,
      ),
      LoginResult.success,
    );
    expect(
      () => store.addSubject('GuardianBlocked'),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  test('missing admin membership is rejected', () async {
    await store.logout();
    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: 'sch-subj',
      fullName: 'No Mem',
      phone: '99110099',
    );
    // Re-login as admin to create teacher, then strip memberships for that user.
    await store.login(
      username: 'subjadmin',
      password: 'Admin2026',
      rememberMe: false,
    );
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(store.authenticatedUser!.id).first,
    );
    await store.createTeacherWithOptionalLogin(
      teacher: teacher,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );
    await store.logout();
    await store.login(
      username: '99110099',
      password: 'Teach2026',
      rememberMe: false,
    );
    // Teacher membership exists but is not admin — rejected.
    expect(store.hasAdminPermissionForActiveSchool, isFalse);
    expect(
      () => store.addSubject('NoAdminMembership'),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  test('duplicate normalized subject name is rejected', () async {
    await store.addSubject('SetupХими');
    expect(
      () => store.addSubject('SetupХими'),
      throwsA(
        isA<ArgumentError>().having((e) => e.message, 'message', 'DUPLICATE'),
      ),
    );
    expect(store.allSubjects.where((s) => s.name == 'SetupХими'), hasLength(1));
  });

  test('case-insensitive duplicate subject name is rejected', () async {
    await store.addSubject('SetupХими2');
    expect(
      () => store.addSubject('setupхими2'),
      throwsA(
        isA<ArgumentError>().having((e) => e.message, 'message', 'DUPLICATE'),
      ),
    );
  });

  test('reloadSubjectsForActiveSchool refreshes list', () async {
    await store.addSubject('SetupФизик');
    await store.reloadSubjectsForActiveSchool();
    expect(store.allSubjects.any((s) => s.name == 'SetupФизик'), isTrue);
  });

  testWidgets('permission denied shows Mongolian admin message', (
    tester,
  ) async {
    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: 'sch-subj',
      fullName: 'Т. Багш2',
      phone: '99110002',
    );
    await store.createTeacherWithOptionalLogin(
      teacher: teacher,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );
    await store.logout();
    await store.login(
      username: '99110002',
      password: 'Teach2026',
      rememberMe: false,
    );
    final membership = store
        .activeMembershipsForUser(store.authenticatedUser!.id)
        .first;
    await store.selectSchoolMembership(membership);

    await tester.pumpWidget(
      MaterialApp(home: SubjectCreateScreen(store: store)),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'BlockedSubject');
    await tester.tap(find.text('Хадгалах'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text(
        'Танд энэ хичээлийг нэмэх эрх алга. Админ бүртгэлээ шалгана уу.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('disposing SubjectCreateScreen does not dispose AppStore', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SubjectCreateScreen(store: store)),
    );
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(store.isLoaded, isTrue);
    await store.reloadSubjectsForActiveSchool();
    expect(() => store.allSubjects, returnsNormally);
  });
}
