import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/navigation/app_navigation.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/admin/admin_school_home_screen.dart';
import 'package:edubridge/screens/auth/login_screen.dart';
import 'package:edubridge/screens/home_screen.dart';
import 'package:edubridge/screens/teacher_account_screen.dart';
import 'package:edubridge/screens/teacher_workspace_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;
  late Teacher teacher;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();
    await store.createSchool(
      id: 'sch-nav',
      name: 'Нав сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-nav',
      fullName: 'А. Админ',
      username: 'navadmin',
      password: 'Admin2026',
    );
    await store.addSchoolClass(name: 'NAV6А');
    await store.addSubject('NAVМонгол');
    final subjectId = store.activeSubjects
        .firstWhere((s) => s.name == 'NAVМонгол')
        .id;
    teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: 'sch-nav',
      fullName: 'Н. Багш',
      phone: '99112233',
    );
    await store.createTeacherWithOptionalLogin(
      teacher: teacher,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );
    await store.saveClassAssignments(
      classId: 'NAV6А',
      homeroomTeacherId: teacher.id,
      subjectTeacherIds: {subjectId: teacher.id},
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> clearTeacherPasswordChangeFlag() async {
    final account = store.loginAccountForTeacher(teacher.id);
    if (account == null) return;
    await store.updateUserAccount(
      account.copyWith(requirePasswordChange: false),
    );
  }

  Future<void> loginAsTeacher() async {
    await clearTeacherPasswordChangeFlag();
    await store.logout();
    final result = await store.login(
      username: '99112233',
      password: 'Teach2026',
      rememberMe: false,
    );
    expect(result, LoginResult.success);
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(store.authenticatedUser!.id).first,
    );
  }

  testWidgets('teacher workspace has no Back button', (tester) async {
    await loginAsTeacher();
    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TeacherWorkspaceScreen), findsOneWidget);
    expect(find.byTooltip('Буцах'), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('teacher workspace cannot pop to a blank screen', (tester) async {
    await loginAsTeacher();
    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);

    // System back is intercepted — stays on workspace (or shows exit dialog).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(TeacherWorkspaceScreen), findsOneWidget);
    expect(find.text('Аппаас гарах уу?'), findsOneWidget);

    await tester.tap(find.text('Үгүй'));
    await tester.pumpAndSettle();

    expect(find.byType(TeacherWorkspaceScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated Back does not produce black screen', (tester) async {
    await loginAsTeacher();
    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      if (find.text('Үгүй').evaluate().isNotEmpty) {
        await tester.tap(find.text('Үгүй'));
        await tester.pumpAndSettle();
      }
    }

    expect(find.byType(TeacherWorkspaceScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('internal screen Back returns to teacher workspace', (
    tester,
  ) async {
    await loginAsTeacher();
    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('NAV6А анги').first);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Буцах'));
    await tester.pumpAndSettle();

    expect(find.byType(TeacherWorkspaceScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('logout returns to login and clears authenticated routes', (
    tester,
  ) async {
    await loginAsTeacher();
    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('NAV6А анги').first);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    // Pop back then logout from workspace menu.
    await tester.tap(find.byTooltip('Буцах'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Гарах'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(TeacherWorkspaceScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
    expect(store.authenticatedUser, isNull);
    expect(store.activeContext.classId, isNull);
    expect(store.activeContext.subjectId, isNull);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('menu includes account and change password', (tester) async {
    await loginAsTeacher();
    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Бүртгэл'), findsOneWidget);
    expect(find.text('Нууц үг солих'), findsOneWidget);
    expect(find.text('Гарах'), findsOneWidget);

    await tester.tap(find.text('Бүртгэл'));
    await tester.pumpAndSettle();
    expect(find.byType(TeacherAccountScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(TeacherWorkspaceScreen), findsOneWidget);
  });

  testWidgets('admin+teacher openTeacherWorkspace becomes root', (
    tester,
  ) async {
    expect(store.activeSchoolId, 'sch-nav');

    await tester.pumpWidget(
      MaterialApp(home: AdminSchoolHomeScreen(store: store)),
    );
    await tester.pumpAndSettle();

    AppNavigation.openTeacherWorkspace(
      tester.element(find.byType(AdminSchoolHomeScreen)),
      store,
    );
    await tester.pumpAndSettle();

    expect(find.byType(TeacherWorkspaceScreen), findsOneWidget);
    expect(find.byType(AdminSchoolHomeScreen), findsNothing);
    expect(find.byTooltip('Буцах'), findsNothing);
    expect(store.activeSchoolId, 'sch-nav');

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);

    // Return to admin via Бүртгэл → Админ нүүр рүү
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Бүртгэл'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Админ нүүр рүү'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminSchoolHomeScreen), findsOneWidget);
    expect(find.byType(TeacherWorkspaceScreen), findsNothing);
    expect(store.activeSchoolId, 'sch-nav');
    expect(store.authenticatedUser?.username, 'navadmin');
  });

  testWidgets('login route replaces stack with teacher workspace root', (
    tester,
  ) async {
    await clearTeacherPasswordChangeFlag();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () async {
                  await store.logout();
                  await store.login(
                    username: '99112233',
                    password: 'Teach2026',
                    rememberMe: false,
                  );
                  await store.selectSchoolMembership(
                    store
                        .activeMembershipsForUser(store.authenticatedUser!.id)
                        .first,
                  );
                  if (!context.mounted) return;
                  await AppNavigation.continueFromSchoolResolution(
                    context,
                    store,
                    preferLastSchool: false,
                  );
                },
                child: const Text('Нэвтрэх тест'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Нэвтрэх тест'));
    await tester.pumpAndSettle();

    expect(find.byType(TeacherWorkspaceScreen), findsOneWidget);
    expect(find.byTooltip('Буцах'), findsNothing);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
  });
}
