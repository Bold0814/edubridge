import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/navigation/app_navigation.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/admin/admin_school_home_screen.dart';
import 'package:edubridge/screens/onboarding/school_setup_screen.dart';
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
      password: 'test123',
    );
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('workspace opened from setup shows back button', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SchoolSetupScreen(store: store)));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(SchoolSetupScreen))).push(
      MaterialPageRoute(
        builder: (context) => TeacherWorkspaceScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TeacherWorkspaceScreen), findsOneWidget);
    expect(find.byTooltip('Буцах'), findsOneWidget);
  });

  testWidgets('pressing back returns to setup', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SchoolSetupScreen(store: store)));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(SchoolSetupScreen))).push(
      MaterialPageRoute(
        builder: (context) => TeacherWorkspaceScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Буцах'));
    await tester.pumpAndSettle();

    expect(find.byType(SchoolSetupScreen), findsOneWidget);
    expect(find.byType(TeacherWorkspaceScreen), findsNothing);
    expect(find.text('Сургуулиа бэлтгэх'), findsWidgets);
  });

  testWidgets(
    'workspace opened as login root does not show a dead back button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: TeacherWorkspaceScreen(store: store)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TeacherWorkspaceScreen), findsOneWidget);
      expect(find.byTooltip('Буцах'), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    },
  );

  testWidgets('active school context is preserved after returning', (
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
    expect(store.activeSchoolId, 'sch-nav');

    await tester.tap(find.byTooltip('Буцах'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminSchoolHomeScreen), findsOneWidget);
    expect(store.activeSchoolId, 'sch-nav');
    expect(store.authenticatedUser?.username, 'navadmin');
  });
}
