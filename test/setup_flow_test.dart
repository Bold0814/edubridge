import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/guardian.dart';
import 'package:edubridge/models/school.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/class_timetable_settings_screen.dart';
import 'package:edubridge/screens/guardian_list_screen.dart';
import 'package:edubridge/screens/onboarding/school_setup_screen.dart';
import 'package:edubridge/screens/settings_screen.dart';
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
      id: 'sch-setup',
      name: 'Бэлтгэл сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-setup',
      fullName: 'А. Админ',
      username: 'setupadmin',
      password: 'test123',
    );
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('setup screen shows only four items', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SchoolSetupScreen(store: store)));
    await tester.pump();

    expect(find.text('Багш нар'), findsOneWidget);
    expect(find.text('Ангиуд'), findsOneWidget);
    expect(find.text('Хичээлүүд'), findsOneWidget);
    expect(find.text('Сурагчид'), findsOneWidget);

    expect(find.text('Анги ба багш'), findsNothing);
    expect(find.text('Асран хамгаалагчид'), findsNothing);
    expect(find.text('Хичээлийн хуваарь'), findsNothing);
    expect(find.text('Багшийн ажлын хэсэг'), findsNothing);
    expect(find.text('Ажлын хэсэг рүү орох'), findsOneWidget);
  });

  testWidgets('completion indicators for four essentials', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SchoolSetupScreen(store: store)));
    await tester.pump();

    expect(store.activeTeachers, isNotEmpty);

    await store.addSchoolClass(name: 'SU5А');
    await store.addSubject('SetupХичээл');
    await store.addStudent(
      Student(
        id: store.nextStudentId('SU5А'),
        className: 'SU5А',
        lastName: 'Бат',
        firstName: 'Болд',
        gender: StudentGender.male,
      ),
    );

    await tester.pump();
    expect(store.classes, contains('SU5А'));
    expect(store.activeSubjects.any((s) => s.name == 'SetupХичээл'), isTrue);
    expect(store.studentsInActiveSchool, isNotEmpty);
    expect(find.byIcon(Icons.check), findsWidgets);
  });

  test('class may select a homeroom teacher', () async {
    final teacher = store.activeTeachers.first;
    await store.addSchoolClass(name: 'SU7Б', homeroomTeacherId: teacher.id);
    expect(store.homeroomTeacherForClass('SU7Б')?.id, teacher.id);
  });

  test('student can be created without guardian', () async {
    await store.addSchoolClass(name: 'SU8А');
    final student = await store.addStudentWithOptionalGuardian(
      student: Student(
        id: store.nextStudentId('SU8А'),
        className: 'SU8А',
        lastName: 'Дорж',
        firstName: 'Сараа',
        gender: StudentGender.female,
      ),
    );
    expect(store.studentById(student.id), isNotNull);
    expect(
      store.guardianStudentLinks.where((l) => l.studentId == student.id),
      isEmpty,
    );
  });

  test('student can be created with guardian and link', () async {
    await store.addSchoolClass(name: 'SU9А');
    final student = await store.addStudentWithOptionalGuardian(
      student: Student(
        id: store.nextStudentId('SU9А'),
        className: 'SU9А',
        lastName: 'Ган',
        firstName: 'Болд',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Г. Ээж',
      guardianPhone: '99112233',
      relationship: 'Ээж',
    );

    final links = store.guardianStudentLinks
        .where((l) => l.studentId == student.id)
        .toList();
    expect(links, hasLength(1));
    expect(links.first.relationship, 'Ээж');
    final guardian = store.guardianById(links.first.guardianId);
    expect(guardian?.fullName, 'Г. Ээж');
    expect(guardian?.phone, '99112233');
    expect(guardian?.schoolId, 'sch-setup');
  });

  test('duplicate guardian by phone is reused within same school', () async {
    await store.addSchoolClass(name: 'SU10А');
    await store.addStudentWithOptionalGuardian(
      student: Student(
        id: store.nextStudentId('SU10А'),
        className: 'SU10А',
        lastName: 'Нэг',
        firstName: 'Хүүхэд',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Эхний',
      guardianPhone: '88001122',
      relationship: 'Ээж',
    );
    await store.addStudentWithOptionalGuardian(
      student: Student(
        id: store.nextStudentId('SU10А'),
        className: 'SU10А',
        lastName: 'Хоёр',
        firstName: 'Хүүхэд',
        gender: StudentGender.female,
      ),
      guardianFullName: 'Өөр нэр',
      guardianPhone: '88001122',
      relationship: 'Аав',
    );

    final samePhone = store.activeGuardians
        .where((g) => g.phone.trim() == '88001122')
        .toList();
    expect(samePhone, hasLength(1));
    expect(
      store.guardianStudentLinks.where(
        (l) => l.guardianId == samePhone.first.id,
      ),
      hasLength(2),
    );
  });

  test('guardians from another school are not reused', () async {
    await store.addSchool(const School(id: 'sch-other', name: 'Бусад'));
    await store.repository.insertSchoolSettings(
      SchoolSettings.emptyFor('sch-other').copyWith(schoolName: 'Бусад'),
    );
    await store.addGuardian(
      const Guardian(
        id: 'grd-other',
        fullName: 'Бусад эцэг',
        schoolId: 'sch-other',
        phone: '77778888',
      ),
    );

    await store.addSchoolClass(name: 'SU11А');
    await store.addStudentWithOptionalGuardian(
      student: Student(
        id: store.nextStudentId('SU11А'),
        className: 'SU11А',
        lastName: 'Локал',
        firstName: 'Хүүхэд',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Локал эцэг',
      guardianPhone: '77778888',
      relationship: 'Аав',
    );

    final matches = (await store.repository.loadGuardians())
        .where((g) => g.phone.trim() == '77778888')
        .toList();
    expect(matches, hasLength(2));
    expect(matches.where((g) => g.schoolId == 'sch-setup'), hasLength(1));
    expect(matches.where((g) => g.schoolId == 'sch-other'), hasLength(1));
    expect(
      store.findGuardianByPhoneInSchool('77778888')?.schoolId,
      'sch-setup',
    );
  });

  testWidgets('periods and guardians remain in Settings', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(store: store)));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Хичээлийн цаг'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Хичээлийн цаг'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Асран хамгаалагчийн холбоос засах'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Асран хамгаалагчийн холбоос засах'), findsOneWidget);

    // Class timetable lives on admin home; screens still exist.
    expect(ClassTimetableSettingsScreen(store: store), isA<Widget>());
    expect(GuardianListScreen(store: store), isA<Widget>());
  });

  test('existing teacher accounts still work', () async {
    await store.ensureDemoAccountsIfNeeded();
    final teacher = store.userByUsername('teacher1');
    expect(teacher?.role, AppRole.teacher);
    expect(
      await store.login(
        username: 'setupadmin',
        password: 'test123',
        rememberMe: false,
      ),
      LoginResult.success,
    );
  });
}
