import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/grade_screen.dart';
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
  var phoneSeq = 99001000;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();
    phoneSeq = 99001000;
    await store.createSchool(
      id: 'sch-grade',
      name: 'Дүн сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-grade',
      fullName: 'А. Админ',
      username: 'gradeadmin',
      password: 'test123',
    );
    await store.addSchoolClass(name: 'G6А');
    await store.addSubject('GradeМат');
    await store.addSubject('GradeМонгол');
  });

  tearDown(() async {
    await database.close();
  });

  Future<Student> addStudent(String last, String first) {
    final phone = '${phoneSeq++}';
    return store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('G6А'),
        className: 'G6А',
        lastName: last,
        firstName: first,
        gender: StudentGender.female,
      ),
      guardianFullName: 'Ээж',
      guardianPhone: phone,
      relationship: 'Ээж',
    );
  }

  Future<void> addGrade({
    required Student student,
    required String subject,
    required String score,
  }) {
    return store.addGrade(
      Grade(
        id: store.nextGradeId(),
        className: 'G6А',
        studentId: student.id,
        studentName: student.fullName,
        subject: subject,
        score: score,
        term: '1-р улирал',
      ),
    );
  }

  testWidgets('grade overview shows one row per student with averages', (
    tester,
  ) async {
    final a = await addStudent('Амар', 'Ану');
    final b = await addStudent('Амар', 'Наран');
    await addStudent('Амар', 'Оюун');
    await addGrade(student: a, subject: 'GradeМат', score: '80');
    await addGrade(student: a, subject: 'GradeМат', score: '70');
    await addGrade(student: b, subject: 'GradeМат', score: '81');
    await addGrade(student: b, subject: 'GradeМонгол', score: '81');

    await store.setTeacherWorkspace(classId: 'G6А', subjectId: null);

    await tester.pumpWidget(
      MaterialApp(
        home: GradeScreen(selectedClass: 'G6А', store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('G6А · Ангийн дүн'), findsOneWidget);
    expect(find.text('Амар Ану'), findsOneWidget);
    expect(find.text('Амар Наран'), findsOneWidget);
    expect(find.text('Амар Оюун'), findsOneWidget);
    expect(find.text('75.0'), findsOneWidget); // (80+70)/2 all subjects
    expect(find.text('81.0'), findsOneWidget);
    expect(find.text('Дүн оруулаагүй'), findsOneWidget);
    expect(find.text('✏️ Засах'), findsNothing);
  });

  testWidgets('selected subject filters the student average', (tester) async {
    final student = await addStudent('Бат', 'Болд');
    await addGrade(student: student, subject: 'GradeМат', score: '90');
    await addGrade(student: student, subject: 'GradeМонгол', score: '60');
    final math = store.activeSubjects.firstWhere((s) => s.name == 'GradeМат');
    await store.setTeacherWorkspace(classId: 'G6А', subjectId: math.id);

    await tester.pumpWidget(
      MaterialApp(
        home: GradeScreen(selectedClass: 'G6А', store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('90.0'), findsOneWidget);
    expect(find.text('75.0'), findsNothing);
  });

  testWidgets('tapping student opens grade detail with subjects', (
    tester,
  ) async {
    final student = await addStudent('Сэр', 'Гэрэл');
    await addGrade(student: student, subject: 'GradeМат', score: '82');
    await addGrade(student: student, subject: 'GradeМат', score: '78');
    await addGrade(student: student, subject: 'GradeМонгол', score: '76');
    await store.setTeacherWorkspace(classId: 'G6А', subjectId: null);

    await tester.pumpWidget(
      MaterialApp(
        home: GradeScreen(selectedClass: 'G6А', store: store),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сэр Гэрэл'));
    await tester.pumpAndSettle();

    expect(find.byType(StudentGradeDetailScreen), findsOneWidget);
    expect(find.text('Сэр Гэрэл'), findsWidgets);
    expect(find.text('GradeМат'), findsOneWidget);
    expect(find.text('GradeМонгол'), findsOneWidget);
    expect(find.text('80.0'), findsOneWidget);
    expect(find.text('76.0'), findsOneWidget);
  });

  testWidgets('active subject opens student records directly', (tester) async {
    final student = await addStudent('Дорж', 'Сараа');
    await addGrade(student: student, subject: 'GradeМат', score: '88');
    await addGrade(student: student, subject: 'GradeМонгол', score: '70');
    final math = store.activeSubjects.firstWhere((s) => s.name == 'GradeМат');
    await store.setTeacherWorkspace(classId: 'G6А', subjectId: math.id);

    await tester.pumpWidget(
      MaterialApp(
        home: GradeScreen(selectedClass: 'G6А', store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дорж Сараа'));
    await tester.pumpAndSettle();

    expect(find.byType(StudentGradeDetailScreen), findsOneWidget);
    expect(find.text('88 (B+)'), findsOneWidget);
    // Unrelated subject records are not listed.
    expect(find.text('70 (C)'), findsNothing);
  });

  test('no cross-class grades in averages', () async {
    final student = await addStudent('Нэг', 'Анги');
    await store.addSchoolClass(name: 'G6Б');
    await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('G6Б'),
        className: 'G6Б',
        lastName: 'Бусад',
        firstName: 'Анги',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Аав',
      guardianPhone: '88112233',
      relationship: 'Аав',
    );
    final other = store.studentsFor('G6Б').first;
    await addGrade(student: student, subject: 'GradeМат', score: '100');
    await store.addGrade(
      Grade(
        id: store.nextGradeId(),
        className: 'G6Б',
        studentId: other.id,
        studentName: other.fullName,
        subject: 'GradeМат',
        score: '50',
        term: '1-р улирал',
      ),
    );

    final avg = store.averageGradeForClassStudent(
      className: 'G6А',
      studentId: student.id,
    );
    expect(avg, 100);
    expect(
      store.gradesForClass('G6А').map((g) => g.studentId),
      everyElement(student.id),
    );
  });
}
