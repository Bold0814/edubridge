import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/timetable.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/admin/admin_school_home_screen.dart';
import 'package:edubridge/screens/onboarding/school_setup_screen.dart';
import 'package:edubridge/screens/teacher_workspace_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:edubridge/widgets/session_menu_button.dart';
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
      id: 'sch-check',
      name: 'Checklist сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-check',
      fullName: 'А. Админ',
      username: 'checkadmin',
      password: 'Admin2026',
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> completeSetup() async {
    await store.addSchoolClass(name: 'CK1А');
    await store.addSubject('ChecklistХичээл');
    final teacher = store.activeTeachers.first;
    final subject = store.activeSubjects.firstWhere(
      (s) => s.name == 'ChecklistХичээл',
    );
    await store.saveClassAssignments(
      classId: 'CK1А',
      homeroomTeacherId: teacher.id,
      subjectTeacherIds: {subject.id: teacher.id},
    );
    final period = LessonPeriod(
      id: store.nextLessonPeriodId(),
      schoolId: 'sch-check',
      periodNumber: 1,
      startTime: '08:00',
      endTime: '08:45',
    );
    await store.addLessonPeriod(period);
    await store.addClassTimetable(
      ClassTimetable(
        id: store.nextClassTimetableId(),
        classId: 'CK1А',
        weekday: 1,
        periodId: period.id,
        subjectId: subject.id,
      ),
    );
  }

  test('checklist completion comes from real stored data', () async {
    var progress = store.schoolSetupProgress;
    expect(progress.hasSchoolInfo, isTrue);
    expect(progress.hasTeacher, isTrue);
    expect(progress.hasClass, isFalse);
    expect(progress.hasSubject, isFalse);
    expect(progress.hasAssignment, isFalse);
    expect(progress.hasTimetable, isFalse);
    expect(store.isSchoolSetupIncomplete, isTrue);

    await store.addSchoolClass(name: 'CK1А');
    progress = store.schoolSetupProgress;
    expect(progress.hasClass, isTrue);
    expect(store.isSchoolSetupIncomplete, isTrue);

    await store.addSubject('ChecklistХичээл');
    progress = store.schoolSetupProgress;
    expect(progress.hasSubject, isTrue);

    final teacher = store.activeTeachers.first;
    final subject = store.activeSubjects.firstWhere(
      (s) => s.name == 'ChecklistХичээл',
    );
    await store.saveClassAssignments(
      classId: 'CK1А',
      homeroomTeacherId: teacher.id,
      subjectTeacherIds: {subject.id: teacher.id},
    );
    progress = store.schoolSetupProgress;
    expect(progress.hasAssignment, isTrue);
    expect(store.isSchoolSetupIncomplete, isTrue);

    final period = LessonPeriod(
      id: store.nextLessonPeriodId(),
      schoolId: 'sch-check',
      periodNumber: 1,
      startTime: '08:00',
      endTime: '08:45',
    );
    await store.addLessonPeriod(period);
    await store.addClassTimetable(
      ClassTimetable(
        id: store.nextClassTimetableId(),
        classId: 'CK1А',
        weekday: 1,
        periodId: period.id,
        subjectId: subject.id,
      ),
    );
    progress = store.schoolSetupProgress;
    expect(progress.hasTimetable, isTrue);
    expect(progress.isComplete, isTrue);
    expect(store.isSchoolSetupIncomplete, isFalse);
  });

  testWidgets('incomplete school shows setup checklist shortcut', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AdminSchoolHomeScreen(store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('admin_setup_shortcut')), findsOneWidget);
    expect(find.byTooltip('Сургуулийн бэлтгэл'), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin_setup_shortcut')));
    await tester.pumpAndSettle();

    expect(find.byType(SchoolSetupScreen), findsOneWidget);
    expect(find.text('Сургуулийн бэлтгэл'), findsWidgets);
    expect(find.text('Сургуулийн мэдээлэл'), findsOneWidget);
    expect(find.text('Багш бүртгэх'), findsOneWidget);
    expect(find.text('Анги үүсгэх'), findsOneWidget);
    expect(find.text('Хичээл үүсгэх'), findsOneWidget);
    expect(find.text('Багш, ангийг оноох'), findsOneWidget);
    expect(find.text('Хичээлийн хуваарь оруулах'), findsOneWidget);
  });

  testWidgets('completed school hides top shortcut but keeps menu entry', (
    tester,
  ) async {
    await completeSetup();
    expect(store.isSchoolSetupIncomplete, isFalse);

    await tester.pumpWidget(
      MaterialApp(home: AdminSchoolHomeScreen(store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('admin_setup_shortcut')), findsNothing);

    await tester.tap(find.byType(SessionMenuButton));
    await tester.pumpAndSettle();
    expect(find.text('Бэлтгэлийн явц'), findsOneWidget);

    // Existing admin routes remain on the home screen.
    expect(find.text('Багш нар'), findsOneWidget);
    expect(find.text('Ангиуд'), findsOneWidget);
    expect(find.text('Хичээлүүд'), findsOneWidget);
    expect(find.text('Сурагчид'), findsOneWidget);
    expect(find.text('Хичээлийн хуваарь'), findsOneWidget);
    expect(find.text('Анги ба багш'), findsOneWidget);
    expect(find.text('Тохиргоо'), findsOneWidget);
  });

  testWidgets('normal teacher never sees setup action', (tester) async {
    await store.createTeacherWithOptionalLogin(
      teacher: Teacher(
        id: store.nextTeacherId(),
        schoolId: 'sch-check',
        fullName: 'Зөвхөн багш',
        phone: '99112233',
      ),
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );
    await store.logout();
    expect(
      await store.login(
        username: '99112233',
        password: 'Teach2026',
        rememberMe: false,
      ),
      LoginResult.success,
    );
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(store.authenticatedUser!.id).first,
    );

    expect(store.hasAdminPermissionForActiveSchool, isFalse);

    await tester.pumpWidget(
      MaterialApp(home: TeacherWorkspaceScreen(store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('admin_setup_shortcut')), findsNothing);
    expect(find.byTooltip('Сургуулийн бэлтгэл'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Бэлтгэлийн явц'), findsNothing);
    expect(find.text('Гарах'), findsOneWidget);
  });

  testWidgets('setup screen marks items complete from live store data', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: SchoolSetupScreen(store: store)));
    await tester.pump();

    // School info + admin teacher exist after createFirstSchoolAdmin.
    expect(find.byIcon(Icons.check), findsNWidgets(2));

    await store.addSchoolClass(name: 'CK1А');
    await store.addSubject('ChecklistХичээл');
    await tester.pump();
    expect(find.byIcon(Icons.check), findsNWidgets(4));

    final teacher = store.activeTeachers.first;
    await store.saveClassAssignments(
      classId: 'CK1А',
      homeroomTeacherId: teacher.id,
      subjectTeacherIds: const {},
    );
    await tester.pump();
    expect(find.byIcon(Icons.check), findsNWidgets(5));
  });
}
