import 'package:edubridge/models/class_naming.dart';
import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/subject.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/class_create_screen.dart';
import 'package:edubridge/screens/grade_screen.dart';
import 'package:edubridge/screens/student_grade_detail_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/grade_average_calculator.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClassNaming', () {
    test('rejects grade 0', () {
      expect(ClassNaming.isValidGradeLevel(0), isFalse);
      expect(() => ClassNaming.displayName(gradeLevel: 0), throwsArgumentError);
    });

    test('rejects grade 13', () {
      expect(ClassNaming.isValidGradeLevel(13), isFalse);
      expect(
        () => ClassNaming.displayName(gradeLevel: 13),
        throwsArgumentError,
      );
    });

    test('accepts 1–12', () {
      for (var g = 1; g <= 12; g++) {
        expect(ClassNaming.isValidGradeLevel(g), isTrue);
      }
    });

    test('"12" + "а" displays "12а анги"', () {
      expect(
        ClassNaming.displayName(gradeLevel: 12, section: 'а'),
        '12а анги',
      );
      expect(
        ClassNaming.displayName(gradeLevel: 5, section: 'Б'),
        '5б анги',
      );
      expect(ClassNaming.displayName(gradeLevel: 5), '5-р анги');
    });

    test('parses legacy compact and numbered names', () {
      expect(ClassNaming.tryParse('12а')?.gradeLevel, 12);
      expect(ClassNaming.tryParse('12а')?.section, 'а');
      expect(ClassNaming.tryParse('6А')?.section, 'а');
      expect(ClassNaming.tryParse('5-р анги')?.gradeLevel, 5);
      expect(ClassNaming.tryParse('5-р анги')?.section, isNull);
      expect(ClassNaming.tryParse('G6А'), isNull);
    });
  });

  group('Class creation store validation', () {
    late Database database;
    late AppStore store;

    setUp(() async {
      database = await DatabaseService.instance.openInMemoryForTest();
      store = AppStore(EduBridgeRepository(database));
      await store.load();
      await store.createSchool(
        id: 'sch-cls',
        name: 'Class School',
        academicYear: SchoolSettings.currentAcademicYear(),
        currentSemester: SchoolSettings.semesterOptions.first,
      );
      await store.createFirstSchoolAdmin(
        schoolId: 'sch-cls',
        fullName: 'Admin',
        username: 'clsadmin',
        password: 'test123',
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('rejects grade 0 and 13 via store', () async {
      await expectLater(
        store.addSchoolClass(gradeLevel: 0, section: 'а'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'INVALID_GRADE_LEVEL',
          ),
        ),
      );
      await expectLater(
        store.addSchoolClass(gradeLevel: 13),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'INVALID_GRADE_LEVEL',
          ),
        ),
      );
    });

    test('accepts 1–12 and builds display name', () async {
      await store.addSchoolClass(gradeLevel: 12, section: 'А');
      final created = store.schoolClassesForActiveSchool.firstWhere(
        (c) => c.gradeLevel == 12,
      );
      expect(created.name, '12а анги');
      expect(created.section, 'а');
    });

    test('duplicate gradeLevel + section in same school is rejected', () async {
      await store.addSchoolClass(gradeLevel: 7, section: 'б');
      await expectLater(
        store.addSchoolClass(gradeLevel: 7, section: 'Б'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'DUPLICATE_CLASS',
          ),
        ),
      );
    });

    testWidgets('create form uses grade dropdown not free-text level', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: ClassCreateScreen(store: store)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ангийн түвшин'), findsOneWidget);
      expect(find.text('Бүлэг (заавал биш)'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8-р анги').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'а');
      await tester.tap(find.text('Нэмэх'));
      await tester.pumpAndSettle();

      expect(
        store.schoolClassesForActiveSchool.any((c) => c.name == '8а анги'),
        isTrue,
      );
    });
  });

  group('Grade averages and three-level navigation', () {
    late Database database;
    late AppStore store;
    late Student student;
    late Student other;
    late int mathId;
    late int otherMathId;
    var phoneSeq = 77001000;

    setUp(() async {
      database = await DatabaseService.instance.openInMemoryForTest();
      store = AppStore(EduBridgeRepository(database));
      await store.load();
      phoneSeq = 77001000;
      await store.createSchool(
        id: 'sch-nav',
        name: 'Nav School',
        academicYear: SchoolSettings.currentAcademicYear(),
        currentSemester: SchoolSettings.semesterOptions.first,
      );
      await store.createFirstSchoolAdmin(
        schoolId: 'sch-nav',
        fullName: 'Admin',
        username: 'navadmin',
        password: 'test123',
      );
      await store.addSchoolClass(gradeLevel: 12, section: 'а');
      await store.addSubject('NavМат');
      await store.addSubject('NavМонгол');
      await store.addSubject('NavМатB');
      mathId = store.subjectByName('NavМат')!.id;
      otherMathId = store.subjectByName('NavМатB')!.id;

      student = await store.addStudentWithRequiredGuardian(
        student: Student(
          id: store.nextStudentId('12а анги'),
          className: '12а анги',
          lastName: 'Togsoo',
          firstName: 'Togs',
          gender: StudentGender.male,
        ),
        guardianFullName: 'Ээж',
        guardianPhone: '${phoneSeq++}',
        relationship: 'Ээж',
      );
      other = await store.addStudentWithRequiredGuardian(
        student: Student(
          id: store.nextStudentId('12а анги'),
          className: '12а анги',
          lastName: 'Other',
          firstName: 'Kid',
          gender: StudentGender.female,
        ),
        guardianFullName: 'Аав',
        guardianPhone: '${phoneSeq++}',
        relationship: 'Аав',
      );
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> addScore({
      required Student forStudent,
      required int subjectId,
      required String subjectName,
      required String score,
      required String term,
      String? gradeDate,
    }) {
      return store.addGrade(
        Grade(
          id: store.nextGradeId(),
          className: '12а анги',
          studentId: forStudent.id,
          studentName: forStudent.fullName,
          subject: subjectName,
          subjectId: subjectId,
          score: score,
          term: term,
          termId: term,
          gradeDate: gradeDate,
          letterGrade: Grade.letterFromScore(num.parse(score)),
        ),
      );
    }

    test('two Math grades average to one subject row 75.0', () async {
      await addScore(
        forStudent: student,
        subjectId: mathId,
        subjectName: 'NavМат',
        score: '85',
        term: '1-р улирал',
      );
      await addScore(
        forStudent: student,
        subjectId: mathId,
        subjectName: 'NavМат',
        score: '65',
        term: '1-р улирал',
      );

      final rows = store.subjectAveragesForStudent(
        className: '12а анги',
        studentId: student.id,
        term: '1-р улирал',
      );
      final math = rows.where((r) => r.subjectId == mathId).toList();
      expect(math, hasLength(1));
      expect(math.single.average, 75.0);
      expect(math.single.displayAverage, '75.0');
      expect(math.single.displayWithLetter, '75.0 (C+)');
      expect(math.single.gradeCount, 2);
    });

    test('different terms are not mixed', () async {
      await addScore(
        forStudent: student,
        subjectId: mathId,
        subjectName: 'NavМат',
        score: '100',
        term: '1-р улирал',
      );
      await addScore(
        forStudent: student,
        subjectId: mathId,
        subjectName: 'NavМат',
        score: '50',
        term: '2-р улирал',
      );

      final t1 = store.averageGradeForClassStudent(
        className: '12а анги',
        studentId: student.id,
        term: '1-р улирал',
      );
      final t2 = store.averageGradeForClassStudent(
        className: '12а анги',
        studentId: student.id,
        term: '2-р улирал',
      );
      expect(t1, 100.0);
      expect(t2, 50.0);
    });

    test('different students are not mixed', () async {
      await addScore(
        forStudent: student,
        subjectId: mathId,
        subjectName: 'NavМат',
        score: '90',
        term: '1-р улирал',
      );
      await addScore(
        forStudent: other,
        subjectId: mathId,
        subjectName: 'NavМат',
        score: '40',
        term: '1-р улирал',
      );

      expect(
        store.averageGradeForClassStudent(
          className: '12а анги',
          studentId: student.id,
          term: '1-р улирал',
        ),
        90.0,
      );
      expect(
        store.averageGradeForClassStudent(
          className: '12а анги',
          studentId: other.id,
          term: '1-р улирал',
        ),
        40.0,
      );
    });

    test('different subjectIds with similar names are not mixed', () async {
      await addScore(
        forStudent: student,
        subjectId: mathId,
        subjectName: 'NavМат',
        score: '80',
        term: '1-р улирал',
      );
      await addScore(
        forStudent: student,
        subjectId: otherMathId,
        subjectName: 'NavМатB',
        score: '60',
        term: '1-р улирал',
      );

      final rows = store.subjectAveragesForStudent(
        className: '12а анги',
        studentId: student.id,
        term: '1-р улирал',
      );
      expect(
        rows.firstWhere((r) => r.subjectId == mathId).average,
        80.0,
      );
      expect(
        rows.firstWhere((r) => r.subjectId == otherMathId).average,
        60.0,
      );
    });

    test('empty grades display —', () {
      expect(GradeAverageCalculator.format(null), '—');
      expect(store.formatGradeAverage(null), '—');
      expect(
        store.averageGradeForClassStudent(
          className: '12а анги',
          studentId: student.id,
          term: '1-р улирал',
        ),
        isNull,
      );
    });

    test('subject detail sorts newest first with actual dates', () async {
      await addScore(
        forStudent: student,
        subjectId: mathId,
        subjectName: 'NavМат',
        score: '65',
        term: '1-р улирал',
        gradeDate: '2026-07-28',
      );
      await addScore(
        forStudent: student,
        subjectId: mathId,
        subjectName: 'NavМат',
        score: '85',
        term: '1-р улирал',
        gradeDate: '2026-07-29',
      );

      final sorted = GradeAverageCalculator.sortNewestFirst(
        store.gradesForStudentContext(
          className: '12а анги',
          studentId: student.id,
          subjectId: mathId,
          term: '1-р улирал',
        ),
      );
      expect(sorted, hasLength(2));
      expect(sorted.first.score, '85');
      expect(sorted.first.gradeDate, '2026-07-29');
      expect(sorted.last.score, '65');
    });

    test('class summary, student summary, and calculator share one helper', () {
      final grades = [
        Grade(
          id: '1',
          className: '12а анги',
          studentId: student.id,
          studentName: student.fullName,
          subject: 'NavМат',
          subjectId: mathId,
          score: '85',
          term: '1-р улирал',
        ),
        Grade(
          id: '2',
          className: '12а анги',
          studentId: student.id,
          studentName: student.fullName,
          subject: 'NavМат',
          subjectId: mathId,
          score: '65',
          term: '1-р улирал',
        ),
      ];
      final calc = GradeAverageCalculator.average(grades);
      expect(calc, 75.0);
      expect(store.averageScore(grades), calc);
      expect(GradeAverageCalculator.format(calc), '75.0');
      expect(
        GradeAverageCalculator.subjectAverages(
          grades: grades,
          subjects: [
            Subject(id: mathId, name: 'NavМат', schoolId: 'sch-nav'),
          ],
        ).single.average,
        calc,
      );
    });

    testWidgets('LEVEL 1 does not open individual Math rows', (tester) async {
      await addScore(
        forStudent: student,
        subjectId: mathId,
        subjectName: 'NavМат',
        score: '85',
        term: '1-р улирал',
        gradeDate: '2026-07-29',
      );
      await addScore(
        forStudent: student,
        subjectId: mathId,
        subjectName: 'NavМат',
        score: '65',
        term: '1-р улирал',
        gradeDate: '2026-07-28',
      );

      // Even with active Math workspace, class summary stays overall + LEVEL 2.
      await store.setTeacherWorkspace(
        classId: '12а анги',
        subjectId: mathId,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GradeScreen(selectedClass: '12а анги', store: store),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('75.0'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.text('Togsoo Togs'));
      await tester.pumpAndSettle();

      expect(find.byType(StudentGradeDetailScreen), findsOneWidget);
      expect(find.text('Togsoo Togs · Дүн'), findsOneWidget);
      // One Math subject row with average — not two score rows.
      expect(find.text('NavМат'), findsOneWidget);
      expect(find.textContaining('75.0'), findsWidgets);
      expect(find.text('85 (B+)'), findsNothing);
      expect(find.text('65 (D)'), findsNothing);

      await tester.tap(find.text('NavМат'));
      await tester.pumpAndSettle();

      expect(find.text('NavМат · 1-р улирал'), findsOneWidget);
      expect(find.text('85 (B+)'), findsOneWidget);
      expect(find.text('65 (D)'), findsOneWidget);
      expect(find.text('2026 оны 7 сарын 29'), findsOneWidget);
      expect(find.text('2026 оны 7 сарын 28'), findsOneWidget);
    });
  });
}
