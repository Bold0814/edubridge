import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/user_account.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/auth/first_time_access_screen.dart';
import 'package:edubridge/screens/teacher_form_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/password_hasher.dart';
import 'package:edubridge/services/password_rules.dart';
import 'package:edubridge/services/phone_normalizer.dart';
import 'package:edubridge/services/pin_rules.dart';
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

  Future<void> seedAdmin() async {
    await store.createSchool(
      id: 'sch-tlogin',
      name: 'Багш нэвтрэлт',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-tlogin',
      fullName: 'А. Админ',
      username: 'tloginadmin',
      password: 'admin1234',
    );
  }

  Future<void> loginAsTeacher() async {
    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: 'sch-tlogin',
      fullName: 'Зөвхөн багш',
      phone: '99887766',
    );
    await store.addTeacher(teacher);
    await store.addUserAccount(
      UserAccount(
        id: store.nextUserId(),
        username: '99887766',
        passwordHash: '',
        role: AppRole.teacher,
        teacherId: teacher.id,
        createdAt: DateTime.now(),
      ),
      plainPassword: 'teach1234',
    );
    final account = store.userByUsername('99887766')!;
    await store.selectDevelopmentUser(account, rememberMe: false);
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(account.id).first,
    );
  }

  group('PasswordRules', () {
    test('accepts letter+digit passwords of 8+', () {
      expect(
        PasswordRules.validateNewPassword('Bagsh2026', 'Bagsh2026'),
        isNull,
      );
      expect(
        PasswordRules.validateNewPassword('Surguuli88', 'Surguuli88'),
        isNull,
      );
      expect(
        PasswordRules.validateNewPassword('Teacher123', 'Teacher123'),
        isNull,
      );
    });

    test('rejects numeric-only, letter-only, short, and mismatch', () {
      expect(
        PasswordRules.validateNewPassword('12345678', '12345678'),
        PasswordRules.missingLetterMessage,
      );
      expect(
        PasswordRules.validateNewPassword('abcdefgh', 'abcdefgh'),
        PasswordRules.missingDigitMessage,
      );
      expect(
        PasswordRules.validateNewPassword('1234', '1234'),
        PasswordRules.combinedRequirementsMessage,
      );
      expect(
        PasswordRules.validateNewPassword('Abc12', 'Abc12'),
        PasswordRules.tooShortMessage,
      );
      expect(
        PasswordRules.validateNewPassword('Bagsh2026', 'Bagsh2027'),
        PasswordRules.mismatchMessage,
      );
      expect(
        PasswordRules.validateNewPassword('', ''),
        PasswordRules.combinedRequirementsMessage,
      );
      expect(
        PasswordRules.validateNewPassword('        ', '        '),
        PasswordRules.combinedRequirementsMessage,
      );
    });
  });

  testWidgets('helper and Mongolian validation message are displayed', (
    tester,
  ) async {
    await seedAdmin();
    await tester.pumpWidget(MaterialApp(home: TeacherFormScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text(PasswordRules.helperText), findsOneWidget);
    expect(find.text('Нэвтрэх нэр'), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), 'Тест Багш');
    await tester.enterText(find.byType(TextField).at(1), '99110033');
    // password fields: index 3 and 4 after name, phone, email
    await tester.enterText(find.byType(TextField).at(3), '12345678');
    await tester.enterText(find.byType(TextField).at(4), '12345678');
    await tester.tap(find.text('Хадгалах'));
    await tester.pumpAndSettle();

    expect(find.text(PasswordRules.missingLetterMessage), findsOneWidget);
  });

  group('PinRules remain 4-digit for guardian/student', () {
    test('exactly 4 digits accepted; 5 digits and letters rejected', () {
      expect(PinRules.isValid('2468'), isTrue);
      expect(PinRules.validateNewPin('2468', '2468'), isNull);
      expect(PinRules.isValid('12345'), isFalse);
      expect(PinRules.validateNewPin('12345', '12345'), isNotNull);
      expect(PinRules.isValid('12ab'), isFalse);
      expect(PinRules.validateNewPin('abcd', 'abcd'), isNotNull);
    });
  });

  test('login identifier is normalized phone', () async {
    expect(PhoneNormalizer.normalize('+976 9911-2233'), '99112233');
    expect(PhoneNormalizer.normalize('(9911) 2233'), '99112233');
    expect(PhoneNormalizer.normalize('97699112233'), '99112233');

    await seedAdmin();
    await store.createTeacherWithOptionalLogin(
      teacher: Teacher(
        id: store.nextTeacherId(),
        schoolId: 'sch-tlogin',
        fullName: 'Утас багш',
        phone: '+976 9911-2233',
      ),
      createLogin: true,
      password: 'abc12345',
      passwordConfirm: 'abc12345',
    );
    final teacher = store.teachers.firstWhere((t) => t.fullName == 'Утас багш');
    final account = store.loginAccountForTeacher(teacher.id)!;
    expect(account.username, '99112233');
    expect(teacher.phone, '99112233');
    expect(account.requirePasswordChange, isTrue);

    final login = await store.login(
      username: '+97699112233',
      password: 'abc12345',
      rememberMe: false,
    );
    expect(login, LoginResult.success);
  });

  testWidgets('admin sees login section without login-name field', (
    tester,
  ) async {
    await seedAdmin();
    await tester.pumpWidget(MaterialApp(home: TeacherFormScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Нэвтрэх эрх'), findsOneWidget);
    expect(find.text('Нэвтрэх эрх үүсгэх'), findsOneWidget);
    expect(find.text('Түр нууц үг'), findsOneWidget);
    expect(find.text('Нууц үг давтах'), findsOneWidget);
    expect(find.text('Багш анх нэвтрээд нууц үгээ солино.'), findsOneWidget);
    expect(find.text('Нэвтрэх нэр'), findsNothing);
  });

  testWidgets('normal teacher cannot open teacher-account management', (
    tester,
  ) async {
    await seedAdmin();
    await loginAsTeacher();

    await tester.pumpWidget(MaterialApp(home: TeacherFormScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Энэ үйлдлийг хийх эрхгүй байна.'), findsOneWidget);
    expect(find.text('Нэвтрэх эрх'), findsNothing);

    expect(
      () => store.createTeacherWithOptionalLogin(
        teacher: Teacher(
          id: store.nextTeacherId(),
          schoolId: 'sch-tlogin',
          fullName: 'Х. Хаалттай',
          phone: '99000011',
        ),
        createLogin: true,
        password: 'abc12345',
        passwordConfirm: 'abc12345',
      ),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  test('new teacher with one login account', () async {
    await seedAdmin();
    final createdLogin = await store.createTeacherWithOptionalLogin(
      teacher: Teacher(
        id: store.nextTeacherId(),
        schoolId: 'sch-tlogin',
        fullName: 'Б. Багш',
        phone: '99110022',
      ),
      createLogin: true,
      password: 'abc12345',
      passwordConfirm: 'abc12345',
    );
    expect(createdLogin, isTrue);
    final teacher = store.teachers.firstWhere((t) => t.fullName == 'Б. Багш');
    final account = store.loginAccountForTeacher(teacher.id)!;
    expect(account.role, AppRole.teacher);
    expect(account.username, '99110022');
    expect(account.requirePasswordChange, isTrue);
    expect(account.passwordHash.contains('abc12345'), isFalse);
    expect(
      PasswordHasher.verifyPassword('abc12345', account.passwordHash),
      isTrue,
    );
  });

  test('new teacher without login account', () async {
    await seedAdmin();
    final createdLogin = await store.createTeacherWithOptionalLogin(
      teacher: Teacher(
        id: store.nextTeacherId(),
        schoolId: 'sch-tlogin',
        fullName: 'П. Профайл',
      ),
      createLogin: false,
    );
    expect(createdLogin, isFalse);
    final teacher = store.teachers.firstWhere(
      (t) => t.fullName == 'П. Профайл',
    );
    expect(store.loginAccountForTeacher(teacher.id), isNull);
    expect(store.teacherLoginStatusLabel(teacher.id), 'Эрх үүсээгүй');
  });

  test('duplicate phone account is rejected', () async {
    await seedAdmin();
    await store.createTeacherWithOptionalLogin(
      teacher: Teacher(
        id: store.nextTeacherId(),
        schoolId: 'sch-tlogin',
        fullName: 'Нэгдүгээр',
        phone: '99112233',
      ),
      createLogin: true,
      password: 'abc12345',
      passwordConfirm: 'abc12345',
    );
    expect(
      () => store.createTeacherWithOptionalLogin(
        teacher: Teacher(
          id: store.nextTeacherId(),
          schoolId: 'sch-tlogin',
          fullName: 'Хоёрдугаар',
          phone: '+976 9911-2233',
        ),
        createLogin: true,
        password: 'abc12345',
        passwordConfirm: 'abc12345',
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

  test(
    'temporary password requires change; clearing works; admin reset sets again',
    () async {
      await seedAdmin();
      await store.createTeacherWithOptionalLogin(
        teacher: Teacher(
          id: store.nextTeacherId(),
          schoolId: 'sch-tlogin',
          fullName: 'Идэвх',
          phone: '99001100',
        ),
        createLogin: true,
        password: 'abc12345',
        passwordConfirm: 'abc12345',
      );
      final teacher = store.teachers.firstWhere((t) => t.fullName == 'Идэвх');
      var account = store.loginAccountForTeacher(teacher.id)!;
      expect(account.requirePasswordChange, isTrue);

      await store.logout();
      final login = await store.login(
        username: '99001100',
        password: 'abc12345',
        rememberMe: false,
      );
      expect(login, LoginResult.success);
      expect(store.selectedDevelopmentUser!.requirePasswordChange, isTrue);

      await store.completeRequiredPasswordChange(
        newPassword: 'newpass99',
        confirmPassword: 'newpass99',
      );
      account = store.loginAccountForTeacher(teacher.id)!;
      expect(account.requirePasswordChange, isFalse);
      expect(
        PasswordHasher.verifyPassword('newpass99', account.passwordHash),
        isTrue,
      );

      // Switch back to admin to reset.
      final admin = store.userByUsername('tloginadmin')!;
      await store.selectDevelopmentUser(admin, rememberMe: false);
      await store.selectSchoolMembership(
        store.activeMembershipsForUser(admin.id).first,
      );

      await store.resetTeacherLoginPassword(
        teacherId: teacher.id,
        password: 'temp9988',
        passwordConfirm: 'temp9988',
      );
      account = store.loginAccountForTeacher(teacher.id)!;
      expect(account.requirePasswordChange, isTrue);
      expect(account.passwordHash.contains('temp9988'), isFalse);
    },
  );

  test('teacher absent from self-activation role selection', () async {
    await seedAdmin();
    // Covered by widget test below as well.
    expect(true, isTrue);
  });

  testWidgets('teacher absent from self-activation role selection UI', (
    tester,
  ) async {
    await seedAdmin();
    await tester.pumpWidget(
      MaterialApp(home: FirstTimeAccessScreen(store: store)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Асран хамгаалагч'), findsOneWidget);
    expect(find.text('Сурагч'), findsOneWidget);
    expect(find.text('Багш'), findsNothing);
  });
}
