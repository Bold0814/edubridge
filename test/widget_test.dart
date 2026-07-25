import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edubridge/main.dart';
import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/user_account.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/auth/login_screen.dart';
import 'package:edubridge/screens/role_selection_screen.dart';
import 'package:edubridge/screens/teacher_workspace_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:edubridge/widgets/edubridge_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app starts at LoginScreen without remembered session', (
    WidgetTester tester,
  ) async {
    final database = await DatabaseService.instance.openInMemoryForTest();
    addTearDown(database.close);
    final store = AppStore(EduBridgeRepository(database));
    await store.load();

    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: AppStore.defaultSchoolId,
      fullName: 'Т.Тест',
    );
    await store.addTeacher(teacher);
    await store.saveClassAssignments(
      classId: '6А',
      homeroomTeacherId: teacher.id,
      subjectTeacherIds: const {},
    );
    await store.addUserAccount(
      UserAccount(
        id: store.nextUserId(),
        username: 'teacher1',
        passwordHash: '',
        role: AppRole.teacher,
        teacherId: teacher.id,
        createdAt: DateTime.now(),
      ),
      plainPassword: 'test123',
    );

    await tester.pumpWidget(EduBridgeApp(store: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RoleSelectionScreen), findsNothing);
    expect(find.text('Багш'), findsNothing);
    expect(find.text('Асран хамгаалагч'), findsNothing);
    expect(find.text('Сурагч'), findsNothing);
    expect(find.byType(EduBridgeLogo), findsWidgets);
    expect(find.text('Нэвтрэх'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'teacher1');
    await tester.enterText(find.byType(TextField).at(1), 'test123');
    await tester.tap(find.text('Нэвтрэх'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TeacherWorkspaceScreen), findsOneWidget);
    expect(find.text('Анги удирдсан'), findsOneWidget);
    expect(store.activeSchoolId, AppStore.defaultSchoolId);

    await tester.tap(find.text('6А анги'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Сайн байна уу,'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('demo guardian login reaches portal', (
    WidgetTester tester,
  ) async {
    final database = await DatabaseService.instance.openInMemoryForTest();
    addTearDown(database.close);
    final store = AppStore(EduBridgeRepository(database));
    await store.load();
    await store.ensureDemoAccountsIfNeeded();

    await tester.pumpWidget(EduBridgeApp(store: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'guardian1');
    await tester.enterText(find.byType(TextField).at(1), 'test123');
    await tester.tap(find.text('Нэвтрэх'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Асран хамгаалагч'), findsWidgets);
    expect(find.byType(RoleSelectionScreen), findsNothing);
  });
}
