import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/school.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/auth/login_screen.dart';
import 'package:edubridge/screens/onboarding/create_school_screen.dart';
import 'package:edubridge/screens/onboarding/school_setup_screen.dart';
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
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('login screen shows school registration request action', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
    expect(find.text('Сургууль бүртгүүлэх хүсэлт'), findsOneWidget);
    expect(find.text('Шинэ сургууль үүсгэх'), findsNothing);
    expect(find.text('Нэвтрэх'), findsOneWidget);
  });

  testWidgets('public registration request does not open CreateSchoolScreen', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сургууль бүртгүүлэх хүсэлт'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateSchoolScreen), findsNothing);
    expect(find.text('Сургууль бүртгүүлэх хүсэлт'), findsWidgets);
    expect(
      find.textContaining('EduBridge-ийн зөвшөөрөл шаардлагатай'),
      findsOneWidget,
    );
    expect(find.text('Ойлголоо'), findsOneWidget);

    await tester.tap(find.text('Ойлголоо'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(CreateSchoolScreen), findsNothing);
  });

  testWidgets('debug mode may open test school creation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
    await tester.pumpAndSettle();

    // flutter_test runs with kDebugMode == true.
    expect(find.text('Туршилтын сургууль үүсгэх'), findsOneWidget);
    await tester.ensureVisible(find.text('Туршилтын сургууль үүсгэх'));
    await tester.tap(find.text('Туршилтын сургууль үүсгэх'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateSchoolScreen), findsOneWidget);
  });

  test('school name validation rejects whitespace', () async {
    expect(
      () => store.createSchool(
        id: 'sch-x',
        name: '   ',
        academicYear: SchoolSettings.currentAcademicYear(),
        currentSemester: SchoolSettings.semesterOptions.first,
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'EMPTY_SCHOOL_NAME',
        ),
      ),
    );
  });

  test('academic year rule by month', () {
    expect(
      SchoolSettings.currentAcademicYear(DateTime(2026, 1, 15)),
      '2025–2026',
    );
    expect(
      SchoolSettings.currentAcademicYear(DateTime(2026, 7, 31)),
      '2025–2026',
    );
    expect(
      SchoolSettings.currentAcademicYear(DateTime(2026, 8, 1)),
      '2026–2027',
    );
    expect(
      SchoolSettings.currentAcademicYear(DateTime(2026, 12, 31)),
      '2026–2027',
    );
  });

  test('simplified create school stores auto academic year', () async {
    final year = SchoolSettings.currentAcademicYear();
    await store.createSchool(
      id: 'sch-auto-year',
      name: 'Авто жил',
      academicYear: year,
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    final settings = await store.repository.loadSchoolSettings(
      schoolId: 'sch-auto-year',
    );
    expect(settings.academicYear, year);
    expect(settings.currentSemester, '1-р улирал');
    expect(settings.schoolName, 'Авто жил');
  });

  test('school creation and duplicate submit prevention', () async {
    final first = await store.createSchool(
      id: 'sch-new',
      name: 'Шинэ сургууль',
      code: 'S1',
      academicYear: '2025–2026',
      currentSemester: '1-р улирал',
    );
    final second = await store.createSchool(
      id: 'sch-new',
      name: 'Өөр нэр',
      academicYear: '2026–2027',
      currentSemester: '2-р улирал',
    );
    expect(first.id, second.id);
    expect(store.schools.where((s) => s.id == 'sch-new'), hasLength(1));
    expect(first.name, 'Шинэ сургууль');

    final settings = await store.repository.loadSchoolSettings(
      schoolId: 'sch-new',
    );
    expect(settings.schoolName, 'Шинэ сургууль');
    expect(settings.academicYear, '2025–2026');
  });

  test('first admin account creation and membership', () async {
    await store.createSchool(
      id: 'sch-admin',
      name: 'Админ сургууль',
      academicYear: '2025–2026',
      currentSemester: '1-р улирал',
    );

    final admin = await store.createFirstSchoolAdmin(
      schoolId: 'sch-admin',
      fullName: 'А. Админ',
      username: 'newadmin',
      password: 'secret123',
    );

    expect(admin.role, AppRole.admin);
    expect(
      PasswordHasher.verifyPassword('secret123', admin.passwordHash),
      isTrue,
    );
    expect(admin.passwordHash.contains('secret123'), isFalse);
    expect(store.activeSchoolId, 'sch-admin');
    expect(store.activeContext.role, AppRole.admin);

    final memberships = store.activeMembershipsForUser(admin.id);
    expect(memberships, hasLength(1));
    expect(memberships.first.schoolId, 'sch-admin');
    expect(memberships.first.role, AppRole.admin);
  });

  test('unique username validation for admin', () async {
    await store.ensureDemoAccountsIfNeeded();
    await store.createSchool(
      id: 'sch-dup',
      name: 'Давхардсан',
      academicYear: '2025–2026',
      currentSemester: '1-р улирал',
    );
    expect(
      () => store.createFirstSchoolAdmin(
        schoolId: 'sch-dup',
        fullName: 'X',
        username: 'teacher1',
        password: 'test123',
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'DUPLICATE_USERNAME',
        ),
      ),
    );
  });

  test('new school starts empty', () async {
    await store.createSchool(
      id: 'sch-empty',
      name: 'Хоосон',
      academicYear: '2025–2026',
      currentSemester: '1-р улирал',
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-empty',
      fullName: 'Э. Эхлэл',
      username: 'emptyadmin',
      password: 'test123',
    );

    // Admin staff teacher exists, but no classes/students yet.
    expect(store.classes, isEmpty);
    expect(store.allStudents, isEmpty);
    expect(store.isSchoolSetupIncomplete, isTrue);
  });

  test('created records use activeSchoolId', () async {
    await store.createSchool(
      id: 'sch-scoped',
      name: 'Scoped',
      academicYear: '2025–2026',
      currentSemester: '1-р улирал',
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-scoped',
      fullName: 'С. Скоп',
      username: 'scopedadmin',
      password: 'test123',
    );
    await store.addSchoolClass(name: '1А');
    expect(store.schoolClassesForActiveSchool.first.schoolId, 'sch-scoped');
    expect(
      store.activeTeachers.every((t) => t.schoolId == 'sch-scoped'),
      isTrue,
    );
  });

  test('existing teacher guardian student login still works', () async {
    await store.ensureDemoAccountsIfNeeded();
    expect(
      await store.login(
        username: 'teacher1',
        password: 'test123',
        rememberMe: false,
      ),
      LoginResult.success,
    );
    await store.logout();
    expect(
      await store.login(
        username: 'guardian1',
        password: 'test123',
        rememberMe: false,
      ),
      LoginResult.success,
    );
    await store.logout();
    expect(
      await store.login(
        username: 'student1',
        password: 'test123',
        rememberMe: false,
      ),
      LoginResult.success,
    );
  });

  test('admin1 demo account exists', () async {
    await store.ensureDemoAccountsIfNeeded();
    final admin = store.userByUsername('admin1');
    expect(admin, isNotNull);
    expect(admin!.role, AppRole.admin);
    expect(
      PasswordHasher.verifyPassword('test123', admin.passwordHash),
      isTrue,
    );
    final memberships = store.activeMembershipsForUser(admin.id);
    expect(
      memberships.any((m) => m.schoolId == AppStore.defaultSchoolId),
      isTrue,
    );
  });

  test('admin sees only selected-school data', () async {
    await store.ensureDemoAccountsIfNeeded();
    await store.addSchool(const School(id: 'sch-other', name: 'Бусад'));
    await store.repository.insertSchoolSettings(
      SchoolSettings.emptyFor('sch-other').copyWith(schoolName: 'Бусад'),
    );
    await store.addSchoolClass(name: 'X1А', schoolId: 'sch-other');

    final result = await store.login(
      username: 'admin1',
      password: 'test123',
      rememberMe: false,
    );
    expect(result, LoginResult.success);
    final resolve = await store.resolveSchoolEntry(preferLastSchool: false);
    await store.selectSchoolMembership(resolve.membership!);

    expect(store.classes, isNot(contains('X1А')));
    expect(store.activeSchoolId, AppStore.defaultSchoolId);
  });

  test('one-school skip logic remains valid', () async {
    await store.ensureDemoAccountsIfNeeded();
    await store.login(
      username: 'admin1',
      password: 'test123',
      rememberMe: false,
    );
    final result = await store.resolveSchoolEntry(preferLastSchool: false);
    expect(result.kind, SchoolResolveKind.single);
  });

  test('database migration preserves school settings', () async {
    final migrated = await DatabaseService.instance.openInMemoryUpgradingFrom(
      7,
    );
    addTearDown(migrated.close);
    final rows = await migrated.query(
      'school_settings',
      where: 'school_id = ?',
      whereArgs: [DatabaseService.defaultSchoolId],
    );
    expect(rows, isNotEmpty);
    final schools = await migrated.query('schools');
    expect(
      schools.any((r) => r['id'] == DatabaseService.defaultSchoolId),
      isTrue,
    );
  });

  testWidgets('create school screen validates empty name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CreateSchoolScreen(store: store)),
    );
    expect(find.text('Сургуулийн нэр'), findsOneWidget);
    expect(find.text('Сургуулийн код'), findsNothing);
    expect(find.textContaining('Хаяг'), findsNothing);
    expect(find.text('Хичээлийн жил'), findsNothing);
    expect(find.text('Одоогийн улирал'), findsNothing);
    await tester.tap(find.text('Сургууль үүсгэх'));
    await tester.pump();
    expect(find.text('Сургуулийн нэрээ оруулна уу'), findsOneWidget);
  });

  testWidgets('admin setup screen opens after first admin', (tester) async {
    await store.createSchool(
      id: 'sch-ui',
      name: 'UI сургууль',
      academicYear: '2025–2026',
      currentSemester: '1-р улирал',
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-ui',
      fullName: 'У. Админ',
      username: 'uiadmin',
      password: 'test123',
    );

    await tester.pumpWidget(MaterialApp(home: SchoolSetupScreen(store: store)));
    await tester.pump();
    expect(find.byType(SchoolSetupScreen), findsOneWidget);
    expect(find.text('Сургуулийн бэлтгэл'), findsWidgets);
    expect(find.text('Ажлын хэсэг рүү орох'), findsOneWidget);
    expect(find.text('Багш бүртгэх'), findsOneWidget);
    expect(find.text('Анги үүсгэх'), findsOneWidget);
    expect(find.text('Хичээл үүсгэх'), findsOneWidget);
    expect(find.text('Багш, ангийг оноох'), findsOneWidget);
    expect(find.text('Хичээлийн хуваарь оруулах'), findsOneWidget);
    expect(find.text('Асран хамгаалагчид'), findsNothing);
  });
}
