import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/user_account.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/password_hasher.dart';
import 'package:edubridge/services/password_rules.dart';
import 'package:edubridge/services/pin_rules.dart';
import 'package:edubridge/state/app_store.dart';
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

  /// Leaves the admin signed in so structure-management APIs work.
  Future<UserAccount> seedAdmin({
    String username = 'admin',
    String password = '12345678',
  }) async {
    await store.createSchool(
      id: 'sch-legacy',
      name: 'Legacy сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    // Seed without PasswordRules so legacy weak stored passwords can be tested.
    final admin = await store.createFirstSchoolAdmin(
      schoolId: 'sch-legacy',
      fullName: 'А. Админ',
      username: username,
      password: 'AdminSeed9',
    );
    final withLegacy = admin.copyWith(
      passwordHash: PasswordHasher.hashPassword(password),
      requirePasswordChange: false,
    );
    await store.updateUserAccount(withLegacy);
    return store.userByUsername(username)!;
  }

  group('PasswordHasher formats', () {
    test('current salt:hash verifies and does not need rehash', () {
      final stored = PasswordHasher.hashPassword('Admin2026');
      expect(PasswordHasher.verifyPassword('Admin2026', stored), isTrue);
      expect(PasswordHasher.verifyPassword('wrong', stored), isFalse);
      expect(PasswordHasher.needsRehash(stored), isFalse);
    });

    test('legacy unsalted sha256 hex verifies and needs rehash', () {
      final legacy = sha256.convert(utf8.encode('12345678')).toString();
      expect(PasswordHasher.verifyPassword('12345678', legacy), isTrue);
      expect(PasswordHasher.verifyPassword('87654321', legacy), isFalse);
      expect(PasswordHasher.needsRehash(legacy), isTrue);
    });
  });

  group('PasswordRules only for create/reset', () {
    test('rejects numeric-only 12345678; accepts Admin2026', () {
      expect(
        PasswordRules.validateNewPassword('12345678', '12345678'),
        PasswordRules.missingLetterMessage,
      );
      expect(
        PasswordRules.validateNewPassword('Admin2026', 'Admin2026'),
        isNull,
      );
    });

    test(
      'login does not apply PasswordRules to legacy weak password',
      () async {
        await seedAdmin(password: '12345678');
        // Strength rules would reject this string for *new* passwords.
        expect(
          PasswordRules.validateNewPassword('12345678', '12345678'),
          isNotNull,
        );

        await store.logout();
        final result = await store.login(
          username: 'admin',
          password: '12345678',
          rememberMe: false,
        );
        expect(result, LoginResult.success);
        expect(store.authenticatedUser?.username, 'admin');
        expect(store.authenticatedUser?.role, AppRole.admin);
      },
    );
  });

  group('legacy admin login', () {
    test('numeric legacy password logs in when stored hash verifies', () async {
      await seedAdmin(password: '12345678');
      final account = store.userByUsername('admin')!;
      expect(account.isActive, isTrue);
      expect(account.passwordHash, isNotEmpty);
      expect(
        PasswordHasher.verifyPassword('12345678', account.passwordHash),
        isTrue,
      );
      expect(store.activeMembershipsForUser(account.id), isNotEmpty);
      expect(
        store.activeMembershipsForUser(account.id).first.role,
        AppRole.admin,
      );

      await store.logout();
      final result = await store.login(
        username: 'admin',
        password: '12345678',
        rememberMe: false,
      );
      expect(result, LoginResult.success);
    });

    test('wrong admin password fails with password wording', () async {
      await seedAdmin(password: '12345678');
      await store.logout();
      final result = await store.login(
        username: 'admin',
        password: 'wrongpass',
        rememberMe: false,
      );
      expect(result, LoginResult.invalidCredentials);
      expect(result.message, 'Нэвтрэх нэр эсвэл нууц үг буруу байна.');
      expect(result.message.contains('PIN'), isFalse);
    });

    test('successful legacy verification migrates hash safely', () async {
      await seedAdmin(password: 'AdminSeed9');
      final admin = store.userByUsername('admin')!;
      final legacy = sha256.convert(utf8.encode('12345678')).toString();
      await store.updateUserAccount(admin.copyWith(passwordHash: legacy));
      await store.logout();

      final result = await store.login(
        username: 'admin',
        password: '12345678',
        rememberMe: false,
      );
      expect(result, LoginResult.success);
      final migrated = store.userByUsername('admin')!;
      expect(migrated.passwordHash.contains(':'), isTrue);
      expect(PasswordHasher.needsRehash(migrated.passwordHash), isFalse);
      expect(
        PasswordHasher.verifyPassword('12345678', migrated.passwordHash),
        isTrue,
      );
      expect(migrated.passwordHash.contains('12345678'), isFalse);
    });
  });

  group('admin vs teacher account separation', () {
    test(
      'teacher password reset does not overwrite admin linked by teacherId',
      () async {
        final admin = await seedAdmin(password: '12345678');
        final adminHashBefore = admin.passwordHash;
        final teacherId = admin.teacherId!;

        expect(store.loginAccountForTeacher(teacherId), isNull);
        expect(store.adminAccountForTeacher(teacherId)?.username, 'admin');
        expect(
          store.teacherLoginStatusLabel(teacherId),
          'Админ эрхээр нэвтэрнэ',
        );

        expect(
          () => store.resetTeacherLoginPassword(
            teacherId: teacherId,
            password: 'TempPass9',
            passwordConfirm: 'TempPass9',
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              'NOT_FOUND',
            ),
          ),
        );

        // Create a separate teacher-role login for the same profile.
        final teacher = store.teacherById(teacherId)!;
        await store.updateTeacher(
          teacher.copyWith(phone: '99118877'),
          allowDuplicate: true,
        );
        await store.createLoginForExistingTeacher(
          teacherId: teacherId,
          password: 'Teach2026',
          passwordConfirm: 'Teach2026',
        );

        final teacherAccount = store.loginAccountForTeacher(teacherId)!;
        expect(teacherAccount.role, AppRole.teacher);
        expect(teacherAccount.id, isNot(admin.id));
        expect(teacherAccount.username, '99118877');

        final adminAfter = store.userByUsername('admin')!;
        expect(adminAfter.passwordHash, adminHashBefore);
        expect(
          PasswordHasher.verifyPassword('12345678', adminAfter.passwordHash),
          isTrue,
        );

        await store.logout();
        expect(
          await store.login(
            username: 'admin',
            password: '12345678',
            rememberMe: false,
          ),
          LoginResult.success,
        );
        await store.logout();
        expect(
          await store.login(
            username: '99118877',
            password: 'Teach2026',
            rememberMe: false,
          ),
          LoginResult.success,
        );
        expect(store.authenticatedUser?.role, AppRole.teacher);
        expect(store.authenticatedUser?.requirePasswordChange, isTrue);
      },
    );

    test('teacher temporary password login succeeds', () async {
      await seedAdmin();
      await store.createTeacherWithOptionalLogin(
        teacher: Teacher(
          id: store.nextTeacherId(),
          schoolId: 'sch-legacy',
          fullName: 'Шинэ багш',
          phone: '99002211',
        ),
        createLogin: true,
        password: 'Bagsh2026',
        passwordConfirm: 'Bagsh2026',
      );
      await store.logout();
      final result = await store.login(
        username: '99002211',
        password: 'Bagsh2026',
        rememberMe: false,
      );
      expect(result, LoginResult.success);
      expect(store.authenticatedUser?.role, AppRole.teacher);
      expect(store.authenticatedUser?.requirePasswordChange, isTrue);
    });
  });

  group('credential type isolation', () {
    test('PasswordRules never used for PIN validation', () {
      expect(PinRules.isValid('2468'), isTrue);
      expect(PinRules.validateNewPin('2468', '2468'), isNull);
      // PIN would fail password strength if wrongly routed.
      expect(PasswordRules.validateNewPassword('2468', '2468'), isNotNull);
    });

    test('guardian/student wrong PIN uses learner message', () async {
      await store.ensureDemoAccountsIfNeeded();
      // Demo guardian uses password-style demo secret, still role=guardian.
      final result = await store.login(
        username: 'guardian1',
        password: '0000',
        rememberMe: false,
      );
      expect(result, LoginResult.invalidLearnerCredentials);
      expect(result.message, 'Нэвтрэх мэдээлэл буруу байна.');
    });

    test('guardian/student PIN login remains unaffected', () async {
      await store.ensureDemoAccountsIfNeeded();
      final result = await store.login(
        username: 'guardian1',
        password: 'test123',
        rememberMe: false,
      );
      expect(result, LoginResult.success);
      expect(store.authenticatedUser?.role, AppRole.guardian);
    });
  });
}
