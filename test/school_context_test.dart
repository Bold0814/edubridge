import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/school.dart';
import 'package:edubridge/models/school_class.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/user_account.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/services/database_service.dart';
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

  Future<UserAccount> seedTeacherUser({
    required String username,
    required String teacherId,
    required String schoolId,
  }) async {
    await store.addTeacher(
      Teacher(id: teacherId, schoolId: schoolId, fullName: 'Багш $username'),
    );
    final user = UserAccount(
      id: store.nextUserId(),
      username: username,
      passwordHash: '',
      role: AppRole.teacher,
      teacherId: teacherId,
      createdAt: DateTime.now(),
    );
    await store.addUserAccount(user, plainPassword: 'test123');
    // Membership is created for _effectiveSchoolId; replace if needed.
    final created = store.userByUsername(username)!;
    final memberships = store.activeMembershipsForUser(created.id);
    if (memberships.isNotEmpty && memberships.first.schoolId != schoolId) {
      await store.addMembership(
        UserSchoolMembership(
          id: store.nextMembershipId(),
          userId: created.id,
          schoolId: schoolId,
          role: AppRole.teacher,
          teacherId: teacherId,
        ),
      );
    }
    return store.userByUsername(username)!;
  }

  test('one school skips school selection', () async {
    final user = await seedTeacherUser(
      username: 'one_school',
      teacherId: store.nextTeacherId(),
      schoolId: AppStore.defaultSchoolId,
    );
    await store.selectDevelopmentUser(user);
    final result = await store.resolveSchoolEntry();
    expect(result.kind, SchoolResolveKind.single);
    await store.selectSchoolMembership(result.membership!);
    expect(store.activeSchoolId, AppStore.defaultSchoolId);
  });

  test('multiple schools show school selection unless last is valid', () async {
    await store.addSchool(
      const School(id: 'sch-b', name: 'Хоёрдугаар сургууль'),
    );
    final teacherId = store.nextTeacherId();
    await store.addTeacher(
      Teacher(
        id: teacherId,
        schoolId: AppStore.defaultSchoolId,
        fullName: 'Хоёр сургууль',
      ),
    );
    final user = UserAccount(
      id: store.nextUserId(),
      username: 'multi_school',
      passwordHash: '',
      role: AppRole.teacher,
      teacherId: teacherId,
      createdAt: DateTime.now(),
    );
    await store.addUserAccount(user, plainPassword: 'test123');
    final created = store.userByUsername('multi_school')!;
    await store.addMembership(
      UserSchoolMembership(
        id: store.nextMembershipId(),
        userId: created.id,
        schoolId: 'sch-b',
        role: AppRole.teacher,
        teacherId: teacherId,
      ),
    );

    await store.selectDevelopmentUser(created);
    // No last school → multiple
    await store.repository.setPref('last_school_id', '');
    var result = await store.resolveSchoolEntry();
    expect(result.kind, SchoolResolveKind.multiple);

    // Valid last school → single (auto)
    await store.selectSchoolMembership(
      store
          .activeMembershipsForUser(created.id)
          .firstWhere((m) => m.schoolId == 'sch-b'),
    );
    result = await store.resolveSchoolEntry();
    expect(result.kind, SchoolResolveKind.single);
    expect(result.membership?.schoolId, 'sch-b');
  });

  test('invalid or inactive saved school is ignored', () async {
    final user = await seedTeacherUser(
      username: 'invalid_last',
      teacherId: store.nextTeacherId(),
      schoolId: AppStore.defaultSchoolId,
    );
    await store.selectDevelopmentUser(user);
    await store.repository.setPref('last_school_id', 'sch-missing');
    final result = await store.resolveSchoolEntry();
    expect(result.kind, SchoolResolveKind.single);
    expect(result.membership?.schoolId, AppStore.defaultSchoolId);
  });

  test('teacher sees only selected-school classes', () async {
    await store.addSchool(const School(id: 'sch-b', name: 'B'));
    await store.repository.insertSchoolClass(
      const SchoolClass(id: 'B8А', name: 'B8А', schoolId: 'sch-b'),
    );
    await store.load();

    final teacherId = store.nextTeacherId();
    await store.addTeacher(
      Teacher(
        id: teacherId,
        schoolId: AppStore.defaultSchoolId,
        fullName: 'Анги шүүлт',
      ),
    );
    final user = UserAccount(
      id: store.nextUserId(),
      username: 'filter_teacher',
      passwordHash: '',
      role: AppRole.teacher,
      teacherId: teacherId,
      createdAt: DateTime.now(),
    );
    await store.addUserAccount(user, plainPassword: 'x');
    final created = store.userByUsername('filter_teacher')!;
    await store.selectDevelopmentUser(created);
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(created.id).first,
    );

    expect(store.classes, isNot(contains('B8А')));
    expect(store.classes, contains('6А'));
  });

  test('switching school clears class subject and child context', () async {
    await store.addSchool(const School(id: 'sch-b', name: 'B'));
    final teacherId = store.nextTeacherId();
    await store.addTeacher(
      Teacher(
        id: teacherId,
        schoolId: AppStore.defaultSchoolId,
        fullName: 'Солих',
      ),
    );
    final user = UserAccount(
      id: store.nextUserId(),
      username: 'switch_school',
      passwordHash: '',
      role: AppRole.teacher,
      teacherId: teacherId,
      createdAt: DateTime.now(),
    );
    await store.addUserAccount(user, plainPassword: 'x');
    final created = store.userByUsername('switch_school')!;
    await store.addMembership(
      UserSchoolMembership(
        id: store.nextMembershipId(),
        userId: created.id,
        schoolId: 'sch-b',
        role: AppRole.teacher,
        teacherId: teacherId,
      ),
    );
    await store.selectDevelopmentUser(created);
    await store.selectSchoolMembership(
      store
          .activeMembershipsForUser(created.id)
          .firstWhere((m) => m.schoolId == AppStore.defaultSchoolId),
    );
    await store.setTeacherWorkspace(classId: '6А', subjectId: 1);
    await store.setGuardianStudentId('child-x');

    await store.switchSchool('sch-b');
    expect(store.activeSchoolId, 'sch-b');
    expect(store.activeContext.classId, isNull);
    expect(store.activeContext.subjectId, isNull);
    expect(store.activeContext.selectedChildId, isNull);
  });

  test('guardian sees only selected-school children', () async {
    await store.addSchool(const School(id: 'sch-b', name: 'B'));
    await store.repository.insertSchoolClass(
      const SchoolClass(id: 'B9А', name: 'B9А', schoolId: 'sch-b'),
    );
    await store.load();

    await store.addStudent(
      const Student(
        id: 'other-child',
        className: 'B9А',
        lastName: 'Бусад',
        firstName: 'Хүүхэд',
        gender: StudentGender.male,
      ),
    );
    await store.ensureDemoAccountsIfNeeded();
    final demoUser = store.userByUsername(AppStore.demoGuardianUsername);
    expect(demoUser, isNotNull);
    await store.selectDevelopmentUser(demoUser!);
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(demoUser.id).first,
    );
    final ids = store.guardianPortalStudents.map((s) => s.id).toSet();
    expect(ids, isNot(contains('other-child')));
  });

  test('existing database migrates to default school', () async {
    // Upgrade from v3 legacy path through current version (includes v9).
    final upgraded = await DatabaseService.instance.openInMemoryUpgradingFrom(
      3,
    );
    final schools = await upgraded.query('schools');
    expect(schools, isNotEmpty);
    expect(schools.first['id'], AppStore.defaultSchoolId);

    final classRows = await upgraded.query('classes');
    expect(classRows, isNotEmpty);
    for (final row in classRows) {
      expect(row['school_id'], AppStore.defaultSchoolId);
    }
    await upgraded.close();
  });
}
