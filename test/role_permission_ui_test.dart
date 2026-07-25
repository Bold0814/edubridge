import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/school.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/user_account.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/settings_screen.dart';
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
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedSchool(String id, String name) async {
    await store.createSchool(
      id: id,
      name: name,
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
  }

  /// Creates a pure teacher membership for [schoolId] and selects it.
  Future<UserAccount> loginAsTeacher({
    required String schoolId,
    required String username,
  }) async {
    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: schoolId,
      fullName: 'Т. Багш',
    );
    await store.addTeacher(teacher);
    await store.addUserAccount(
      UserAccount(
        id: store.nextUserId(),
        username: username,
        passwordHash: '',
        role: AppRole.teacher,
        teacherId: teacher.id,
        createdAt: DateTime.now(),
      ),
      plainPassword: 'test123',
    );
    final account = store.userByUsername(username)!;
    final membership = store
        .activeMembershipsForUser(account.id)
        .firstWhere(
          (m) => m.role == AppRole.teacher,
          orElse: () => store.activeMembershipsForUser(account.id).first,
        );
    if (membership.schoolId != schoolId) {
      final fixed = UserSchoolMembership(
        id: store.nextMembershipId(),
        userId: account.id,
        schoolId: schoolId,
        role: AppRole.teacher,
        teacherId: teacher.id,
      );
      await store.addMembership(fixed);
      await store.selectDevelopmentUser(account, rememberMe: false);
      await store.selectSchoolMembership(fixed);
    } else {
      await store.selectDevelopmentUser(account, rememberMe: false);
      await store.selectSchoolMembership(membership);
    }
    return account;
  }

  testWidgets('teacher does not see Settings gear', (tester) async {
    await seedSchool('sch-t', 'Багш сургууль');
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-t',
      fullName: 'А. Админ',
      username: 'tadmin',
      password: 'test123',
    );
    await loginAsTeacher(schoolId: 'sch-t', username: 'teacheronly');

    expect(store.hasAdminPermissionForActiveSchool, isFalse);
    expect(store.activeContext.role, AppRole.teacher);

    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Тохиргоо'), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
  });

  testWidgets('admin sees Settings gear', (tester) async {
    await seedSchool('sch-a', 'Админ сургууль');
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-a',
      fullName: 'А. Админ',
      username: 'onlyadmin',
      password: 'test123',
    );

    expect(store.hasAdminPermissionForActiveSchool, isTrue);

    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Тохиргоо'), findsOneWidget);
  });

  testWidgets('admin+teacher sees Settings gear', (tester) async {
    await seedSchool('sch-at', 'Хосолсон');
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-at',
      fullName: 'А. Хосолсон',
      username: 'adminteacher',
      password: 'test123',
    );

    expect(store.hasAdminPermissionForActiveSchool, isTrue);
    expect(store.hasTeacherWorkspaceAccess, isTrue);

    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Тохиргоо'), findsOneWidget);
  });

  testWidgets('teacher cannot open admin route', (tester) async {
    await seedSchool('sch-deny', 'Хязгаарлалт');
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-deny',
      fullName: 'А. Админ',
      username: 'denyadmin',
      password: 'test123',
    );
    await loginAsTeacher(schoolId: 'sch-deny', username: 'denyteacher');

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Энэ үйлдлийг хийх эрхгүй байна.'), findsOneWidget);
    expect(find.text('Сургуулийн мэдээлэл'), findsNothing);
  });

  testWidgets('teacher still sees logout', (tester) async {
    await seedSchool('sch-out', 'Гарах тест');
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-out',
      fullName: 'А. Админ',
      username: 'outadmin',
      password: 'test123',
    );
    await loginAsTeacher(schoolId: 'sch-out', username: 'outteacher');

    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Цэс'));
    await tester.pumpAndSettle();

    expect(find.text('Гарах'), findsOneWidget);
    expect(find.text('Сонголт солих'), findsNothing);
  });

  testWidgets('multi-school teacher sees school switch', (tester) async {
    await seedSchool('sch-m1', 'Нэгдүгээр');
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-m1',
      fullName: 'А. Админ',
      username: 'madmin',
      password: 'test123',
    );

    await seedSchool('sch-m2', 'Хоёрдугаар');
    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: 'sch-m1',
      fullName: 'Олон сургууль',
    );
    await store.addTeacher(teacher);
    await store.addUserAccount(
      UserAccount(
        id: store.nextUserId(),
        username: 'multiteacher',
        passwordHash: '',
        role: AppRole.teacher,
        teacherId: teacher.id,
        createdAt: DateTime.now(),
      ),
      plainPassword: 'test123',
    );
    final account = store.userByUsername('multiteacher')!;
    await store.addMembership(
      UserSchoolMembership(
        id: store.nextMembershipId(),
        userId: account.id,
        schoolId: 'sch-m2',
        role: AppRole.teacher,
        teacherId: teacher.id,
      ),
    );
    await store.selectDevelopmentUser(account, rememberMe: false);
    await store.selectSchoolMembership(
      store
          .activeMembershipsForUser(account.id)
          .firstWhere((m) => m.schoolId == 'sch-m1'),
    );

    expect(store.activeMembershipsForUser(account.id).length, greaterThan(1));

    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Цэс'));
    await tester.pumpAndSettle();

    expect(find.text('Сургууль солих'), findsOneWidget);
    expect(find.text('Гарах'), findsOneWidget);
  });

  testWidgets('active school context remains unchanged', (tester) async {
    await seedSchool('sch-keep', 'Хадгал');
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-keep',
      fullName: 'А. Админ',
      username: 'keepadmin',
      password: 'test123',
    );
    await loginAsTeacher(schoolId: 'sch-keep', username: 'keepteacher');

    expect(store.activeSchoolId, 'sch-keep');

    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Цэс'));
    await tester.pumpAndSettle();
    expect(find.text('Гарах'), findsOneWidget);

    expect(store.activeSchoolId, 'sch-keep');
    expect(store.activeContext.role, AppRole.teacher);
  });
}
