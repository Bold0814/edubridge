import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/guardian.dart';
import 'package:edubridge/models/guardian_student.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/user_account.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/password_hasher.dart';
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

  Future<Teacher> seedTeacher() async {
    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: AppStore.defaultSchoolId,
      fullName: 'Д.Эрдэнэ',
    );
    await store.addTeacher(teacher);
    return teacher;
  }

  Future<Student> seedStudent({
    String id = '6А-9001',
    String className = '6А',
    String last = 'Бат',
    String first = 'Болд',
  }) async {
    final student = Student(
      id: id,
      className: className,
      lastName: last,
      firstName: first,
      gender: StudentGender.male,
    );
    await store.addStudent(student);
    return student;
  }

  test('unique username validation', () async {
    final teacher = await seedTeacher();
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

    expect(
      () => store.addUserAccount(
        UserAccount(
          id: store.nextUserId(),
          username: 'teacher1',
          passwordHash: '',
          role: AppRole.teacher,
          teacherId: teacher.id,
          createdAt: DateTime.now(),
        ),
        plainPassword: 'test123',
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

  test('role and linked entity matching', () async {
    final teacher = await seedTeacher();
    final student = await seedStudent();

    expect(
      () => store.addUserAccount(
        UserAccount(
          id: store.nextUserId(),
          username: 'bad',
          passwordHash: '',
          role: AppRole.teacher,
          studentId: student.id,
          createdAt: DateTime.now(),
        ),
        plainPassword: 'x',
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'MISSING_LINK',
        ),
      ),
    );

    await store.addUserAccount(
      UserAccount(
        id: store.nextUserId(),
        username: 'ok_teacher',
        passwordHash: '',
        role: AppRole.teacher,
        teacherId: teacher.id,
        createdAt: DateTime.now(),
      ),
      plainPassword: 'secret',
    );
    expect(store.userByUsername('ok_teacher')?.teacherId, teacher.id);
  });

  test(
    'guardian with multiple students and student with multiple guardians',
    () async {
      final s1 = await seedStudent(id: '6А-1', first: 'Батболд');
      final s2 = await seedStudent(id: '6А-2', first: 'Номин');

      final g1 = Guardian(
        id: store.nextGuardianId(),
        schoolId: AppStore.defaultSchoolId,
        fullName: 'Б. Болормаа',
      );
      final g2 = Guardian(
        id: store.nextGuardianId(),
        schoolId: AppStore.defaultSchoolId,
        fullName: 'Д. Бат',
      );
      await store.addGuardian(g1);
      await store.addGuardian(g2);

      await store.saveGuardianStudentLinks(
        guardianId: g1.id,
        links: [
          GuardianStudent(
            guardianId: g1.id,
            studentId: s1.id,
            relationship: 'Ээж',
          ),
          GuardianStudent(
            guardianId: g1.id,
            studentId: s2.id,
            relationship: 'Ээж',
          ),
        ],
      );
      await store.saveGuardianStudentLinks(
        guardianId: g2.id,
        links: [
          GuardianStudent(
            guardianId: g2.id,
            studentId: s1.id,
            relationship: 'Аав',
          ),
        ],
      );

      expect(store.studentsForGuardian(g1.id), hasLength(2));
      expect(store.guardiansForStudent(s1.id), hasLength(2));
    },
  );

  test('inactive account filtering', () async {
    final teacher = await seedTeacher();
    final user = UserAccount(
      id: store.nextUserId(),
      username: 'inactive1',
      passwordHash: '',
      role: AppRole.teacher,
      teacherId: teacher.id,
      createdAt: DateTime.now(),
    );
    await store.addUserAccount(user, plainPassword: 'x');
    await store.deactivateUserAccount(user.id);

    expect(
      store.activeUserAccounts.any((u) => u.username == 'inactive1'),
      isFalse,
    );
    expect(
      store.activeUsersForRole(AppRole.teacher).any((u) => u.id == user.id),
      isFalse,
    );
  });

  test('password hash verification', () {
    final stored = PasswordHasher.hashPassword('test123');
    expect(PasswordHasher.verifyPassword('test123', stored), isTrue);
    expect(PasswordHasher.verifyPassword('wrong', stored), isFalse);
    expect(stored.contains(':'), isTrue);
    expect(stored, isNot(contains('test123')));
  });

  test('development role navigation helpers', () async {
    final teacher = await seedTeacher();
    final account = UserAccount(
      id: store.nextUserId(),
      username: 'dev_teacher',
      passwordHash: '',
      role: AppRole.teacher,
      teacherId: teacher.id,
      createdAt: DateTime.now(),
    );
    await store.addUserAccount(account, plainPassword: 'test123');
    await store.selectDevelopmentUser(store.userByUsername('dev_teacher')!);

    expect(store.selectedDevelopmentRole, AppRole.teacher);
    expect(store.selectedDevelopmentUser?.username, 'dev_teacher');
    expect(
      store.teacherForUser(store.selectedDevelopmentUser!.id)?.fullName,
      'Д.Эрдэнэ',
    );
  });

  test('SQLite migration preserves existing data for user accounts', () async {
    final upgraded = await DatabaseService.instance.openInMemoryUpgradingFrom(
      3,
    );
    addTearDown(upgraded.close);
    final repo = EduBridgeRepository(upgraded);

    final classes = await repo.loadClasses();
    expect(classes, contains('6А'));

    await repo.insertGuardian(
      const Guardian(
        id: 'g-mig',
        schoolId: AppStore.defaultSchoolId,
        fullName: 'Ш.Шинэ',
      ),
    );
    final guardians = await repo.loadGuardians();
    expect(guardians.any((g) => g.id == 'g-mig'), isTrue);

    await repo.insertUserAccount(
      UserAccount(
        id: 'u-mig',
        username: 'mig_user',
        passwordHash: PasswordHasher.hashPassword('x'),
        role: AppRole.guardian,
        guardianId: 'g-mig',
        createdAt: DateTime.now(),
      ),
    );
    expect(await repo.findUserByUsername('mig_user'), isNotNull);
  });

  test('demo accounts seed once and appear for role picker', () async {
    expect(store.activeUserAccounts, isEmpty);
    await store.ensureDemoAccountsIfNeeded();

    expect(store.userByUsername('teacher1')?.role, AppRole.teacher);
    expect(store.userByUsername('guardian1')?.role, AppRole.guardian);
    expect(store.userByUsername('student1')?.role, AppRole.student);
    expect(store.teacherById(AppStore.demoTeacherId), isNotNull);
    expect(store.guardianById(AppStore.demoGuardianId), isNotNull);
    expect(store.studentById(AppStore.demoStudentId), isNotNull);
    expect(store.studentsForGuardian(AppStore.demoGuardianId), isNotEmpty);

    final before = store.activeUserAccounts.length;
    await store.ensureDemoAccountsIfNeeded();
    expect(store.activeUserAccounts, hasLength(before));
    expect(
      store.activeUserAccounts.where((u) => u.username == 'teacher1'),
      hasLength(1),
    );
  });
}
