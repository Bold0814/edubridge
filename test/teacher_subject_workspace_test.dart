import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/homework.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/teacher_workspace_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();
    await store.createSchool(
      id: 'sch-tw',
      name: 'Workspace сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-tw',
      fullName: 'А. Админ',
      username: 'twadmin',
      password: 'Admin2026',
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<({Teacher teacher, String classId, int mongolId, int mathId})>
  seedTeacherWithAssignments() async {
    await store.addSchoolClass(name: 'TW6А');
    await store.addSchoolClass(name: 'TW6Б');
    await store.addSchoolClass(name: 'TW7А');
    await store.addSubject('TWМонгол');
    await store.addSubject('TWМатематик');
    final mongol = store.activeSubjects.firstWhere((s) => s.name == 'TWМонгол');
    final math = store.activeSubjects.firstWhere(
      (s) => s.name == 'TWМатематик',
    );

    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: 'sch-tw',
      fullName: 'М. Багш',
      phone: '99110011',
    );
    await store.createTeacherWithOptionalLogin(
      teacher: teacher,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );

    await store.saveClassAssignments(
      classId: 'TW6А',
      homeroomTeacherId: teacher.id,
      subjectTeacherIds: {mongol.id: teacher.id},
    );
    await store.saveClassAssignments(
      classId: 'TW6Б',
      homeroomTeacherId: null,
      subjectTeacherIds: {mongol.id: teacher.id},
    );
    await store.saveClassAssignments(
      classId: 'TW7А',
      homeroomTeacherId: null,
      subjectTeacherIds: {
        mongol.id: teacher.id,
        math.id: store.activeTeachers.first.id,
      },
    );

    await store.addStudent(
      Student(
        id: store.nextStudentId('TW6А'),
        className: 'TW6А',
        lastName: 'Бат',
        firstName: 'Болд',
        gender: StudentGender.male,
      ),
    );

    await store.logout();
    await store.login(
      username: '99110011',
      password: 'Teach2026',
      rememberMe: false,
    );
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(store.authenticatedUser!.id).first,
    );

    return (
      teacher: store.teacherById(teacher.id)!,
      classId: 'TW6А',
      mongolId: mongol.id,
      mathId: math.id,
    );
  }

  testWidgets('section label is Хичээл заадаг ангиуд', (tester) async {
    await seedTeacherWithAssignments();
    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Хичээл заадаг ангиуд'), findsOneWidget);
    expect(find.text('Хичээл заадаг'), findsNothing);
    expect(find.text('Анги удирдсан'), findsOneWidget);
    expect(find.text('Миний хуваарь'), findsOneWidget);
  });

  testWidgets('teacher sees all and only assigned class-subject rows', (
    tester,
  ) async {
    await seedTeacherWithAssignments();
    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('TW6А анги'), findsWidgets); // homeroom + teaching
    expect(find.text('TW6Б анги'), findsOneWidget);
    expect(find.text('TW7А анги'), findsOneWidget);
    expect(find.text('TWМонгол'), findsNWidgets(3));
    expect(find.text('TWМатематик'), findsNothing);

    final rows = store.teachingAssignmentsForActiveTeacher();
    expect(rows.map((r) => '${r.schoolClass.name}:${r.subject.name}'), [
      'TW6А:TWМонгол',
      'TW6Б:TWМонгол',
      'TW7А:TWМонгол',
    ]);
  });

  test('subject workspace receives correct classId and subjectId', () async {
    final seeded = await seedTeacherWithAssignments();
    await store.setTeacherWorkspace(
      classId: seeded.classId,
      subjectId: seeded.mongolId,
    );
    expect(store.activeContext.classId, 'TW6А');
    expect(store.activeContext.subjectId, seeded.mongolId);
    expect(store.activeSubjectName, 'TWМонгол');
  });

  test(
    'homeroom teacher can view overall grades but not edit other subject',
    () async {
      final seeded = await seedTeacherWithAssignments();
      await store.logout();
      await store.login(
        username: 'twadmin',
        password: 'Admin2026',
        rememberMe: false,
      );
      await store.selectSchoolMembership(
        store.activeMembershipsForUser(store.authenticatedUser!.id).first,
      );
      final student = store.studentsFor('TW6А').first;
      await store.addGrade(
        Grade(
          id: store.nextGradeId(),
          className: 'TW6А',
          studentId: student.id,
          studentName: student.fullName,
          subject: 'TWМатематик',
          score: '88',
          term: '1-р улирал',
        ),
      );

      await store.logout();
      await store.login(
        username: '99110011',
        password: 'Teach2026',
        rememberMe: false,
      );
      await store.selectSchoolMembership(
        store.activeMembershipsForUser(store.authenticatedUser!.id).first,
      );

      await store.setTeacherWorkspace(classId: 'TW6А', subjectId: null);
      expect(store.isHomeroomOverviewOf('TW6А'), isTrue);
      expect(store.teacherCanAccessClass('TW6А'), isTrue);
      expect(store.gradesFor('TW6А'), isNotEmpty);

      expect(
        store.teacherCanEditClassSubject(
          classId: 'TW6А',
          subjectId: seeded.mathId,
        ),
        isFalse,
      );
      expect(
        () => store.addGrade(
          Grade(
            id: store.nextGradeId(),
            className: 'TW6А',
            studentId: student.id,
            studentName: student.fullName,
            subject: 'TWМатематик',
            score: '90',
            term: '1-р улирал',
          ),
        ),
        throwsA(
          isA<PermissionDeniedException>().having(
            (e) => e.message,
            'message',
            contains(Grade.permissionDeniedMessage),
          ),
        ),
      );
    },
  );

  test('assigned subject teacher can edit that subject grades', () async {
    final seeded = await seedTeacherWithAssignments();
    await store.setTeacherWorkspace(
      classId: 'TW6А',
      subjectId: seeded.mongolId,
    );
    expect(
      store.teacherCanEditClassSubject(
        classId: 'TW6А',
        subjectId: seeded.mongolId,
      ),
      isTrue,
    );
    final student = store.studentsFor('TW6А').first;
    await store.addGrade(
      Grade(
        id: store.nextGradeId(),
        className: 'TW6А',
        studentId: student.id,
        studentName: student.fullName,
        subject: 'TWМонгол',
        score: '91',
        term: '1-р улирал',
      ),
    );
    expect(
      store
          .gradesFor('TW6А')
          .any((g) => g.subject == 'TWМонгол' && g.score == '91'),
      isTrue,
    );
  });

  test('teacher cannot edit unrelated class or subject', () async {
    final seeded = await seedTeacherWithAssignments();
    await store.setTeacherWorkspace(
      classId: 'TW6Б',
      subjectId: seeded.mongolId,
    );
    expect(
      store.teacherCanEditClassSubject(
        classId: 'TW7А',
        subjectId: seeded.mathId,
      ),
      isFalse,
    );
    expect(store.teacherCanWriteAttendance('TW6А'), isFalse);
    expect(store.teacherCanWriteAttendance('TW6Б'), isTrue);
  });

  test(
    'combined homeroom+subject teacher can edit only assigned subject',
    () async {
      final seeded = await seedTeacherWithAssignments();
      await store.setTeacherWorkspace(classId: 'TW6А', subjectId: null);
      expect(store.isHomeroomOverviewOf('TW6А'), isTrue);
      expect(store.teacherCanEditActiveSubjectInClass('TW6А'), isFalse);

      await store.setTeacherWorkspace(
        classId: 'TW6А',
        subjectId: seeded.mongolId,
      );
      expect(store.isHomeroomOverviewOf('TW6А'), isFalse);
      expect(store.teacherCanEditActiveSubjectInClass('TW6А'), isTrue);
      expect(
        store.teacherCanEditClassSubject(
          classId: 'TW6А',
          subjectId: seeded.mathId,
        ),
        isFalse,
      );
    },
  );

  test('attendance homework journal use assignment permission', () async {
    final seeded = await seedTeacherWithAssignments();
    final student = store.studentsFor('TW6А').first;

    await store.setTeacherWorkspace(classId: 'TW6А', subjectId: null);
    expect(store.teacherCanWriteAttendance('TW6А'), isFalse);

    await store.setTeacherWorkspace(
      classId: 'TW6А',
      subjectId: seeded.mongolId,
    );
    expect(store.teacherCanWriteAttendance('TW6А'), isTrue);

    await store.addHomework(
      Homework(
        id: store.nextHomeworkId(),
        className: 'TW6А',
        subject: 'TWМонгол',
        title: 'Уншлага',
        description: 'Хуудас 12',
        dueDate: '2026 оны 7 сарын 28',
        status: HomeworkStatus.pending,
      ),
    );

    expect(
      () => store.addHomework(
        Homework(
          id: store.nextHomeworkId(),
          className: 'TW6А',
          subject: 'TWМатематик',
          title: 'Бодлого',
          description: '1-5',
          dueDate: '2026 оны 7 сарын 28',
          status: HomeworkStatus.pending,
        ),
      ),
      throwsA(isA<PermissionDeniedException>()),
    );

    expect(
      store.teacherCanEditSubjectNamed(
        classId: 'TW6А',
        subjectName: 'TWМонгол',
      ),
      isTrue,
    );
    expect(student.id, isNotEmpty);
  });
}
