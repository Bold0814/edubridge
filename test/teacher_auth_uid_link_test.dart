import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/firestore_grade_repository.dart';
import 'package:edubridge/services/firestore_staff_repository.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late MemoryGradeDocumentStore memory;
  late AppStore store;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    memory = MemoryGradeDocumentStore();
    store = AppStore(
      EduBridgeRepository(database),
      gradeRepository: FirestoreGradeRepository(store: memory),
      firestoreStaff: FirestoreStaffRepository(store: memory),
    );
    await store.load();
    await store.createSchool(
      id: 'sch-12a',
      name: '12a school',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-12a',
      fullName: 'Admin',
      username: 'admin12a',
      password: 'test123',
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('debug link binds Firebase authUid to Bold teacher document id', () async {
    final boldId = store.nextTeacherId();
    await store.addTeacher(
      Teacher(
        id: boldId,
        fullName: 'Bold',
        schoolId: 'sch-12a',
        phone: '99112233',
      ),
    );
    await store.linkTeacherAuthUidForDebug(
      teacherId: boldId,
      authUid: 'firebase-bold-uid',
    );

    final linked = store.teacherById(boldId)!;
    expect(linked.authUid, 'firebase-bold-uid');
    expect(linked.fullName, 'Bold');

    final cloud = await store.firestoreStaffRepository.getTeacher(boldId);
    expect(cloud?.authUid, 'firebase-bold-uid');
    expect(cloud?.id, boldId);
  });

  test('grade teacherId uses stable teacher document id not display name',
      () async {
    await store.addSchoolClass(name: '12a');
    await store.addSubject('Math');
    final math = store.subjectByName('Math')!;
    final boldId = store.nextTeacherId();
    await store.addTeacher(
      Teacher(
        id: boldId,
        fullName: 'Bold',
        schoolId: 'sch-12a',
      ),
    );
    await store.saveClassAssignments(
      classId: '12a',
      homeroomTeacherId: boldId,
      subjectTeacherIds: {math.id: boldId},
    );

    expect(store.teacherIdForClassSubject('12a', math.id), boldId);
    expect(store.teacherIdForClassSubject('12a', math.id), isNot('Bold'));

    final student = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('12a'),
        className: '12a',
        lastName: 'Сүх',
        firstName: 'Ану',
        gender: StudentGender.female,
      ),
      guardianFullName: 'Ээж',
      guardianPhone: '88001122',
      relationship: 'Ээж',
    );

    final prepared = store.prepareGradeForSave(
      Grade(
        id: 'gr-test',
        className: '12a',
        studentId: student.id,
        studentName: student.fullName,
        subject: 'Math',
        subjectId: math.id,
        teacherId: boldId,
        score: '88',
        term: '1-р улирал',
      ),
      isCreate: true,
    );

    expect(prepared.teacherId, boldId);
    expect(prepared.teacherId, isNot('Bold'));
    expect(prepared.subjectId, math.id);
    expect(prepared.className, '12a');
  });
}
