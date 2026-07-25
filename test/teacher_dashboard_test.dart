import 'package:edubridge/models/announcement.dart';
import 'package:edubridge/models/attendance_record.dart';
import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/announcement_screen.dart';
import 'package:edubridge/screens/attendance_screen.dart';
import 'package:edubridge/screens/grade_screen.dart';
import 'package:edubridge/screens/home_screen.dart';
import 'package:edubridge/screens/student_form_screen.dart';
import 'package:edubridge/screens/student_list_screen.dart';
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
      id: 'sch-dash',
      name: 'Dashboard сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-dash',
      fullName: 'А. Админ',
      username: 'dashadmin',
      password: 'test123',
    );
    await store.addSchoolClass(name: 'DASH6А');
    await store.addSubject('DashМат');
    final subject = store.activeSubjects.firstWhere((s) => s.name == 'DashМат');
    final teacherId = store.activeContext.teacherId!;
    await store.saveClassAssignments(
      classId: 'DASH6А',
      homeroomTeacherId: teacherId,
      subjectTeacherIds: {subject.id: teacherId},
    );
    await store.setTeacherWorkspace(classId: 'DASH6А', subjectId: subject.id);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(selectedClass: 'DASH6А', store: store),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('each summary card is tappable', (tester) async {
    await pumpDashboard(tester);

    expect(find.text('Нийт сурагч'), findsOneWidget);
    expect(find.text('Ирц'), findsWidgets);
    expect(find.text('Ангийн дундаж'), findsOneWidget);
    expect(find.text('Шинэ зарлал'), findsOneWidget);
    expect(find.text('Харах'), findsNothing);
  });

  testWidgets('class selector is in the header with greeting', (tester) async {
    await pumpDashboard(tester);

    expect(find.textContaining('Сайн байна уу,'), findsOneWidget);
    expect(find.textContaining('DASH6А анги'), findsOneWidget);
    // Only one class selector on the dashboard.
    expect(find.textContaining('анги'), findsWidgets);
    expect(find.byTooltip('Анги сонгох'), findsOneWidget);
  });

  testWidgets('narrow viewport header does not overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpDashboard(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Сайн байна уу,'), findsOneWidget);
    expect(find.byTooltip('Анги сонгох'), findsOneWidget);
  });

  testWidgets('three compact action cards appear before summary cards', (
    tester,
  ) async {
    await pumpDashboard(tester);

    final journal = tester.getTopLeft(find.text('Хичээлийн журнал'));
    final homework = tester.getTopLeft(find.text('Даалгавар'));
    final advice = tester.getTopLeft(find.text('Зөвлөгөө'));
    final students = tester.getTopLeft(find.text('Нийт сурагч'));

    expect(journal.dy, lessThan(students.dy));
    expect(homework.dy, lessThan(students.dy));
    expect(advice.dy, lessThan(students.dy));
  });

  testWidgets('student card opens student list', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.text('Нийт сурагч'));
    await tester.pumpAndSettle();

    expect(find.byType(StudentListScreen), findsOneWidget);
    expect(find.textContaining('DASH6А · Сурагчид'), findsOneWidget);
  });

  testWidgets('attendance card opens attendance list', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.text('Ирц').first);
    await tester.pumpAndSettle();

    expect(find.byType(AttendanceScreen), findsOneWidget);
    expect(find.textContaining('DASH6А · Ирц'), findsOneWidget);
  });

  testWidgets('grade card opens grade overview', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.text('Ангийн дундаж'));
    await tester.pumpAndSettle();

    expect(find.byType(GradeScreen), findsOneWidget);
    expect(find.textContaining('DASH6А · Ангийн дүн'), findsOneWidget);
  });

  testWidgets('announcement card opens announcement list', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.text('Шинэ зарлал'));
    await tester.pumpAndSettle();

    expect(find.byType(AnnouncementScreen), findsOneWidget);
    expect(find.textContaining('DASH6А · Зарлал'), findsOneWidget);
  });

  testWidgets('dashboard does not show duplicate quick actions', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.text('Сурагчид'), findsNothing);
    expect(find.text('Ирц авах'), findsNothing);
    expect(find.text('Дүн оруулах'), findsNothing);
    expect(find.text('Шинэ зарлал'), findsOneWidget); // summary card title only
    expect(find.text('Бусад үйлдэл'), findsNothing);
    expect(find.text('Хичээлийн журнал'), findsOneWidget);
    expect(find.text('Даалгавар'), findsOneWidget);
    expect(find.text('Зөвлөгөө'), findsOneWidget);
  });

  testWidgets('all seven actions visible in standard phone viewport', (
    tester,
  ) async {
    // iPhone 14 Pro Max logical size ≈ 430 × 932
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpDashboard(tester);

    expect(find.text('Хичээлийн журнал'), findsOneWidget);
    expect(find.text('Даалгавар'), findsOneWidget);
    expect(find.text('Зөвлөгөө'), findsOneWidget);
    expect(find.text('Нийт сурагч'), findsOneWidget);
    expect(find.text('Ангийн дундаж'), findsOneWidget);
    expect(find.text('Шинэ зарлал'), findsOneWidget);
    expect(tester.getRect(find.text('Нийт сурагч')).bottom, lessThan(932));
    expect(tester.getRect(find.text('Зөвлөгөө')).bottom, lessThan(932));
  });

  testWidgets('no overflow on a smaller phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpDashboard(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Хичээлийн журнал'), findsOneWidget);
    expect(find.text('Нийт сурагч'), findsOneWidget);
    // 2 + 1 layout still shows all three actions without horizontal scroll.
    expect(find.text('Даалгавар'), findsOneWidget);
    expect(find.text('Зөвлөгөө'), findsOneWidget);
  });

  testWidgets('dashboard has no global floating + button', (tester) async {
    await pumpDashboard(tester);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('destination screens have exactly one add action', (
    tester,
  ) async {
    await pumpDashboard(tester);
    await tester.tap(find.text('Нийт сурагч'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Сурагч нэмэх'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ирц').first);
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Өнөөдрийн ирц авах'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ангийн дундаж'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Ангийн дүн оруулах'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Шинэ зарлал'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('back navigation returns to the dashboard', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.text('Нийт сурагч'));
    await tester.pumpAndSettle();
    expect(find.byType(StudentListScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.textContaining('Сайн байна уу,'), findsOneWidget);
    expect(find.text('Нийт сурагч'), findsOneWidget);
  });

  testWidgets('active class/subject context is preserved', (tester) async {
    await pumpDashboard(tester);
    expect(store.activeContext.classId, 'DASH6А');
    expect(store.activeContext.subjectId, isNotNull);
    expect(find.textContaining('DashМат'), findsOneWidget);
    expect(find.textContaining('DASH6А анги'), findsOneWidget);

    await tester.tap(find.text('Ангийн дундаж'));
    await tester.pumpAndSettle();
    expect(store.activeContext.classId, 'DASH6А');
    expect(store.activeContext.subjectId, isNotNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(store.activeContext.classId, 'DASH6А');
    expect(find.textContaining('DashМат'), findsOneWidget);
  });

  testWidgets('dashboard summary refreshes after returning from creation', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(find.text('0'), findsWidgets); // student count / announcements

    await tester.tap(find.text('Нийт сурагч'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(StudentFormScreen), findsOneWidget);

    // Create via store (form login fields covered in guardian_student_login_mvp_test).
    await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('DASH6А'),
        className: 'DASH6А',
        lastName: 'Бат',
        firstName: 'Болд',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Э. Ээж',
      guardianPhone: '99110022',
      relationship: 'Ээж',
    );
    Navigator.of(tester.element(find.byType(StudentFormScreen))).pop(true);
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(store.studentsFor('DASH6А'), hasLength(1));
    expect(find.text('1'), findsWidgets);
  });

  test(
    'summary values update from store after attendance and grades',
    () async {
      await store.addStudentWithRequiredGuardian(
        student: Student(
          id: store.nextStudentId('DASH6А'),
          className: 'DASH6А',
          lastName: 'Дорж',
          firstName: 'Сараа',
          gender: StudentGender.female,
        ),
        guardianFullName: 'Аав',
        guardianPhone: '88002233',
        relationship: 'Аав',
      );
      await store.addAttendance(
        'DASH6А',
        AttendanceRecord.detailed(
          id: store.nextAttendanceId(),
          date: '2026-07-25',
          className: 'DASH6А',
          entries: const [
            StudentAttendanceEntry(
              studentName: 'Дорж Сараа',
              status: AttendanceStatus.present,
            ),
          ],
        ),
      );
      final student = store.studentsFor('DASH6А').first;
      await store.addGrade(
        Grade(
          id: store.nextGradeId(),
          className: 'DASH6А',
          studentId: student.id,
          studentName: student.fullName,
          subject: 'DashМат',
          score: '90',
          term: '1-р улирал',
          letterGrade: 'A',
        ),
      );
      await store.addAnnouncement(
        Announcement(
          id: store.nextAnnouncementId(),
          schoolId: 'sch-dash',
          className: 'DASH6А',
          title: 'Шинэ',
          body: 'Бие',
          date: '2026-07-25',
          isFeatured: false,
        ),
      );

      final dash = store; // listenable already updated
      expect(dash.studentsFor('DASH6А'), hasLength(1));
      expect(dash.attendanceFor('DASH6А'), isNotEmpty);
      expect(dash.gradesFor('DASH6А'), isNotEmpty);
      expect(dash.announcementsFor('DASH6А'), isNotEmpty);
    },
  );
}
