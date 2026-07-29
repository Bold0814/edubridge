import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/guardian/guardian_grades_screen.dart';
import 'package:edubridge/screens/guardian/learner_subject_grade_history_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/grade_average_calculator.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;
  late Student student;
  late int mathId;
  late int mongolId;
  var phoneSeq = 99333000;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();
    phoneSeq = 99333000;

    await store.createSchool(
      id: 'sch-learner-grade',
      name: 'Learner Grade School',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-learner-grade',
      fullName: 'Admin',
      username: 'lgadmin',
      password: 'test123',
    );
    await store.addSchoolClass(name: 'L9A');
    await store.addSubject('LgMath');
    await store.addSubject('LgMongol');
    mathId = store.subjectByName('LgMath')!.id;
    mongolId = store.subjectByName('LgMongol')!.id;

    student = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('L9A'),
        className: 'L9A',
        lastName: 'Бат',
        firstName: 'Ану',
        gender: StudentGender.female,
      ),
      guardianFullName: 'Ээж',
      guardianPhone: '${phoneSeq++}',
      relationship: 'Ээж',
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> loginAsStudent() async {
    final guardians = store.guardiansForStudent(student.id);
    expect(guardians, isNotEmpty);
    final phone = guardians.first.phone;
    final lookup = store.lookupStudentActivation(
      studentCode: student.studentCode!,
      guardianPhone: phone,
    );
    expect(lookup.result, ActivationLookupResult.ok);
    await store.activateAccountWithPin(userId: lookup.account!.id, pin: '2468');
    try {
      await store.logout();
    } catch (_) {}
    final result = await store.login(
      username: student.studentCode!,
      password: '2468',
      rememberMe: false,
    );
    expect(result, LoginResult.success);
    final memberships = store.activeMembershipsForUser(
      store.authenticatedUser!.id,
    );
    if (memberships.isNotEmpty) {
      await store.selectSchoolMembership(memberships.first);
    }
  }
  Future<void> addGrade({
    required String subject,
    required int subjectId,
    required String score,
    required String term,
    String? gradeDate,
    DateTime? createdAt,
    String? note,
  }) {
    return store.addGrade(
      Grade(
        id: store.nextGradeId(),
        className: 'L9A',
        studentId: student.id,
        studentName: student.fullName,
        subject: subject,
        subjectId: subjectId,
        score: score,
        term: term,
        termId: term,
        schoolId: 'sch-learner-grade',
        gradeDate: gradeDate,
        createdAt: createdAt,
        note: note,
        letterGrade: Grade.letterFromScore(double.parse(score)),
      ),
    );
  }

  test('1. grades from different terms are not mixed', () async {
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '90',
      term: '1-р улирал',
    );
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '40',
      term: '2-р улирал',
    );

    final term1 = store.gradesForStudentContext(
      className: 'L9A',
      studentId: student.id,
      term: '1-р улирал',
    );
    final term2 = store.gradesForStudentContext(
      className: 'L9A',
      studentId: student.id,
      term: '2-р улирал',
    );
    expect(term1, hasLength(1));
    expect(term1.first.score, '90');
    expect(term2, hasLength(1));
    expect(term2.first.score, '40');

    final averages = store.subjectAveragesForStudent(
      className: 'L9A',
      studentId: student.id,
      term: '1-р улирал',
      onlyWithGrades: true,
    );
    expect(averages, hasLength(1));
    expect(averages.first.average, 90);
  });

  test('2. multiple grades for one subject appear as one summary row', () async {
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '80',
      term: '1-р улирал',
    );
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '70',
      term: '1-р улирал',
    );
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '60',
      term: '1-р улирал',
    );

    final averages = store.subjectAveragesForStudent(
      className: 'L9A',
      studentId: student.id,
      term: '1-р улирал',
      onlyWithGrades: true,
    );
    expect(averages, hasLength(1));
    expect(averages.first.subjectId, mathId);
    expect(averages.first.gradeCount, 3);
  });

  test('3. subject average is calculated correctly', () async {
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '50',
      term: '1-р улирал',
    );
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '80',
      term: '1-р улирал',
    );

    final averages = store.subjectAveragesForStudent(
      className: 'L9A',
      studentId: student.id,
      term: '1-р улирал',
      onlyWithGrades: true,
    );
    expect(averages.first.average, 65);
  });

  test('4. letter grade uses the existing grade scale', () {
    expect(Grade.letterFromScore(65), 'D');
    expect(Grade.letterFromScore(79), 'C+');
    expect(Grade.letterFromScore(95), 'A+');

    final row = SubjectGradeAverage(
      subjectId: mathId,
      subjectName: 'LgMath',
      average: 65,
      gradeCount: 2,
    );
    expect(row.letterGrade, 'D');
    expect(row.displayWithLetter, '65.0 (D)');
  });

  testWidgets('5. tapping a subject opens only that subject history', (
    tester,
  ) async {
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '88',
      term: '1-р улирал',
      gradeDate: '2026-07-25',
      createdAt: DateTime(2026, 7, 25, 14, 20),
    );
    await addGrade(
      subject: 'LgMongol',
      subjectId: mongolId,
      score: '70',
      term: '1-р улирал',
      gradeDate: '2026-07-20',
      createdAt: DateTime(2026, 7, 20, 10, 0),
    );
    await loginAsStudent();

    await tester.pumpWidget(
      MaterialApp(
        home: GuardianGradesScreen(store: store, student: student),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LgMath'), findsOneWidget);
    expect(find.text('LgMongol'), findsOneWidget);
    expect(find.text('88 (B+)'), findsNothing);
    expect(find.text('70 (C)'), findsNothing);

    await tester.tap(find.text('LgMath'));
    await tester.pumpAndSettle();

    expect(find.byType(LearnerSubjectGradeHistoryScreen), findsOneWidget);
    expect(find.text('LgMath · 1-р улирал'), findsOneWidget);
    expect(find.text('88 (B+)'), findsOneWidget);
    expect(find.text('70 (C)'), findsNothing);
  });

  test('6. grade history is ordered newest first', () async {
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '40',
      term: '1-р улирал',
      gradeDate: '2026-07-10',
      createdAt: DateTime(2026, 7, 10, 9),
    );
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '90',
      term: '1-р улирал',
      gradeDate: '2026-07-25',
      createdAt: DateTime(2026, 7, 25, 14),
    );
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '70',
      term: '1-р улирал',
      gradeDate: '2026-07-18',
      createdAt: DateTime(2026, 7, 18, 11),
    );

    final sorted = GradeAverageCalculator.sortNewestFirst(
      store.gradesForStudentContext(
        className: 'L9A',
        studentId: student.id,
        subjectId: mathId,
        term: '1-р улирал',
      ),
    );
    expect(sorted.map((g) => g.score).toList(), ['90', '70', '40']);
  });

  test('7. different subjects are not mixed', () async {
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '90',
      term: '1-р улирал',
    );
    await addGrade(
      subject: 'LgMongol',
      subjectId: mongolId,
      score: '50',
      term: '1-р улирал',
    );

    final mathOnly = store.gradesForStudentContext(
      className: 'L9A',
      studentId: student.id,
      subjectId: mathId,
      term: '1-р улирал',
    );
    expect(mathOnly, hasLength(1));
    expect(mathOnly.first.subject, 'LgMath');
    expect(
      mathOnly.any((g) => g.subject == 'LgMongol'),
      isFalse,
    );
  });

  testWidgets('8. student cannot see add/edit/delete controls', (tester) async {
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '75',
      term: '1-р улирал',
      gradeDate: '2026-07-25',
      createdAt: DateTime(2026, 7, 25, 14, 20),
    );
    await loginAsStudent();

    await tester.pumpWidget(
      MaterialApp(
        home: GuardianGradesScreen(store: store, student: student),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Цэс'), findsNothing);

    await tester.tap(find.text('LgMath'));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Цэс'), findsNothing);
    expect(find.text('✏️ Засах'), findsNothing);
    expect(find.text('🗑 Устгах'), findsNothing);
  });

  test('9. missing date displays Огноо тодорхойгүй', () {
    const undated = Grade(
      id: 'g-undated',
      className: 'L9A',
      studentId: 's1',
      studentName: 'A',
      subject: 'LgMath',
      score: '50',
      term: '1-р улирал',
    );
    expect(
      GradeAverageCalculator.historyDateLabel(undated),
      GradeAverageCalculator.unknownDateLabel,
    );
    expect(GradeAverageCalculator.historyTimeLabel(undated), isNull);

    final sorted = GradeAverageCalculator.sortNewestFirst([
      undated,
      Grade(
        id: 'g-dated',
        className: 'L9A',
        studentId: 's1',
        studentName: 'A',
        subject: 'LgMath',
        score: '80',
        term: '1-р улирал',
        gradeDate: '2026-07-25',
        createdAt: DateTime(2026, 7, 25, 12),
      ),
    ]);
    expect(sorted.first.id, 'g-dated');
    expect(sorted.last.id, 'g-undated');
  });

  testWidgets('10. empty term displays correct Mongolian empty state', (
    tester,
  ) async {
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '90',
      term: '2-р улирал',
    );
    await loginAsStudent();

    await tester.pumpWidget(
      MaterialApp(
        home: GuardianGradesScreen(store: store, student: student),
      ),
    );
    await tester.pumpAndSettle();

    // Default term is 1-р улирал (school current semester).
    expect(find.text(GradeAverageCalculator.emptyTermMessage), findsOneWidget);
    expect(find.text('LgMath'), findsNothing);
  });

  test('11. teacher and student views use the same average helper', () async {
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '60',
      term: '1-р улирал',
    );
    await addGrade(
      subject: 'LgMath',
      subjectId: mathId,
      score: '80',
      term: '1-р улирал',
    );

    final grades = store.gradesForStudentContext(
      className: 'L9A',
      studentId: student.id,
      subjectId: mathId,
      term: '1-р улирал',
    );
    final shared = GradeAverageCalculator.average(grades);
    final viaStore = store.averageScore(grades);
    final viaSubject = store.subjectAveragesForStudent(
      className: 'L9A',
      studentId: student.id,
      term: '1-р улирал',
      onlyWithGrades: true,
    ).first.average;

    expect(shared, 70);
    expect(viaStore, shared);
    expect(viaSubject, shared);
  });
}
