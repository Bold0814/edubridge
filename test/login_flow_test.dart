import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/guardian_student.dart';
import 'package:edubridge/models/school.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/auth/login_screen.dart';
import 'package:edubridge/screens/guardian/guardian_child_selection_screen.dart';
import 'package:edubridge/screens/guardian/guardian_home_screen.dart';
import 'package:edubridge/screens/role_selection_screen.dart';
import 'package:edubridge/screens/school/school_selection_screen.dart';
import 'package:edubridge/screens/splash_screen.dart';
import 'package:edubridge/screens/student/student_home_screen.dart';
import 'package:edubridge/screens/teacher_workspace_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/password_hasher.dart';
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
    await store.ensureDemoAccountsIfNeeded();
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('app starts at LoginScreen with no session', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SplashScreen(store: store)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RoleSelectionScreen), findsNothing);
    expect(find.text('Багш'), findsNothing);
  });

  test('valid teacher login', () async {
    final result = await store.login(
      username: 'teacher1',
      password: 'test123',
      rememberMe: false,
    );
    expect(result, LoginResult.success);
    expect(store.authenticatedUser?.username, 'teacher1');
    expect(store.authenticatedUser?.role, AppRole.teacher);
  });

  test('valid guardian login', () async {
    final result = await store.login(
      username: 'guardian1',
      password: 'test123',
      rememberMe: false,
    );
    expect(result, LoginResult.success);
    expect(store.authenticatedUser?.role, AppRole.guardian);
  });

  test('valid student login', () async {
    final result = await store.login(
      username: 'student1',
      password: 'test123',
      rememberMe: false,
    );
    expect(result, LoginResult.success);
    expect(store.authenticatedUser?.role, AppRole.student);
  });

  test('incorrect password', () async {
    final result = await store.login(
      username: 'teacher1',
      password: 'wrong',
      rememberMe: false,
    );
    expect(result, LoginResult.invalidCredentials);
    expect(store.authenticatedUser, isNull);
  });

  test('inactive account', () async {
    final user = store.userByUsername('teacher1')!;
    await store.updateUserAccount(user.copyWith(isActive: false));
    final result = await store.login(
      username: 'teacher1',
      password: 'test123',
      rememberMe: false,
    );
    expect(result, LoginResult.inactive);
  });

  test('one school skips school selection after login', () async {
    await store.login(
      username: 'teacher1',
      password: 'test123',
      rememberMe: false,
    );
    final result = await store.resolveSchoolEntry(preferLastSchool: false);
    expect(result.kind, SchoolResolveKind.single);
  });

  test('multiple schools show school selection on fresh login', () async {
    await store.addSchool(
      const School(id: 'sch-b', name: 'Хоёрдугаар сургууль'),
    );
    final user = store.userByUsername('teacher1')!;
    await store.addMembership(
      UserSchoolMembership(
        id: store.nextMembershipId(),
        userId: user.id,
        schoolId: 'sch-b',
        role: AppRole.teacher,
        teacherId: user.teacherId,
      ),
    );
    await store.login(
      username: 'teacher1',
      password: 'test123',
      rememberMe: false,
    );
    final result = await store.resolveSchoolEntry(preferLastSchool: false);
    expect(result.kind, SchoolResolveKind.multiple);
  });

  test('role is resolved automatically from membership', () async {
    await store.login(
      username: 'guardian1',
      password: 'test123',
      rememberMe: false,
    );
    final result = await store.resolveSchoolEntry(preferLastSchool: false);
    await store.selectSchoolMembership(result.membership!);
    expect(store.activeContext.role, AppRole.guardian);
    expect(store.activeContext.guardianId, isNotNull);
  });

  testWidgets('teacher login opens TeacherWorkspaceScreen', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
    await tester.enterText(find.byType(TextField).at(0), 'teacher1');
    await tester.enterText(find.byType(TextField).at(1), 'test123');
    await tester.tap(find.text('Нэвтрэх'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TeacherWorkspaceScreen), findsOneWidget);
    expect(find.byType(SchoolSelectionScreen), findsNothing);
  });

  testWidgets('guardian with one child skips child selection', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
    await tester.enterText(find.byType(TextField).at(0), 'guardian1');
    await tester.enterText(find.byType(TextField).at(1), 'test123');
    await tester.tap(find.text('Нэвтрэх'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GuardianHomeScreen), findsOneWidget);
    expect(find.byType(GuardianChildSelectionScreen), findsNothing);
  });

  testWidgets('guardian with multiple children sees child selector', (
    tester,
  ) async {
    final className = store.classes.first;
    final second = Student(
      id: store.nextStudentId(className),
      className: className,
      lastName: 'Хоёр',
      firstName: 'Хүүхэд',
      gender: StudentGender.female,
    );
    await store.addStudent(second);
    await store.saveGuardianStudentLinks(
      guardianId: AppStore.demoGuardianId,
      links: [
        const GuardianStudent(
          guardianId: AppStore.demoGuardianId,
          studentId: AppStore.demoStudentId,
          relationship: 'Ээж',
        ),
        GuardianStudent(
          guardianId: AppStore.demoGuardianId,
          studentId: second.id,
          relationship: 'Аав',
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
    await tester.enterText(find.byType(TextField).at(0), 'guardian1');
    await tester.enterText(find.byType(TextField).at(1), 'test123');
    await tester.tap(find.text('Нэвтрэх'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GuardianChildSelectionScreen), findsOneWidget);
    expect(find.text('Миний хүүхдүүд'), findsWidgets);
  });

  testWidgets('student opens StudentDashboardScreen directly', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
    await tester.enterText(find.byType(TextField).at(0), 'student1');
    await tester.enterText(find.byType(TextField).at(1), 'test123');
    await tester.tap(find.text('Нэвтрэх'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(StudentHomeScreen), findsOneWidget);
    expect(find.byType(RoleSelectionScreen), findsNothing);
    expect(find.byType(SchoolSelectionScreen), findsNothing);
  });

  test('logout clears all active context', () async {
    await store.login(
      username: 'teacher1',
      password: 'test123',
      rememberMe: true,
    );
    final result = await store.resolveSchoolEntry(preferLastSchool: false);
    await store.selectSchoolMembership(result.membership!);
    await store.setTeacherWorkspace(classId: '6А', subjectId: null);

    expect(store.authenticatedUser, isNotNull);
    expect(store.activeSchoolId, isNotNull);

    await store.logout();
    expect(store.authenticatedUser, isNull);
    expect(store.activeSchoolId, isNull);
    expect(store.activeContext.classId, isNull);
    expect(store.activeContext.subjectId, isNull);
    expect(store.activeContext.selectedChildId, isNull);
    expect(store.hasValidRememberedSession, isFalse);
  });

  test('remembered session restores user', () async {
    await store.login(
      username: 'teacher1',
      password: 'test123',
      rememberMe: true,
    );
    final result = await store.resolveSchoolEntry(preferLastSchool: false);
    await store.selectSchoolMembership(result.membership!);

    final store2 = AppStore(EduBridgeRepository(database));
    await store2.load();
    expect(store2.hasValidRememberedSession, isTrue);
    expect(store2.authenticatedUser?.username, 'teacher1');
  });

  test('password is never stored in plain text', () async {
    final user = store.userByUsername('teacher1')!;
    expect(user.passwordHash.contains('test123'), isFalse);
    expect(PasswordHasher.verifyPassword('test123', user.passwordHash), isTrue);
  });
}
