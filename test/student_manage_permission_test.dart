import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/user_account.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/student_detail_screen.dart';
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
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedAdminSchool() async {
    await store.createSchool(
      id: 'sch-stu',
      name: 'Сурагч сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-stu',
      fullName: 'А. Админ',
      username: 'stuadmin',
      password: 'test123',
    );
    await store.addSchoolClass(name: 'S6А');
  }

  Future<void> loginAsTeacher(String username) async {
    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: 'sch-stu',
      fullName: 'Т. Багш',
    );
    await store.addTeacher(teacher);
    await store.addUserAccount(
      UserAccount(
        id: store.nextUserId(),
        username: username,
        passwordHash: '',
        role: AppRole.teacher,
        teacherId: teacher.id,
        createdAt: DateTime.now(),
      ),
      plainPassword: 'test123',
    );
    final account = store.userByUsername(username)!;
    final membership = store
        .activeMembershipsForUser(account.id)
        .firstWhere((m) => m.role == AppRole.teacher);
    await store.selectDevelopmentUser(account, rememberMe: false);
    await store.selectSchoolMembership(membership);
  }

  testWidgets('teacher sees no add/edit/delete student controls', (
    tester,
  ) async {
    await seedAdminSchool();
    await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('S6А'),
        className: 'S6А',
        lastName: 'Бат',
        firstName: 'Болд',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Ээж',
      guardianPhone: '99112233',
      relationship: 'Ээж',
    );
    await loginAsTeacher('onlyteacher');

    expect(store.canManageStudents, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: StudentListScreen(selectedClass: 'S6А', store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Засах'), findsNothing);
    expect(find.byTooltip('Устгах'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('admin sees management controls', (tester) async {
    await seedAdminSchool();
    await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('S6А'),
        className: 'S6А',
        lastName: 'Бат',
        firstName: 'Болд',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Ээж',
      guardianPhone: '99112233',
      relationship: 'Ээж',
    );

    expect(store.canManageStudents, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: StudentListScreen(selectedClass: 'S6А', store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byTooltip('Засах'), findsOneWidget);
    expect(find.byTooltip('Устгах'), findsOneWidget);
  });

  testWidgets('admin+teacher sees management controls', (tester) async {
    await seedAdminSchool();
    expect(store.hasAdminPermissionForActiveSchool, isTrue);
    expect(store.hasTeacherWorkspaceAccess, isTrue);
    expect(store.canManageStudents, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: StudentListScreen(selectedClass: 'S6А', store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('teacher cannot open student management routes directly', (
    tester,
  ) async {
    await seedAdminSchool();
    await loginAsTeacher('denyform');

    await tester.pumpWidget(
      MaterialApp(
        home: StudentFormScreen(
          classId: 'S6А',
          schoolId: 'sch-stu',
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Энэ үйлдлийг хийх эрхгүй байна.'), findsOneWidget);
    expect(find.text('Сурагчийн мэдээлэл'), findsNothing);
  });

  testWidgets('teacher can open read-only student detail', (tester) async {
    await seedAdminSchool();
    await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('S6А'),
        className: 'S6А',
        lastName: 'Сүх',
        firstName: 'Баатар',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Аав',
      guardianPhone: '88001122',
      relationship: 'Аав',
    );
    await loginAsTeacher('readdetail');

    await tester.pumpWidget(
      MaterialApp(
        home: StudentListScreen(selectedClass: 'S6А', store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сүх Баатар'));
    await tester.pumpAndSettle();

    expect(find.byType(StudentDetailScreen), findsOneWidget);
    expect(find.textContaining('Сүх Баатар'), findsWidgets);
  });

  test('teacher deleteStudent is denied in store', () async {
    await seedAdminSchool();
    final student = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('S6А'),
        className: 'S6А',
        lastName: 'Устгах',
        firstName: 'Оролдлого',
        gender: StudentGender.female,
      ),
      guardianFullName: 'Ээж',
      guardianPhone: '99110000',
      relationship: 'Ээж',
    );
    await loginAsTeacher('deletedeny');

    expect(
      () => store.deleteStudent('S6А', student.id),
      throwsA(isA<PermissionDeniedException>()),
    );
    expect(store.studentsFor('S6А'), hasLength(1));
  });
}
