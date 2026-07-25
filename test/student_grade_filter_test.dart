import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/student_detail_screen.dart';
import 'package:edubridge/screens/student_grade_detail_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;
  late Student student;
  late Student otherStudent;
  var phoneSeq = 99222000;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();
    phoneSeq = 99222000;
    await store.createSchool(
      id: 'sch-gf',
      name: 'Дүн шүүлт',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-gf',
      fullName: 'А. Админ',
      username: 'gfadmin',
      password: 'test123',
    );
    await store.addSchoolClass(name: 'F6А');
    await store.addSchoolClass(name: 'F6Б');
    await store.addSubject('GfМонгол');
    await store.addSubject('GfМат');
    student = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('F6А'),
        className: 'F6А',
        lastName: 'Амар',
        firstName: 'Ану',
        gender: StudentGender.female,
      ),
      guardianFullName: 'Ээж',
      guardianPhone: '${phoneSeq++}',
      relationship: 'Ээж',
    );
    otherStudent = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('F6А'),
        className: 'F6А',
        lastName: 'Бусад',
        firstName: 'Сурагч',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Аав',
      guardianPhone: '${phoneSeq++}',
      relationship: 'Аав',
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> addGrade({
    required Student forStudent,
    required String className,
    required String subject,
    required String score,
    required String term,
  }) {
    return store.addGrade(
      Grade(
        id: store.nextGradeId(),
        className: className,
        studentId: forStudent.id,
        studentName: forStudent.fullName,
        subject: subject,
        score: score,
        term: term,
      ),
    );
  }

  test('summary and detail share the same Student.id records', () async {
    await addGrade(
      forStudent: student,
      className: 'F6А',
      subject: 'GfМонгол',
      score: '80',
      term: '1-р улирал',
    );
    await addGrade(
      forStudent: student,
      className: 'F6А',
      subject: 'GfМат',
      score: '70',
      term: '1-р улирал',
    );
    await addGrade(
      forStudent: otherStudent,
      className: 'F6А',
      subject: 'GfМонгол',
      score: '99',
      term: '1-р улирал',
    );

    final mongol = store.activeSubjects.firstWhere((s) => s.name == 'GfМонгол');
    final summary = store.gradesForStudentContext(
      className: 'F6А',
      studentId: student.id,
      subjectId: mongol.id,
      term: '1-р улирал',
    );
    final detail = store.gradesForStudentContext(
      className: 'F6А',
      studentId: student.id,
      subjectId: mongol.id,
      term: '1-р улирал',
    );

    expect(summary.map((g) => g.id), detail.map((g) => g.id));
    expect(summary, hasLength(1));
    expect(summary.first.studentId, student.id);
    expect(summary.first.score, '80');
    expect(store.averageScore(summary), 80);
  });

  test('selected subject and term filter correctly', () async {
    await addGrade(
      forStudent: student,
      className: 'F6А',
      subject: 'GfМонгол',
      score: '78',
      term: '1-р улирал',
    );
    await addGrade(
      forStudent: student,
      className: 'F6А',
      subject: 'GfМонгол',
      score: '90',
      term: '2-р улирал',
    );
    await addGrade(
      forStudent: student,
      className: 'F6А',
      subject: 'GfМат',
      score: '60',
      term: '1-р улирал',
    );

    final term1 = store.gradesForStudentContext(
      className: 'F6А',
      studentId: student.id,
      subjectName: 'GfМонгол',
      term: '1-р улирал',
    );
    expect(term1, hasLength(1));
    expect(term1.first.score, '78');

    final allTerms = store.gradesForStudentContext(
      className: 'F6А',
      studentId: student.id,
      subjectName: 'GfМонгол',
    );
    expect(allTerms, hasLength(2));
  });

  test('null subject/term do not invent null comparisons', () async {
    await addGrade(
      forStudent: student,
      className: 'F6А',
      subject: 'GfМонгол',
      score: '78',
      term: '1-р улирал',
    );
    await addGrade(
      forStudent: student,
      className: 'F6А',
      subject: 'GfМат',
      score: '80',
      term: '2-р улирал',
    );

    final all = store.gradesForStudentContext(
      className: 'F6А',
      studentId: student.id,
    );
    expect(all, hasLength(2));
  });

  test('other student/class grades are excluded', () async {
    await addGrade(
      forStudent: student,
      className: 'F6А',
      subject: 'GfМонгол',
      score: '78',
      term: '1-р улирал',
    );
    await addGrade(
      forStudent: otherStudent,
      className: 'F6А',
      subject: 'GfМонгол',
      score: '50',
      term: '1-р улирал',
    );
    final otherClassStudent = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('F6Б'),
        className: 'F6Б',
        lastName: 'Анги',
        firstName: 'Өөр',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Ээж',
      guardianPhone: '${phoneSeq++}',
      relationship: 'Ээж',
    );
    await addGrade(
      forStudent: otherClassStudent,
      className: 'F6Б',
      subject: 'GfМонгол',
      score: '40',
      term: '1-р улирал',
    );

    final rows = store.gradesForStudentContext(
      className: 'F6А',
      studentId: student.id,
      subjectName: 'GfМонгол',
    );
    expect(rows, hasLength(1));
    expect(rows.first.studentId, student.id);
    expect(
      store.gradesForStudentContext(
        className: 'Unknown',
        studentId: student.id,
      ),
      isEmpty,
    );
  });

  testWidgets('existing grade opens from Дүн харах with same filter', (
    tester,
  ) async {
    await addGrade(
      forStudent: student,
      className: 'F6А',
      subject: 'GfМонгол',
      score: '79',
      term: '1-р улирал',
    );
    await addGrade(
      forStudent: student,
      className: 'F6А',
      subject: 'GfМат',
      score: '90',
      term: '1-р улирал',
    );
    final mongol = store.activeSubjects.firstWhere((s) => s.name == 'GfМонгол');
    await store.setTeacherWorkspace(classId: 'F6А', subjectId: mongol.id);
    store.setJournalTerm('F6А', '1-р улирал');

    await tester.pumpWidget(
      MaterialApp(
        home: StudentDetailScreen(
          studentId: student.id,
          selectedClass: 'F6А',
          store: store,
          subjectId: mongol.id,
          selectedSubject: 'GfМонгол',
          selectedTerm: '1-р улирал',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Дундаж дүн: 79'), findsOneWidget);

    await tester.tap(find.text('Дүн харах'));
    // Empty copy must not appear while loading or once records are ready.
    await tester.pump();
    expect(find.text('Дүн бүртгээгүй байна'), findsNothing);
    expect(find.text('Энэ хичээл, улиралд дүн бүртгээгүй байна'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byType(StudentGradeDetailScreen), findsOneWidget);
    expect(
      find.textContaining('Амар Ану · GfМонгол · 1-р улирал'),
      findsOneWidget,
    );
    expect(find.text('79 (C+)'), findsOneWidget);
    expect(find.text('Дүн бүртгээгүй байна'), findsNothing);
    expect(find.text('Энэ хичээл, улиралд дүн бүртгээгүй байна'), findsNothing);
  });

  testWidgets('empty state only when filtered result is truly empty', (
    tester,
  ) async {
    await addGrade(
      forStudent: student,
      className: 'F6А',
      subject: 'GfМат',
      score: '90',
      term: '1-р улирал',
    );
    final mongol = store.activeSubjects.firstWhere((s) => s.name == 'GfМонгол');

    await tester.pumpWidget(
      MaterialApp(
        home: StudentGradeDetailScreen(
          store: store,
          student: student,
          schoolId: 'sch-gf',
          classId: 'F6А',
          subjectId: mongol.id,
          term: '1-р улирал',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Энэ хичээл, улиралд дүн бүртгээгүй байна'),
      findsOneWidget,
    );
    expect(find.text('90 (A)'), findsNothing);
  });
}
