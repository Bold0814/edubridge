import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/password_hasher.dart';
import 'package:edubridge/services/phone_normalizer.dart';
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

  Future<void> seedAdmin() async {
    await store.createSchool(
      id: 'sch-phone',
      name: 'Утас sync',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-phone',
      fullName: 'А. Админ',
      username: 'phoneadmin',
      password: 'Admin2026',
    );
  }

  group('PhoneNormalizer canonical format', () {
    test('+976 and local formats normalize consistently', () {
      expect(PhoneNormalizer.normalize('85406262'), '85406262');
      expect(PhoneNormalizer.normalize('85 406 262'), '85406262');
      expect(PhoneNormalizer.normalize('+97685406262'), '85406262');
      expect(PhoneNormalizer.normalize('976-8540-6262'), '85406262');
      expect(PhoneNormalizer.normalize('(85) 406-262'), '85406262');
    });
  });

  group('teacher phone / login sync', () {
    test(
      'profile phone update changes linked loginIdentifier and preserves auth',
      () async {
        await seedAdmin();
        final adminId = store.authenticatedUser!.id;
        await store.createTeacherWithOptionalLogin(
          teacher: Teacher(
            id: store.nextTeacherId(),
            schoolId: 'sch-phone',
            fullName: 'У. Багш',
            phone: '88888888',
          ),
          createLogin: true,
          password: 'Teach2026',
          passwordConfirm: 'Teach2026',
        );
        final teacher = store.teachers.firstWhere(
          (t) => t.fullName == 'У. Багш',
        );
        final before = store.loginAccountForTeacher(teacher.id)!;
        final hashBefore = before.passwordHash;
        final membershipsBefore = store
            .activeMembershipsForUser(before.id)
            .map((m) => m.id)
            .toList();
        expect(before.username, '88888888');
        expect(before.requirePasswordChange, isTrue);

        await store.updateTeacher(
          teacher.copyWith(phone: '+976 85 406 262'),
          allowDuplicate: true,
        );

        final updatedTeacher = store.teacherById(teacher.id)!;
        final account = store.loginAccountForTeacher(teacher.id)!;
        expect(updatedTeacher.phone, '85406262');
        expect(account.username, '85406262');
        expect(account.id, before.id);
        expect(account.teacherId, teacher.id);
        expect(account.passwordHash, hashBefore);
        expect(account.requirePasswordChange, isTrue);
        expect(account.isActive, isTrue);
        expect(
          store.activeMembershipsForUser(account.id).map((m) => m.id),
          membershipsBefore,
        );
        expect(store.userByUsername('phoneadmin')!.id, adminId);
        expect(store.userByUsername('phoneadmin')!.username, 'phoneadmin');

        expect(store.findAccountByLoginPhone('88888888'), isNull);
        expect(store.findAccountByLoginPhone('85406262')?.id, account.id);

        await store.logout();
        expect(
          await store.login(
            username: '88888888',
            password: 'Teach2026',
            rememberMe: false,
          ),
          LoginResult.invalidCredentials,
        );
        expect(
          await store.login(
            username: '+97685406262',
            password: 'Teach2026',
            rememberMe: false,
          ),
          LoginResult.success,
        );
        expect(
          PasswordHasher.verifyPassword(
            'Teach2026',
            store.authenticatedUser!.passwordHash,
          ),
          isTrue,
        );
      },
    );

    test(
      'duplicate normalized phone is rejected without partial update',
      () async {
        await seedAdmin();
        await store.createTeacherWithOptionalLogin(
          teacher: Teacher(
            id: store.nextTeacherId(),
            schoolId: 'sch-phone',
            fullName: 'Нэгдүгээр',
            phone: '88888888',
          ),
          createLogin: true,
          password: 'Teach2026',
          passwordConfirm: 'Teach2026',
        );
        await store.createTeacherWithOptionalLogin(
          teacher: Teacher(
            id: store.nextTeacherId(),
            schoolId: 'sch-phone',
            fullName: 'Хоёрдугаар',
            phone: '85406262',
          ),
          createLogin: true,
          password: 'Teach2026',
          passwordConfirm: 'Teach2026',
        );
        final first = store.teachers.firstWhere(
          (t) => t.fullName == 'Нэгдүгээр',
        );
        final firstAccount = store.loginAccountForTeacher(first.id)!;
        final hashBefore = firstAccount.passwordHash;

        expect(
          () => store.updateTeacher(
            first.copyWith(phone: '85 406 262'),
            allowDuplicate: true,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              'DUPLICATE_PHONE',
            ),
          ),
        );

        expect(store.teacherById(first.id)!.phone, '88888888');
        expect(store.loginAccountForTeacher(first.id)!.username, '88888888');
        expect(
          store.loginAccountForTeacher(first.id)!.passwordHash,
          hashBefore,
        );
      },
    );

    test('editing teacher without account updates profile only', () async {
      await seedAdmin();
      await store.createTeacherWithOptionalLogin(
        teacher: Teacher(
          id: store.nextTeacherId(),
          schoolId: 'sch-phone',
          fullName: 'Профайл',
          phone: '88888888',
        ),
        createLogin: false,
      );
      final teacher = store.teachers.firstWhere((t) => t.fullName == 'Профайл');
      final accountsBefore = store.userAccounts.length;

      await store.updateTeacher(
        teacher.copyWith(phone: '85406262'),
        allowDuplicate: true,
      );

      expect(store.teacherById(teacher.id)!.phone, '85406262');
      expect(store.loginAccountForTeacher(teacher.id), isNull);
      expect(store.teacherLoginStatusLabel(teacher.id), 'Эрх үүсээгүй');
      expect(store.userAccounts.length, accountsBefore);
      expect(store.findAccountByLoginPhone('85406262'), isNull);
    });

    test('saving twice does not create duplicate accounts', () async {
      await seedAdmin();
      await store.createTeacherWithOptionalLogin(
        teacher: Teacher(
          id: store.nextTeacherId(),
          schoolId: 'sch-phone',
          fullName: 'Давхар',
          phone: '88888888',
        ),
        createLogin: true,
        password: 'Teach2026',
        passwordConfirm: 'Teach2026',
      );
      final teacher = store.teachers.firstWhere((t) => t.fullName == 'Давхар');
      final accountId = store.loginAccountForTeacher(teacher.id)!.id;
      final countBefore = store.userAccounts
          .where((u) => u.teacherId == teacher.id && u.role == AppRole.teacher)
          .length;

      await store.updateTeacher(
        teacher.copyWith(phone: '85406262'),
        allowDuplicate: true,
      );
      await store.updateTeacher(
        store.teacherById(teacher.id)!.copyWith(phone: '85406262'),
        allowDuplicate: true,
      );

      final teacherAccounts = store.userAccounts
          .where((u) => u.teacherId == teacher.id && u.role == AppRole.teacher)
          .toList();
      expect(teacherAccounts.length, countBefore);
      expect(teacherAccounts.single.id, accountId);
      expect(teacherAccounts.single.username, '85406262');
    });

    test('same teacher phone is not treated as duplicate of itself', () async {
      await seedAdmin();
      await store.createTeacherWithOptionalLogin(
        teacher: Teacher(
          id: store.nextTeacherId(),
          schoolId: 'sch-phone',
          fullName: 'Өөрөө',
          phone: '88888888',
        ),
        createLogin: true,
        password: 'Teach2026',
        passwordConfirm: 'Teach2026',
      );
      final teacher = store.teachers.firstWhere((t) => t.fullName == 'Өөрөө');
      await store.updateTeacher(
        teacher.copyWith(fullName: 'Өөрөө Шинэ', phone: '88888888'),
        allowDuplicate: true,
      );
      expect(store.loginAccountForTeacher(teacher.id)!.username, '88888888');
      expect(store.teacherById(teacher.id)!.fullName, 'Өөрөө Шинэ');
    });
  });
}
