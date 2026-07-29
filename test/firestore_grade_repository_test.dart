import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/student_grade_detail_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/firestore_grade_repository.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late MemoryGradeDocumentStore memoryStore;
  late FirestoreGradeRepository gradeRepo;
  late AppStore store;
  late Student studentA;
  late Student studentBSameName;
  var phoneSeq = 88001000;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    memoryStore = MemoryGradeDocumentStore();
    gradeRepo = FirestoreGradeRepository(store: memoryStore);
    store = AppStore(
      EduBridgeRepository(database),
      gradeRepository: gradeRepo,
    );
    await store.load();
    phoneSeq = 88001000;

    await store.createSchool(
      id: 'sch-fs-grade',
      name: 'Firestore дүн',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-fs-grade',
      fullName: 'А. Админ',
      username: 'fsgradeadmin',
      password: 'test123',
    );
    await store.addSchoolClass(name: 'FS6А');
    await store.addSubject('FsМат');
    await store.addSubject('FsМонгол');

    studentA = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('FS6А'),
        className: 'FS6А',
        lastName: 'Бат',
        firstName: 'Ану',
        gender: StudentGender.female,
      ),
      guardianFullName: 'Ээж А',
      guardianPhone: '${phoneSeq++}',
      relationship: 'Ээж',
    );
    studentBSameName = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('FS6А'),
        className: 'FS6А',
        lastName: 'Бат',
        firstName: 'Ану',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Ээж Б',
      guardianPhone: '${phoneSeq++}',
      relationship: 'Ээж',
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<Grade> saveGrade({
    required Student student,
    required String subject,
    required String score,
    required String term,
    String? id,
  }) async {
    final grade = Grade(
      id: id ?? store.nextGradeId(),
      className: 'FS6А',
      studentId: student.id,
      studentName: student.fullName,
      subject: subject,
      score: score,
      term: term,
    );
    await store.addGrade(grade);
    return store.gradesForStudent(student).firstWhere((g) => g.id == grade.id);
  }

  test('numeric-to-letter conversion uses shared grade scale', () {
    expect(Grade.letterFromScore(95), 'A+');
    expect(Grade.letterFromScore(90), 'A');
    expect(Grade.letterFromScore(85), 'B+');
    expect(Grade.letterFromScore(80), 'B');
    expect(Grade.letterFromScore(75), 'C+');
    expect(Grade.letterFromScore(70), 'C');
    expect(Grade.letterFromScore(60), 'D');
    expect(Grade.letterFromScore(59), 'F');
    expect(Grade.tryLetterFromScoreText('88'), 'B+');
    expect(Grade.tryLetterFromScoreText('101'), isNull);
  });

  test('create grade writes Firestore fields and letter grade', () async {
    final saved = await saveGrade(
      student: studentA,
      subject: 'FsМат',
      score: '92',
      term: '1-р улирал',
    );

    expect(saved.score, '92');
    expect(saved.letterGrade, 'A');
    expect(saved.schoolId, 'sch-fs-grade');
    expect(saved.className, 'FS6А');
    expect(saved.studentId, studentA.id);
    expect(saved.subjectId, isNotNull);
    expect(saved.termId, '1-р улирал');
    expect(saved.gradeType, Grade.defaultGradeType);
    expect(saved.gradeDate, isNotNull);

    final path = FirestoreGradeRepository.pathFor(saved.id);
    final doc = await memoryStore.get(path);
    expect(doc, isNotNull);
    expect(doc!['studentId'], studentA.id);
    expect(doc['score'], '92');
    expect(doc['letterGrade'], 'A');
    expect(doc['schoolId'], 'sch-fs-grade');
    expect(doc['classId'], 'FS6А');
    expect(doc['termId'], '1-р улирал');
    expect(doc['createdAt'], isNotNull);
    expect(doc['updatedAt'], isNotNull);
    expect(memoryStore.setCount, 1);
  });

  test('edit grade updates same document without duplicate', () async {
    final saved = await saveGrade(
      student: studentA,
      subject: 'FsМат',
      score: '70',
      term: '1-р улирал',
    );
    final path = FirestoreGradeRepository.pathFor(saved.id);
    final before = await memoryStore.get(path);
    final createdAt = before!['createdAt'];

    await store.updateGrade(saved.copyWith(score: '88'));

    expect(memoryStore.documents.keys.where((k) => k.startsWith('grades/')),
        hasLength(1));
    final after = await memoryStore.get(path);
    expect(after!['score'], '88');
    expect(after['letterGrade'], 'B+');
    expect(after['createdAt'], createdAt);
    expect(after['updatedAt'], isNot(createdAt));
    expect(store.gradesForStudent(studentA), hasLength(1));
  });

  test('delete grade removes Firestore document', () async {
    final saved = await saveGrade(
      student: studentA,
      subject: 'FsМат',
      score: '80',
      term: '1-р улирал',
    );
    await store.deleteGrade(saved.id);

    expect(await memoryStore.get(FirestoreGradeRepository.pathFor(saved.id)),
        isNull);
    expect(store.gradesForStudent(studentA), isEmpty);
    expect(memoryStore.deleteCount, 1);
  });

  test('student detail and portals show the same saved grade by studentId',
      () async {
    await saveGrade(
      student: studentA,
      subject: 'FsМат',
      score: '81',
      term: '1-р улирал',
    );

    final detail = store.gradesForStudentContext(
      className: 'FS6А',
      studentId: studentA.id,
      schoolId: 'sch-fs-grade',
    );
    expect(detail, hasLength(1));
    expect(detail.first.score, '81');

    final portal = store.gradesForStudent(studentA);
    expect(portal, hasLength(1));
    expect(portal.first.id, detail.first.id);

    final guardianView = store.gradesForStudent(studentA);
    expect(guardianView.first.studentId, studentA.id);
    expect(guardianView.first.studentId, isNot(studentBSameName.id));
  });

  test('class average uses the same filtered Firestore records', () async {
    await saveGrade(
      student: studentA,
      subject: 'FsМат',
      score: '80',
      term: '1-р улирал',
    );
    await saveGrade(
      student: studentA,
      subject: 'FsМат',
      score: '90',
      term: '1-р улирал',
    );

    final grades = store.gradesForStudentContext(
      className: 'FS6А',
      studentId: studentA.id,
      subjectName: 'FsМат',
      term: '1-р улирал',
    );
    final average = store.averageScore(grades);
    expect(average, 85);
    expect(
      store.averageGradeForClassStudent(
        className: 'FS6А',
        studentId: studentA.id,
        subjectName: 'FsМат',
        term: '1-р улирал',
      ),
      85,
    );
  });

  test('different subjects and terms do not mix', () async {
    await saveGrade(
      student: studentA,
      subject: 'FsМат',
      score: '80',
      term: '1-р улирал',
    );
    await saveGrade(
      student: studentA,
      subject: 'FsМонгол',
      score: '90',
      term: '1-р улирал',
    );
    await saveGrade(
      student: studentA,
      subject: 'FsМат',
      score: '60',
      term: '2-р улирал',
    );

    final mathT1 = store.gradesForStudentContext(
      className: 'FS6А',
      studentId: studentA.id,
      subjectName: 'FsМат',
      term: '1-р улирал',
    );
    expect(mathT1, hasLength(1));
    expect(mathT1.first.score, '80');

    final mathT2 = store.gradesForStudentContext(
      className: 'FS6А',
      studentId: studentA.id,
      subjectName: 'FsМат',
      term: '2-р улирал',
    );
    expect(mathT2, hasLength(1));
    expect(mathT2.first.score, '60');
  });

  test('two students with the same name do not mix grades', () async {
    expect(studentA.fullName, studentBSameName.fullName);
    expect(studentA.id, isNot(studentBSameName.id));

    await saveGrade(
      student: studentA,
      subject: 'FsМат',
      score: '95',
      term: '1-р улирал',
    );
    await saveGrade(
      student: studentBSameName,
      subject: 'FsМат',
      score: '55',
      term: '1-р улирал',
    );

    final aGrades = store.gradesForStudent(studentA);
    final bGrades = store.gradesForStudent(studentBSameName);
    expect(aGrades, hasLength(1));
    expect(bGrades, hasLength(1));
    expect(aGrades.first.score, '95');
    expect(bGrades.first.score, '55');
    expect(aGrades.first.studentId, studentA.id);
    expect(bGrades.first.studentId, studentBSameName.id);
  });

  test('legacy Firestore docs with missing optional fields still parse', () {
    final grade = Grade.fromFirestore('legacy-1', {
      'classId': 'FS6А',
      'studentId': 'stu-1',
      'studentName': 'Test',
      'subject': 'FsМат',
      'score': '77',
      'term': '1-р улирал',
    });
    expect(grade.id, 'legacy-1');
    expect(grade.schoolId, isNull);
    expect(grade.subjectId, isNull);
    expect(grade.letterGrade, isNull);
    expect(grade.resolvedLetterGrade, 'C+');
    expect(grade.resolvedTermId, '1-р улирал');
  });

  testWidgets('student detail screen lists saved grade', (tester) async {
    final saved = await saveGrade(
      student: studentA,
      subject: 'FsМат',
      score: '84',
      term: '1-р улирал',
    );

    expect(
      store.gradesForStudentContext(
        className: 'FS6А',
        studentId: studentA.id,
      ),
      isNotEmpty,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentGradeDetailScreen(
          store: store,
          student: studentA,
          schoolId: store.activeSchoolId,
          classId: 'FS6А',
          subjectName: 'FsМат',
          term: '1-р улирал',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(saved.score), findsWidgets);
    expect(find.textContaining('B'), findsWidgets);
  });

  test('guardian portal uses linked child studentId (not name)', () async {
    await saveGrade(
      student: studentA,
      subject: 'FsМонгол',
      score: '91',
      term: '1-р улирал',
    );
    await saveGrade(
      student: studentBSameName,
      subject: 'FsМонгол',
      score: '40',
      term: '1-р улирал',
    );

    // Same source of truth GuardianGradesScreen / student portal call.
    final childGrades = store.gradesForStudent(studentA);
    expect(childGrades, hasLength(1));
    expect(childGrades.first.studentId, studentA.id);
    expect(childGrades.first.score, '91');
    expect(childGrades.first.letterGrade, 'A');
  });
}
