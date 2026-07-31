import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/firestore_identity_repository.dart';
import 'package:edubridge/services/teacher_authorization_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

/// End-to-end role-flow regression for the four EduBridge personas.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late MemoryIdentityDocumentStore identityStore;
  late AppStore store;
  const schoolId = 'sch-role-flow';
  const classId = 'RF7А';
  const subjectName = 'RFМатематик';

  Future<void> loginTeacher(String phone) async {
    try {
      await store.logout();
    } catch (_) {}
    final result = await store.login(
      username: phone,
      password: 'Teach2026',
      rememberMe: false,
    );
    expect(result, LoginResult.success);
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(store.authenticatedUser!.id).first,
    );
  }

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    identityStore = MemoryIdentityDocumentStore();
    store = AppStore(
      EduBridgeRepository(database),
      firestoreIdentity: FirestoreIdentityRepository(store: identityStore),
      cloudAuthProvisionOverride: (request) async {
        final email = request.internalEmail;
        if (email.contains('99110001')) return 'uid-teacher-a';
        if (email.contains('99110002')) return 'uid-teacher-b';
        if (email.contains('88001111')) return 'uid-guardian-a';
        if (email.contains('88002222')) return 'uid-guardian-b';
        return 'uid-${request.role.wireValue}-${request.internalEmail.hashCode.abs()}';
      },
    );
    await store.load();
  });

  tearDown(() async {
    await database.close();
  });

  test('admin creates school/class/teacher/student with authUid', () async {
    await store.createSchool(
      id: schoolId,
      name: 'Role Flow School',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    final admin = await store.createFirstSchoolAdmin(
      schoolId: schoolId,
      fullName: 'Admin',
      username: 'rfadmin',
      password: 'Admin2026',
    );
    expect(admin.authUid, isNotNull);
    expect(admin.authUid, isNotEmpty);

    await store.addSchoolClass(gradeLevel: 7, section: 'А');
    final createdClass = store.schoolClasses.singleWhere(
      (c) => c.schoolId == schoolId && c.gradeLevel == 7,
    );
    final resolvedClassId = createdClass.id;
    expect(createdClass.schoolId, schoolId);
    expect(createdClass.section, isNotNull);

    expect(
      () => store.addSchoolClass(gradeLevel: 7, section: 'А'),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => store.addSchoolClass(gradeLevel: 13, section: 'А'),
      throwsA(isA<ArgumentError>()),
    );

    await store.addSubject(subjectName);
    final mathId = store.subjectByName(subjectName)!.id;
    expect(store.subjectById(mathId)!.schoolId, schoolId);

    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: schoolId,
      fullName: 'Багш А',
      phone: '99110001',
    );
    await store.createTeacherWithOptionalLogin(
      teacher: teacher,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );
    expect(store.teacherById(teacher.id)!.authUid, 'uid-teacher-a');
    expect(store.loginAccountForTeacher(teacher.id)!.authUid, 'uid-teacher-a');

    await store.saveClassAssignments(
      classId: resolvedClassId,
      homeroomTeacherId: teacher.id,
      subjectTeacherIds: {mathId: teacher.id},
    );
    expect(store.teacherIdForClassSubject(resolvedClassId, mathId), teacher.id);

    final student = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId(resolvedClassId),
        className: resolvedClassId,
        lastName: 'Бат',
        firstName: 'Болд',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Ээж',
      guardianPhone: '88001111',
      relationship: 'Ээж',
    );
    final studentAccount = store.accountForStudentId(student.id)!;
    final guardian = store.guardiansForStudent(student.id).first;
    final guardianAccount = store.accountForGuardianId(guardian.id)!;
    // Learners receive authUid on PIN activation (not at create).
    expect(studentAccount.authUid, isNull);
    expect(guardianAccount.authUid, isNull);
    expect(guardian.schoolId, schoolId);

    await store.activateAccountWithPin(userId: studentAccount.id, pin: '2468');
    await store.activateAccountWithPin(userId: guardianAccount.id, pin: '1357');
    expect(store.accountForStudentId(student.id)!.authUid, isNotNull);
    expect(store.accountForGuardianId(guardian.id)!.authUid, isNotNull);
  });

  test(
    'assigned teacher creates/edits own grade; cannot edit other teacher',
    () async {
      await store.createSchool(
        id: schoolId,
        name: 'Role Flow School',
        academicYear: SchoolSettings.currentAcademicYear(),
        currentSemester: SchoolSettings.semesterOptions.first,
      );
      await store.createFirstSchoolAdmin(
        schoolId: schoolId,
        fullName: 'Admin',
        username: 'rfadmin2',
        password: 'Admin2026',
      );
      await store.addSchoolClass(name: classId);
      await store.addSubject(subjectName);
      final mathId = store.subjectByName(subjectName)!.id;

      final teacherA = Teacher(
        id: store.nextTeacherId(),
        schoolId: schoolId,
        fullName: 'Багш А',
        phone: '99110001',
      );
      final teacherB = Teacher(
        id: store.nextTeacherId(),
        schoolId: schoolId,
        fullName: 'Багш Б',
        phone: '99110002',
      );
      await store.createTeacherWithOptionalLogin(
        teacher: teacherA,
        createLogin: true,
        password: 'Teach2026',
        passwordConfirm: 'Teach2026',
      );
      await store.createTeacherWithOptionalLogin(
        teacher: teacherB,
        createLogin: true,
        password: 'Teach2026',
        passwordConfirm: 'Teach2026',
      );
      await store.saveClassAssignments(
        classId: classId,
        homeroomTeacherId: teacherA.id,
        subjectTeacherIds: {mathId: teacherA.id},
      );

      final student = await store.addStudentWithRequiredGuardian(
        student: Student(
          id: store.nextStudentId(classId),
          className: classId,
          lastName: 'Дорж',
          firstName: 'Батаа',
          gender: StudentGender.male,
        ),
        guardianFullName: 'Аав',
        guardianPhone: '88001111',
        relationship: 'Аав',
      );

      await loginTeacher('99110001');
      await store.setTeacherWorkspace(classId: classId, subjectId: mathId);

      final created = await store.saveGrade(
        Grade(
          id: store.nextGradeId(),
          className: classId,
          studentId: student.id,
          studentName: student.fullName,
          subject: subjectName,
          subjectId: mathId,
          score: '88',
          term: SchoolSettings.semesterOptions.first,
          schoolId: schoolId,
        ),
        isUpdate: false,
      );
      expect(created.createdByUid, 'uid-teacher-a');
      expect(created.teacherId, teacherA.id);
      expect(created.schoolId, schoolId);
      expect(created.subjectId, mathId);

      final edited = await store.saveGrade(
        created.copyWith(score: '91'),
        isUpdate: true,
      );
      expect(edited.score, '91');
      expect(edited.createdByUid, 'uid-teacher-a');

      // Foreign grade owned by teacher B (same subject assignment temporarily).
      final foreign = Grade(
        id: store.nextGradeId(),
        className: classId,
        studentId: student.id,
        studentName: student.fullName,
        subject: subjectName,
        subjectId: mathId,
        score: '70',
        term: SchoolSettings.semesterOptions.first,
        schoolId: schoolId,
        teacherId: teacherB.id,
        createdByUid: 'uid-teacher-b',
      );
      await store.repository.insertGrade(foreign);
      await store.load();
      await loginTeacher('99110001');
      await store.selectSchoolMembership(
        store.activeMembershipsForUser(store.authenticatedUser!.id).first,
      );
      await store.setTeacherWorkspace(classId: classId, subjectId: mathId);

      final foreignLoaded = store
          .gradesForStudent(student)
          .firstWhere((g) => g.id == foreign.id);
      expect(store.canEditGradeRecord(foreignLoaded), isFalse);
      expect(
        () => store.saveGrade(
          foreignLoaded.copyWith(score: '99'),
          isUpdate: true,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    },
  );

  test(
    'student sees own grades only; guardian sees linked child only',
    () async {
      await store.createSchool(
        id: schoolId,
        name: 'Role Flow School',
        academicYear: SchoolSettings.currentAcademicYear(),
        currentSemester: SchoolSettings.semesterOptions.first,
      );
      await store.createFirstSchoolAdmin(
        schoolId: schoolId,
        fullName: 'Admin',
        username: 'rfadmin3',
        password: 'Admin2026',
      );
      await store.addSchoolClass(name: classId);
      await store.addSubject(subjectName);
      final mathId = store.subjectByName(subjectName)!.id;

      final teacher = Teacher(
        id: store.nextTeacherId(),
        schoolId: schoolId,
        fullName: 'Багш А',
        phone: '99110001',
      );
      await store.createTeacherWithOptionalLogin(
        teacher: teacher,
        createLogin: true,
        password: 'Teach2026',
        passwordConfirm: 'Teach2026',
      );
      await store.saveClassAssignments(
        classId: classId,
        homeroomTeacherId: teacher.id,
        subjectTeacherIds: {mathId: teacher.id},
      );

      final studentA = await store.addStudentWithRequiredGuardian(
        student: Student(
          id: store.nextStudentId(classId),
          className: classId,
          lastName: 'Амар',
          firstName: 'Ану',
          gender: StudentGender.female,
        ),
        guardianFullName: 'Ээж А',
        guardianPhone: '88001111',
        relationship: 'Ээж',
      );
      final studentB = await store.addStudentWithRequiredGuardian(
        student: Student(
          id: store.nextStudentId(classId),
          className: classId,
          lastName: 'Болор',
          firstName: 'Билгүүн',
          gender: StudentGender.male,
        ),
        guardianFullName: 'Ээж Б',
        guardianPhone: '88002222',
        relationship: 'Ээж',
      );

      await loginTeacher('99110001');
      await store.setTeacherWorkspace(classId: classId, subjectId: mathId);
      await store.saveGrade(
        Grade(
          id: store.nextGradeId(),
          className: classId,
          studentId: studentA.id,
          studentName: studentA.fullName,
          subject: subjectName,
          subjectId: mathId,
          score: '95',
          term: SchoolSettings.semesterOptions.first,
          schoolId: schoolId,
        ),
        isUpdate: false,
      );
      await store.saveGrade(
        Grade(
          id: store.nextGradeId(),
          className: classId,
          studentId: studentB.id,
          studentName: studentB.fullName,
          subject: subjectName,
          subjectId: mathId,
          score: '80',
          term: SchoolSettings.semesterOptions.first,
          schoolId: schoolId,
        ),
        isUpdate: false,
      );

      // Student A session — only own learner access.
      final studentAccount = store.accountForStudentId(studentA.id)!;
      await store.selectDevelopmentUser(studentAccount);
      await store.selectSchoolMembership(
        store.activeMembershipsForUser(studentAccount.id).first,
      );
      expect(store.canViewLearnerStudent(studentA.id), isTrue);
      expect(store.canViewLearnerStudent(studentB.id), isFalse);
      final ownGrades = store.gradesForStudent(studentA);
      expect(ownGrades.every((g) => g.studentId == studentA.id), isTrue);
      expect(ownGrades.any((g) => g.studentId == studentB.id), isFalse);

      // Guardian A — linked child only.
      final guardianA = store.guardiansForStudent(studentA.id).first;
      final guardianAccount = store.accountForGuardianId(guardianA.id)!;
      await store.selectDevelopmentUser(guardianAccount);
      await store.selectSchoolMembership(
        store.activeMembershipsForUser(guardianAccount.id).first,
      );
      await store.setGuardianStudentId(studentA.id);
      expect(store.canViewLearnerStudent(studentA.id), isTrue);
      expect(store.canViewLearnerStudent(studentB.id), isFalse);
      expect(
        store.guardianPortalStudents.map((s) => s.id),
        contains(studentA.id),
      );
      expect(
        store.guardianPortalStudents.map((s) => s.id),
        isNot(contains(studentB.id)),
      );
    },
  );

  test('admin-stamped grade remains editable by assigned teacherId owner', () {
    final auth = TeacherAuthorizationService(
      authUid: 'uid-teacher-a',
      teacherDocId: 'tch-a',
      schoolId: schoolId,
      isAdmin: false,
      isHomeroomOf: (_) => false,
      isAssignedTo: (c, s) => c == classId && s == 10,
      teachesInClass: (c) => c == classId,
    );
    const ownership = RecordOwnership(
      schoolId: schoolId,
      classId: classId,
      subjectId: 10,
      createdByUid: 'uid-admin',
      createdByTeacherId: 'tch-a',
    );
    expect(
      auth.canEditRecord(kind: TeacherRecordKind.grade, ownership: ownership),
      isTrue,
    );
    expect(
      auth.canEditRecord(
        kind: TeacherRecordKind.grade,
        ownership: const RecordOwnership(
          schoolId: schoolId,
          classId: classId,
          subjectId: 10,
          createdByUid: 'uid-teacher-b',
          createdByTeacherId: 'tch-b',
        ),
      ),
      isFalse,
    );
  });
}
