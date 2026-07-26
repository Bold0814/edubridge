import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/school_class.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/user_account.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/admin/school_students_hub_screen.dart';
import 'package:edubridge/screens/home_screen.dart';
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

  Future<void> seedSchool() async {
    await store.createSchool(
      id: 'sch-sel',
      name: 'Сонголт сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-sel',
      fullName: 'А. Админ',
      username: 'seladmin',
      password: 'test123',
    );
  }

  Future<String> createTeacherAccount(String username) async {
    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: 'sch-sel',
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
    return teacher.id;
  }

  Future<void> switchToTeacher(String username) async {
    final account = store.userByUsername(username)!;
    final membership = store
        .activeMembershipsForUser(account.id)
        .firstWhere((m) => m.role == AppRole.teacher);
    await store.selectDevelopmentUser(account, rememberMe: false);
    await store.selectSchoolMembership(membership);
  }

  test('homeroom and subject classes appear; unrelated excluded', () async {
    await seedSchool();
    final teacherId = await createTeacherAccount('t1');
    await store.addSchoolClass(name: 'T1А', homeroomTeacherId: teacherId);
    await store.addSchoolClass(name: 'T2А');
    await store.addSchoolClass(name: 'T3А');
    await store.addSubject('SelМат');
    await store.addSubject('SelФизик');
    final math = store.activeSubjects.firstWhere((s) => s.name == 'SelМат');
    final physics = store.activeSubjects.firstWhere(
      (s) => s.name == 'SelФизик',
    );
    await store.saveClassAssignments(
      classId: 'T2А',
      homeroomTeacherId: null,
      subjectTeacherIds: {math.id: teacherId, physics.id: teacherId},
    );
    await switchToTeacher('t1');

    final assigned = store.assignedClassesForActiveTeacher();
    expect(assigned.map((c) => c.className), ['T1А', 'T2А']);
    expect(assigned.any((c) => c.className == 'T3А'), isFalse);

    final home = assigned.firstWhere((c) => c.className == 'T1А');
    expect(home.isHomeroom, isTrue);
    expect(home.relationshipSubtitle, 'Анги удирдсан');

    final taught = assigned.firstWhere((c) => c.className == 'T2А');
    expect(taught.isHomeroom, isFalse);
    expect(taught.relationshipSubtitle, 'SelМат · SelФизик');
  });

  test('duplicate homeroom+subject appears once with combined label', () async {
    await seedSchool();
    final teacherId = await createTeacherAccount('t2');
    await store.addSchoolClass(name: 'D1А', homeroomTeacherId: teacherId);
    await store.addSubject('SelМонгол');
    await store.addSubject('SelУран');
    await store.addSubject('SelТүүх');
    final s1 = store.activeSubjects.firstWhere((s) => s.name == 'SelМонгол');
    final s2 = store.activeSubjects.firstWhere((s) => s.name == 'SelУран');
    final s3 = store.activeSubjects.firstWhere((s) => s.name == 'SelТүүх');
    await store.saveClassAssignments(
      classId: 'D1А',
      homeroomTeacherId: teacherId,
      subjectTeacherIds: {s1.id: teacherId, s2.id: teacherId, s3.id: teacherId},
    );
    await switchToTeacher('t2');

    final assigned = store.assignedClassesForActiveTeacher();
    expect(assigned, hasLength(1));
    expect(assigned.first.isHomeroom, isTrue);
    expect(assigned.first.subjects, hasLength(3));
    expect(
      assigned.first.relationshipSubtitle,
      'Анги удирдсан · SelМонгол, SelТүүх +1 хичээл',
    );
  });

  test('another school class is excluded', () async {
    await seedSchool();
    final teacherId = await createTeacherAccount('t3');
    await store.addSchoolClass(name: 'Local1А', homeroomTeacherId: teacherId);
    await store.createSchool(
      id: 'sch-other',
      name: 'Бусад',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.repository.insertSchoolClass(
      const SchoolClass(
        id: 'Other9А',
        name: 'Other9А',
        schoolId: 'sch-other',
        homeroomTeacherId: 'foreign-teacher',
      ),
    );
    await store.load();
    // Re-select teacher membership after reload.
    final account = store.userByUsername('t3')!;
    await store.selectDevelopmentUser(account, rememberMe: false);
    await store.selectSchoolMembership(
      store
          .activeMembershipsForUser(account.id)
          .firstWhere((m) => m.schoolId == 'sch-sel'),
    );

    final assigned = store.assignedClassesForActiveTeacher();
    expect(assigned.map((c) => c.className), ['Local1А']);
    expect(store.teacherCanAccessClass('Other9А'), isFalse);
  });

  test('selecting class with one subject auto-selects it', () async {
    await seedSchool();
    final teacherId = await createTeacherAccount('t4');
    await store.addSchoolClass(name: 'S1А');
    await store.addSubject('AutoМат');
    final math = store.activeSubjects.firstWhere((s) => s.name == 'AutoМат');
    await store.saveClassAssignments(
      classId: 'S1А',
      homeroomTeacherId: null,
      subjectTeacherIds: {math.id: teacherId},
    );
    await switchToTeacher('t4');

    final ok = await store.selectTeacherDashboardClass('S1А');
    expect(ok, isTrue);
    expect(store.activeContext.classId, 'S1А');
    expect(store.activeContext.subjectId, math.id);
  });

  test('stale subject cleared when switching to homeroom-only class', () async {
    await seedSchool();
    final teacherId = await createTeacherAccount('t5');
    await store.addSchoolClass(name: 'H1А', homeroomTeacherId: teacherId);
    await store.addSchoolClass(name: 'S2А');
    await store.addSubject('StaleМат');
    final math = store.activeSubjects.firstWhere((s) => s.name == 'StaleМат');
    await store.saveClassAssignments(
      classId: 'S2А',
      homeroomTeacherId: null,
      subjectTeacherIds: {math.id: teacherId},
    );
    await switchToTeacher('t5');

    await store.setTeacherWorkspace(classId: 'S2А', subjectId: math.id);
    expect(store.activeContext.subjectId, math.id);

    final ok = await store.selectTeacherDashboardClass('H1А');
    expect(ok, isTrue);
    expect(store.activeContext.classId, 'H1А');
    expect(store.activeContext.subjectId, isNull);
  });

  test(
    'multi-subject keeps valid preferred and rejects foreign subject',
    () async {
      await seedSchool();
      final teacherId = await createTeacherAccount('t6');
      await store.addSchoolClass(name: 'M1А');
      await store.addSubject('MМат');
      await store.addSubject('MФизик');
      final math = store.activeSubjects.firstWhere((s) => s.name == 'MМат');
      final physics = store.activeSubjects.firstWhere(
        (s) => s.name == 'MФизик',
      );
      await store.saveClassAssignments(
        classId: 'M1А',
        homeroomTeacherId: null,
        subjectTeacherIds: {math.id: teacherId, physics.id: teacherId},
      );
      await switchToTeacher('t6');

      await store.setTeacherWorkspace(classId: 'M1А', subjectId: math.id);
      final kept = await store.selectTeacherDashboardClass(
        'M1А',
        preferredSubjectId: math.id,
      );
      expect(kept, isTrue);
      expect(store.activeContext.subjectId, math.id);

      final cleared = await store.selectTeacherDashboardClass(
        'M1А',
        preferredSubjectId: 999999,
      );
      expect(cleared, isTrue);
      expect(store.activeContext.subjectId, isNull);
    },
  );

  test('teacher with no assignments sees empty list', () async {
    await seedSchool();
    await createTeacherAccount('t7');
    await store.addSchoolClass(name: 'X1А');
    await switchToTeacher('t7');
    expect(store.assignedClassesForActiveTeacher(), isEmpty);
    expect(store.teacherCanAccessClass('X1А'), isFalse);
  });

  test('direct access to unrelated class is denied', () async {
    await seedSchool();
    final teacherId = await createTeacherAccount('t8');
    await store.addSchoolClass(name: 'Ok1А', homeroomTeacherId: teacherId);
    await store.addSchoolClass(name: 'No1А');
    await switchToTeacher('t8');
    expect(await store.selectTeacherDashboardClass('No1А'), isFalse);
  });

  testWidgets('dashboard shows empty state when no assignments', (
    tester,
  ) async {
    await seedSchool();
    await createTeacherAccount('t9');
    await store.addSchoolClass(name: 'E1А');
    await switchToTeacher('t9');
    await store.setTeacherWorkspace(classId: 'E1А', subjectId: null);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(selectedClass: 'E1А', store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Танд хуваарилсан анги алга байна.'), findsOneWidget);
    expect(find.text('Энэ ангид хандах эрхгүй байна.'), findsNothing);
  });

  testWidgets('unrelated class shows access denied', (tester) async {
    await seedSchool();
    final teacherId = await createTeacherAccount('t10');
    await store.addSchoolClass(name: 'Ok2А', homeroomTeacherId: teacherId);
    await store.addSchoolClass(name: 'Bad2А');
    await switchToTeacher('t10');
    await store.setTeacherWorkspace(classId: 'Bad2А', subjectId: null);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(selectedClass: 'Bad2А', store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Энэ ангид хандах эрхгүй байна.'), findsOneWidget);
  });

  testWidgets('admin management still sees all school classes', (tester) async {
    await seedSchool();
    await store.addSchoolClass(name: 'A1А');
    await store.addSchoolClass(name: 'A2А');

    await tester.pumpWidget(
      MaterialApp(home: SchoolStudentsHubScreen(store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('A1А анги'), findsOneWidget);
    expect(find.text('A2А анги'), findsOneWidget);
  });

  testWidgets('admin opening teacher workspace sees only teacher classes', (
    tester,
  ) async {
    await seedSchool();
    // Admin has a teacherId from createFirstSchoolAdmin.
    final adminTeacherId = store.activeContext.teacherId!;
    await store.addSchoolClass(
      name: 'AdminHome',
      homeroomTeacherId: adminTeacherId,
    );
    await store.addSchoolClass(name: 'OtherOnly');

    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('AdminHome'), findsOneWidget);
    expect(find.textContaining('OtherOnly'), findsNothing);

    final assigned = store.assignedClassesForActiveTeacher();
    expect(assigned.map((c) => c.className), ['AdminHome']);
  });
}
