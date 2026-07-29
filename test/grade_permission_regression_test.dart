import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/bulk_grade_entry_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/firestore_grade_repository.dart';
import 'package:edubridge/services/grade_write_authorization.dart';
import 'package:edubridge/services/sqlite_grade_repository.dart';
import 'package:edubridge/services/synced_grade_repository.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

class _DenyCloudStore extends MemoryGradeDocumentStore {
  @override
  Future<void> set(
    String path,
    Map<String, Object?> data, {
    bool merge = false,
  }) async {
    if (path.startsWith('${Grade.collection}/')) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );
    }
    await super.set(path, data, merge: merge);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;
  late Teacher bold;
  late Teacher otherTeacher;
  late Student student;
  late Student secondStudent;
  late int mathId;
  const schoolId = 'sch-grade-perm';
  const classId = '12a';
  const firebaseUid = 'firebase-bold-uid';

  Future<void> seed({
    GradeDocumentStore? cloudStore,
    bool useSynced = false,
  }) async {
    database = await DatabaseService.instance.openInMemoryForTest();
    final repo = EduBridgeRepository(database);
    final mirror = SqliteGradeRepository(repo);
    final memory = cloudStore ?? MemoryGradeDocumentStore();
    final primary = FirestoreGradeRepository(store: memory);
    store = AppStore(
      repo,
      gradeRepository: useSynced
          ? SyncedGradeRepository(primary: primary, mirror: mirror)
          : primary,
    );
    await store.load();

    await store.createSchool(
      id: schoolId,
      name: 'Grade Perm School',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: schoolId,
      fullName: 'Admin',
      username: 'gpadmin',
      password: 'test123',
    );

    await store.addSchoolClass(name: classId);
    await store.addSubject('Math');
    mathId = store.subjectByName('Math')!.id;

    bold = Teacher(
      id: store.nextTeacherId(),
      schoolId: schoolId,
      fullName: 'Bold',
      phone: '99001234',
      authUid: firebaseUid,
    );
    await store.createTeacherWithOptionalLogin(
      teacher: bold,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );

    otherTeacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: schoolId,
      fullName: 'Other',
      phone: '99009999',
    );
    await store.createTeacherWithOptionalLogin(
      teacher: otherTeacher,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );

    await store.saveClassAssignments(
      classId: classId,
      homeroomTeacherId: bold.id,
      subjectTeacherIds: {mathId: bold.id},
    );

    student = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId(classId),
        className: classId,
        lastName: 'Сүх',
        firstName: 'Ану',
        gender: StudentGender.female,
      ),
      guardianFullName: 'Ээж',
      guardianPhone: '88001122',
      relationship: 'Ээж',
    );
    secondStudent = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId(classId),
        className: classId,
        lastName: 'Бат',
        firstName: 'Болормаа',
        gender: StudentGender.female,
      ),
      guardianFullName: 'Аав',
      guardianPhone: '88001123',
      relationship: 'Аав',
    );

    await store.logout();
    await store.login(
      username: '99001234',
      password: 'Teach2026',
      rememberMe: false,
    );
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(store.authenticatedUser!.id).first,
    );
  }

  tearDown(() async {
    await database.close();
  });

  test('assigned Bold teacher can save one Math grade for 12a', () async {
    await seed();

    final permission = store.canTeacherManageGrades(
      classId: classId,
      subjectId: mathId,
    );
    expect(permission.allowed, isTrue);

    final saved = await store.saveGrade(
      Grade(
        id: store.nextGradeId(),
        className: classId,
        studentId: student.id,
        studentName: student.fullName,
        subject: 'Math',
        subjectId: mathId,
        score: '91',
        term: '1-р улирал',
        termId: '1-р улирал',
      ),
      isUpdate: false,
    );

    expect(saved.score, '91');
    expect(saved.teacherId, bold.id);
    expect(saved.teacherId, isNot(firebaseUid));
    expect(saved.className, classId);
    expect(saved.subjectId, mathId);
  });

  test('assigned Bold teacher can bulk-save Math grades for 12a', () async {
    await seed();

    await store.addGrades([
      Grade(
        id: store.nextGradeId(),
        className: classId,
        studentId: student.id,
        studentName: student.fullName,
        subject: 'Math',
        subjectId: mathId,
        score: '80',
        term: '1-р улирал',
        termId: '1-р улирал',
      ),
      Grade(
        id: store.nextGradeId(),
        className: classId,
        studentId: secondStudent.id,
        studentName: secondStudent.fullName,
        subject: 'Math',
        subjectId: mathId,
        score: '85',
        term: '1-р улирал',
        termId: '1-р улирал',
      ),
    ]);

    expect(store.gradesForStudent(student), hasLength(1));
    expect(store.gradesForStudent(secondStudent), hasLength(1));
  });

  testWidgets('bulk button enables after a score changes', (tester) async {
    await seed();

    await tester.pumpWidget(
      MaterialApp(
        home: BulkGradeEntryScreen(
          selectedClass: classId,
          store: store,
          initialSubject: 'Math',
          initialTerm: '1-р улирал',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'Бүх дүнг хадгалах');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    await tester.enterText(find.byType(TextFormField).first, '77');
    await tester.pump();

    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
  });

  test('existing grade can be updated', () async {
    await seed();

    final created = await store.saveGrade(
      Grade(
        id: store.nextGradeId(),
        className: classId,
        studentId: student.id,
        studentName: student.fullName,
        subject: 'Math',
        subjectId: mathId,
        score: '70',
        term: '1-р улирал',
        termId: '1-р улирал',
      ),
      isUpdate: false,
    );

    final updated = await store.saveGrade(
      created.copyWith(score: '95'),
      isUpdate: true,
    );
    expect(updated.id, created.id);
    expect(updated.score, '95');
    expect(updated.letterGrade, 'A+');
  });

  test('admin can save', () async {
    await seed();
    await store.logout();
    await store.login(
      username: 'gpadmin',
      password: 'test123',
      rememberMe: false,
    );
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(store.authenticatedUser!.id).first,
    );

    expect(
      store.canTeacherManageGrades(classId: classId, subjectId: mathId).allowed,
      isTrue,
    );

    final saved = await store.saveGrade(
      Grade(
        id: store.nextGradeId(),
        className: classId,
        studentId: student.id,
        studentName: student.fullName,
        subject: 'Math',
        subjectId: mathId,
        score: '88',
        term: '1-р улирал',
        termId: '1-р улирал',
      ),
      isUpdate: false,
    );
    expect(saved.score, '88');
  });

  test('unassigned teacher is denied', () async {
    await seed();
    await store.logout();
    await store.login(
      username: '99009999',
      password: 'Teach2026',
      rememberMe: false,
    );
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(store.authenticatedUser!.id).first,
    );

    final permission = store.canTeacherManageGrades(
      classId: classId,
      subjectId: mathId,
    );
    expect(permission.allowed, isFalse);
    expect(
      permission.denialReason,
      GradePermissionResult.assignmentMissing,
    );

    await expectLater(
      store.saveGrade(
        Grade(
          id: store.nextGradeId(),
          className: classId,
          studentId: student.id,
          studentName: student.fullName,
          subject: 'Math',
          subjectId: mathId,
          score: '60',
          term: '1-р улирал',
          termId: '1-р улирал',
        ),
        isUpdate: false,
      ),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  test('teacher document ID and Firebase uid are not incorrectly compared',
      () async {
    await seed();

    expect(bold.id, isNot(firebaseUid));
    expect(store.teacherIdForClassSubject(classId, mathId), bold.id);
    expect(store.teacherIdForClassSubject(classId, mathId), isNot(firebaseUid));

    final prepared = store.prepareGradeForSave(
      Grade(
        id: 'gr-id-check',
        className: classId,
        studentId: student.id,
        studentName: student.fullName,
        subject: 'Math',
        subjectId: mathId,
        teacherId: firebaseUid,
        score: '81',
        term: '1-р улирал',
      ),
      isCreate: true,
    );
    expect(prepared.teacherId, bold.id);
    expect(prepared.teacherId, isNot(firebaseUid));

    final auth = const GradeWriteAuthorization();
    expect(
      auth.canCreateGrade(
        authUid: firebaseUid,
        schoolId: schoolId,
        classId: classId,
        subjectId: mathId,
        gradeTeacherId: firebaseUid,
        teacherDoc: null,
        assignmentDoc: null,
        membershipRole: 'teacher',
        membershipActive: true,
        membershipSchoolId: schoolId,
      ),
      isFalse,
    );
  });

  test('all grade screens return the same permission result', () async {
    await seed();

    final shared = store.canTeacherManageGrades(
      classId: classId,
      subjectId: mathId,
    );
    expect(shared.allowed, isTrue);
    expect(
      store.teacherCanEditClassSubject(classId: classId, subjectId: mathId),
      shared.allowed,
    );
    expect(
      store.teacherCanEditSubjectNamed(classId: classId, subjectName: 'Math'),
      shared.allowed,
    );

    await store.logout();
    await store.login(
      username: '99009999',
      password: 'Teach2026',
      rememberMe: false,
    );
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(store.authenticatedUser!.id).first,
    );

    final denied = store.canTeacherManageGrades(
      classId: classId,
      subjectId: mathId,
    );
    expect(denied.allowed, isFalse);
    expect(
      store.teacherCanEditClassSubject(classId: classId, subjectId: mathId),
      denied.allowed,
    );
    expect(
      store.teacherCanEditSubjectNamed(classId: classId, subjectName: 'Math'),
      denied.allowed,
    );
  });

  test('synced repository falls back to local when Firestore denies', () async {
    await seed(cloudStore: _DenyCloudStore(), useSynced: true);

    final saved = await store.saveGrade(
      Grade(
        id: store.nextGradeId(),
        className: classId,
        studentId: student.id,
        studentName: student.fullName,
        subject: 'Math',
        subjectId: mathId,
        score: '73',
        term: '1-р улирал',
        termId: '1-р улирал',
      ),
      isUpdate: false,
    );

    expect(saved.score, '73');
    expect(store.gradesForStudent(student), hasLength(1));
  });
}
