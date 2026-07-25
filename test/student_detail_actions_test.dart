import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/homework.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/homework_screen.dart';
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
  var phoneSeq = 99111000;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();
    phoneSeq = 99111000;
    await store.createSchool(
      id: 'sch-detail',
      name: 'Дэлгэрэнгүй сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-detail',
      fullName: 'А. Админ',
      username: 'detailadmin',
      password: 'test123',
    );
    await store.addSchoolClass(name: 'D6А');
    await store.addSubject('DetailМат');
    await store.addSubject('DetailГазар');
    student = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('D6А'),
        className: 'D6А',
        lastName: 'Бат',
        firstName: 'Болд',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Ээж',
      guardianPhone: '${phoneSeq++}',
      relationship: 'Ээж',
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpDetail(
    WidgetTester tester, {
    int? subjectId,
    String? selectedSubject,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentDetailScreen(
          studentId: student.id,
          selectedClass: 'D6А',
          store: store,
          subjectId: subjectId,
          selectedSubject: selectedSubject,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Дүн харах has working onPressed and opens subject grades', (
    tester,
  ) async {
    final math = store.activeSubjects.firstWhere((s) => s.name == 'DetailМат');
    await store.addGrade(
      Grade(
        id: store.nextGradeId(),
        className: 'D6А',
        studentId: student.id,
        studentName: student.fullName,
        subject: 'DetailМат',
        score: '88',
        term: '1-р улирал',
      ),
    );
    await store.addGrade(
      Grade(
        id: store.nextGradeId(),
        className: 'D6А',
        studentId: student.id,
        studentName: student.fullName,
        subject: 'DetailГазар',
        score: '70',
        term: '1-р улирал',
      ),
    );
    await store.setTeacherWorkspace(classId: 'D6А', subjectId: math.id);

    await pumpDetail(tester, subjectId: math.id);
    await tester.tap(find.text('Дүн харах'));
    await tester.pumpAndSettle();

    expect(find.byType(StudentGradeDetailScreen), findsOneWidget);
    expect(find.text('88 (B+)'), findsOneWidget);
    expect(find.text('70 (C)'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(StudentDetailScreen), findsOneWidget);
  });

  testWidgets('null subject opens subject-average list', (tester) async {
    await store.addGrade(
      Grade(
        id: store.nextGradeId(),
        className: 'D6А',
        studentId: student.id,
        studentName: student.fullName,
        subject: 'DetailМат',
        score: '90',
        term: '1-р улирал',
      ),
    );
    await store.setTeacherWorkspace(classId: 'D6А', subjectId: null);

    await pumpDetail(tester);
    await tester.tap(find.text('Дүн харах'));
    await tester.pumpAndSettle();

    expect(find.byType(StudentGradeDetailScreen), findsOneWidget);
    expect(find.text('DetailМат'), findsOneWidget);
    expect(find.text('DetailГазар'), findsOneWidget);
    expect(find.text('90.0'), findsOneWidget);
  });

  testWidgets('Даалгавар харах opens subject-filtered homework', (
    tester,
  ) async {
    final math = store.activeSubjects.firstWhere((s) => s.name == 'DetailМат');
    await store.addHomework(
      Homework(
        id: store.nextHomeworkId(),
        className: 'D6А',
        subject: 'DetailМат',
        title: 'Мат даалгавар',
        description: 'А',
        dueDate: '2026 оны 8 сарын 1',
        status: HomeworkStatus.pending,
      ),
    );
    await store.addHomework(
      Homework(
        id: store.nextHomeworkId(),
        className: 'D6А',
        subject: 'DetailГазар',
        title: 'Газар даалгавар',
        description: 'Б',
        dueDate: '2026 оны 8 сарын 1',
        status: HomeworkStatus.pending,
      ),
    );
    await store.setTeacherWorkspace(classId: 'D6А', subjectId: math.id);

    await pumpDetail(tester, subjectId: math.id);
    await tester.tap(find.text('Даалгавар харах'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeworkScreen), findsOneWidget);
    expect(find.text('Мат даалгавар'), findsOneWidget);
    expect(find.text('Газар даалгавар'), findsNothing);
    expect(store.activeContext.studentId, isNull);
    expect(student.id, isNotEmpty);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(StudentDetailScreen), findsOneWidget);
    expect(find.text('Бат Болд'), findsOneWidget);
  });
}
