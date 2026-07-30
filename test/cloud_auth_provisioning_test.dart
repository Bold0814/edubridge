import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/firestore_identity_repository.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late MemoryIdentityDocumentStore identityStore;
  late AppStore store;
  const schoolId = 'sch-auth';
  const classId = '10a';
  var provisionCount = 0;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    identityStore = MemoryIdentityDocumentStore();
    provisionCount = 0;
    store = AppStore(
      EduBridgeRepository(database),
      firestoreIdentity: FirestoreIdentityRepository(store: identityStore),
      cloudAuthProvisionOverride: (request) async {
        provisionCount += 1;
        return 'uid-${request.role.wireValue}-$provisionCount';
      },
    );
    await store.load();
    await store.createSchool(
      id: schoolId,
      name: 'Auth School',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: schoolId,
      fullName: 'Admin',
      username: 'authadmin',
      password: 'Admin2026',
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('teacher login create stores authUid on account and teacher', () async {
    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: schoolId,
      fullName: 'Saraa',
      phone: '99112233',
    );
    await store.createTeacherWithOptionalLogin(
      teacher: teacher,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );

    final account = store.loginAccountForTeacher(teacher.id)!;
    expect(account.authUid, isNotNull);
    expect(account.authUid, startsWith('uid-teacher-'));
    expect(store.teacherById(teacher.id)!.authUid, account.authUid);

    final profilePath =
        'users/${account.authUid}';
    expect(identityStore.documents.containsKey(profilePath), isTrue);
  });

  test('student+guardian create stores authUid before PIN activation', () async {
    await store.addSchoolClass(name: classId);
    final student = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId(classId),
        className: classId,
        lastName: 'Бат',
        firstName: 'Болд',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Ээж',
      guardianPhone: '88001122',
      relationship: 'Ээж',
    );

    final studentAccount = store.accountForStudentId(student.id)!;
    expect(studentAccount.authUid, isNotNull);
    expect(studentAccount.authUid, isNotEmpty);

    final guardian = store.guardiansForStudent(student.id).first;
    final guardianAccount = store.accountForGuardianId(guardian.id)!;
    expect(guardianAccount.authUid, isNotNull);
    expect(guardianAccount.authUid, isNotEmpty);
  });

  test('teacher login links authUid for ownership', () async {
    await store.addSchoolClass(name: classId);
    await store.addSubject('Math');
    final mathId = store.subjectByName('Math')!.id;

    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: schoolId,
      fullName: 'Bold',
      phone: '99001122',
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

    final student = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId(classId),
        className: classId,
        lastName: 'Дорж',
        firstName: 'Батаа',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Аав',
      guardianPhone: '88003344',
      relationship: 'Аав',
    );

    await store.logout();
    await store.login(
      username: '99001122',
      password: 'Teach2026',
      rememberMe: false,
    );
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(store.authenticatedUser!.id).first,
    );
    await store.setTeacherWorkspace(classId: classId, subjectId: mathId);

    expect(store.authenticatedUser?.authUid, isNotNull);
    expect(store.teacherAuthorization.authUid, isNotNull);
    expect(
      store.teacherAuthorization.authUid,
      store.authenticatedUser!.authUid,
    );

    final saved = await store.saveGrade(
      Grade(
        id: store.nextGradeId(),
        className: classId,
        studentId: student.id,
        studentName: student.fullName,
        subject: 'Math',
        subjectId: mathId,
        score: '90',
        term: SchoolSettings.semesterOptions.first,
        schoolId: schoolId,
      ),
      isUpdate: false,
    );
    expect(saved.createdByUid, store.authenticatedUser!.authUid);
    expect(store.teacherById(teacher.id)?.authUid, saved.createdByUid);
  });
}
