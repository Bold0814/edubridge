import 'package:edubridge/models/guardian.dart';
import 'package:edubridge/models/school.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/navigation/app_navigation.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/class_list_screen.dart';
import 'package:edubridge/screens/guardian/guardian_child_selection_screen.dart';
import 'package:edubridge/screens/guardian/guardian_home_screen.dart';
import 'package:edubridge/screens/student_form_screen.dart';
import 'package:edubridge/screens/student_list_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/phone_normalizer.dart';
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
      id: 'sch-flow',
      name: 'Урсгал сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-flow',
      fullName: 'А. Админ',
      username: 'flowadmin',
      password: 'test123',
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> fillStudentBasics(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Бат');
    await tester.enterText(fields.at(1), 'Болд');
    await tester.tap(find.byType(DropdownButtonFormField<StudentGender>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Эрэгтэй').last);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Сурагч нэмэх');
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('class card shows Анги удирдсан багш', (tester) async {
    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: 'sch-flow',
      fullName: 'А.Энх-Амгалан',
    );
    await store.addTeacher(teacher);
    await store.addSchoolClass(name: 'CS12А', homeroomTeacherId: teacher.id);

    await tester.pumpWidget(MaterialApp(home: ClassListScreen(store: store)));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Анги удирдсан багш: А.Энх-Амгалан'),
      findsOneWidget,
    );
  });

  testWidgets('missing homeroom teacher state', (tester) async {
    await store.addSchoolClass(name: 'CS11Б');

    await tester.pumpWidget(MaterialApp(home: ClassListScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Анги удирдсан багш сонгоогүй'), findsOneWidget);
  });

  testWidgets('empty student screen has exactly one add action', (
    tester,
  ) async {
    await store.addSchoolClass(name: 'CS10А');

    await tester.pumpWidget(
      MaterialApp(
        home: StudentListScreen(selectedClass: 'CS10А', store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Сурагч бүртгээгүй байна'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Сурагч нэмэх'), findsNothing);
  });

  testWidgets('non-empty student screen has exactly one add action', (
    tester,
  ) async {
    await store.addSchoolClass(name: 'CS10Б');
    await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('CS10Б'),
        className: 'CS10Б',
        lastName: 'Бат',
        firstName: 'Болд',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Э. Ээж',
      guardianPhone: '99110011',
      relationship: 'Ээж',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentListScreen(selectedClass: 'CS10Б', store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Сурагч нэмэх'), findsNothing);
    expect(find.text('Сурагч бүртгээгүй байна'), findsNothing);
  });

  testWidgets('student form receives classId and has no class dropdown', (
    tester,
  ) async {
    await store.addSchoolClass(name: 'CS11А');

    await tester.pumpWidget(
      MaterialApp(
        home: StudentFormScreen(
          classId: 'CS11А',
          schoolId: 'sch-flow',
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Анги: CS11А'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<StudentGender>), findsOneWidget);
    expect(
      find.byType(DropdownButtonFormField<String>, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.textContaining('CS11А анги'), findsNothing);
    // No class dropdown — only gender + relationship.
    expect(
      find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField,
        skipOffstage: false,
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('student cannot save without surname', (tester) async {
    await store.addSchoolClass(name: 'CS9А');
    await tester.pumpWidget(
      MaterialApp(
        home: StudentFormScreen(
          classId: 'CS9А',
          schoolId: 'sch-flow',
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), 'Болд');
    await tapSave(tester);

    expect(find.text('Овгоо оруулна уу'), findsOneWidget);
    expect(store.studentsFor('CS9А'), isEmpty);
  });

  testWidgets('student cannot save without first name', (tester) async {
    await store.addSchoolClass(name: 'CS9Б');
    await tester.pumpWidget(
      MaterialApp(
        home: StudentFormScreen(
          classId: 'CS9Б',
          schoolId: 'sch-flow',
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Бат');
    await tapSave(tester);

    expect(find.text('Нэрээ оруулна уу'), findsOneWidget);
    expect(store.studentsFor('CS9Б'), isEmpty);
  });

  testWidgets('student cannot save without gender', (tester) async {
    await store.addSchoolClass(name: 'CS9В');
    await tester.pumpWidget(
      MaterialApp(
        home: StudentFormScreen(
          classId: 'CS9В',
          schoolId: 'sch-flow',
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField, skipOffstage: false);
    await tester.enterText(fields.at(0), 'Бат');
    await tester.enterText(fields.at(1), 'Болд');
    await tester.scrollUntilVisible(
      fields.at(4),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(fields.at(4), 'Ээж');
    await tester.enterText(fields.at(5), '99001122');
    final relationship = find.byType(
      DropdownButtonFormField<String>,
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(
      relationship,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(relationship);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ээж').last);
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(find.text('Хүйсээ сонгоно уу', skipOffstage: false), findsWidgets);
    expect(store.studentsFor('CS9В'), isEmpty);
  });

  testWidgets('student cannot save without guardian name', (tester) async {
    await store.addSchoolClass(name: 'CS8А');
    await tester.pumpWidget(
      MaterialApp(
        home: StudentFormScreen(
          classId: 'CS8А',
          schoolId: 'sch-flow',
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await fillStudentBasics(tester);
    await tapSave(tester);

    expect(
      find.text('Асран хамгаалагчийн нэрийг оруулна уу', skipOffstage: false),
      findsOneWidget,
    );
    expect(store.studentsFor('CS8А'), isEmpty);
  });

  testWidgets('student cannot save without guardian phone', (tester) async {
    await store.addSchoolClass(name: 'CS8Б');
    await tester.pumpWidget(
      MaterialApp(
        home: StudentFormScreen(
          classId: 'CS8Б',
          schoolId: 'sch-flow',
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await fillStudentBasics(tester);
    await tester.enterText(
      find.byType(TextFormField, skipOffstage: false).at(4),
      'Э. Ээж',
    );
    await tapSave(tester);

    expect(
      find.text('Асран хамгаалагчийн утсыг оруулна уу', skipOffstage: false),
      findsOneWidget,
    );
    expect(store.studentsFor('CS8Б'), isEmpty);
  });

  testWidgets('student cannot save without guardian relationship', (
    tester,
  ) async {
    await store.addSchoolClass(name: 'CS8В');
    await tester.pumpWidget(
      MaterialApp(
        home: StudentFormScreen(
          classId: 'CS8В',
          schoolId: 'sch-flow',
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await fillStudentBasics(tester);
    final fields = find.byType(TextFormField, skipOffstage: false);
    await tester.scrollUntilVisible(
      fields.at(4),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(fields.at(4), 'Э. Ээж');
    await tester.enterText(fields.at(5), '99001122');
    await tapSave(tester);

    expect(
      find.text('Хүүхэдтэй ямар холбоотойг сонгоно уу', skipOffstage: false),
      findsOneWidget,
    );
    expect(store.studentsFor('CS8В'), isEmpty);
  });

  test('phone normalizer strips spaces and hyphens', () {
    expect(PhoneNormalizer.normalize(' 99-11 22 33 '), '99112233');
    expect(PhoneNormalizer.normalize('+976 9911-2233'), '+97699112233');
  });

  test('normalized same-school guardian phone reuses guardian', () async {
    await store.addSchoolClass(name: 'CS7А');
    await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('CS7А'),
        className: 'CS7А',
        lastName: 'Нэг',
        firstName: 'Хүүхэд',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Эхний',
      guardianPhone: '88-00 11-22',
      relationship: 'Ээж',
    );
    await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('CS7А'),
        className: 'CS7А',
        lastName: 'Хоёр',
        firstName: 'Хүүхэд',
        gender: StudentGender.female,
      ),
      guardianFullName: 'Өөр нэр',
      guardianPhone: '88001122',
      relationship: 'Аав',
    );

    final samePhone = store.activeGuardians
        .where((g) => PhoneNormalizer.normalize(g.phone) == '88001122')
        .toList();
    expect(samePhone, hasLength(1));
    expect(
      store.guardianStudentLinks.where(
        (l) => l.guardianId == samePhone.first.id,
      ),
      hasLength(2),
    );
  });

  test('same phone in another school is not reused', () async {
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

    await store.addSchoolClass(name: 'CS7Б');
    await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('CS7Б'),
        className: 'CS7Б',
        lastName: 'Локал',
        firstName: 'Хүүхэд',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Локал эцэг',
      guardianPhone: '77778888',
      relationship: 'Аав',
    );

    final matches = (await store.repository.loadGuardians())
        .where((g) => PhoneNormalizer.normalize(g.phone) == '77778888')
        .toList();
    expect(matches, hasLength(2));
    expect(matches.where((g) => g.schoolId == 'sch-flow'), hasLength(1));
    expect(matches.where((g) => g.schoolId == 'sch-other'), hasLength(1));
  });

  test('guardian-student link is created', () async {
    await store.addSchoolClass(name: 'CS6А');
    final student = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('CS6А'),
        className: 'CS6А',
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
  });

  test('one guardian may link to multiple children', () async {
    await store.addSchoolClass(name: 'CS6Б');
    await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('CS6Б'),
        className: 'CS6Б',
        lastName: 'А',
        firstName: 'Нэг',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Нэг асран',
      guardianPhone: '90001111',
      relationship: 'Ээж',
    );
    await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('CS6Б'),
        className: 'CS6Б',
        lastName: 'Б',
        firstName: 'Хоёр',
        gender: StudentGender.female,
      ),
      guardianFullName: 'Нэг асран',
      guardianPhone: '90001111',
      relationship: 'Ээж',
    );

    final guardian = store.findGuardianByPhoneInSchool('90001111')!;
    expect(
      store.guardianStudentLinks.where((l) => l.guardianId == guardian.id),
      hasLength(2),
    );
  });

  test('double save does not create duplicate student or guardian', () async {
    await store.addSchoolClass(name: 'CS5А');
    await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('CS5А'),
        className: 'CS5А',
        lastName: 'Давхар',
        firstName: 'Хадгал',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Давхар эцэг',
      guardianPhone: '91112222',
      relationship: 'Аав',
    );
    await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('CS5А'),
        className: 'CS5А',
        lastName: 'Давхар',
        firstName: 'Хоёр',
        gender: StudentGender.female,
      ),
      guardianFullName: 'Давхар эцэг',
      guardianPhone: '9111-2222',
      relationship: 'Аав',
    );

    expect(
      store.activeGuardians.where(
        (g) => PhoneNormalizer.normalize(g.phone) == '91112222',
      ),
      hasLength(1),
    );
    expect(store.studentsFor('CS5А'), hasLength(2));
  });

  test('one linked child skips child selection', () async {
    await store.addSchoolClass(name: 'CS4А');
    final student = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('CS4А'),
        className: 'CS4А',
        lastName: 'Ганц',
        firstName: 'Хүүхэд',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Ганц эцэг',
      guardianPhone: '96667777',
      relationship: 'Аав',
    );
    final account = store.findGuardianAccountByNormalizedPhone('96667777')!;
    await store.activateAccountWithPin(userId: account.id, pin: '5678');
    await store.selectDevelopmentUser(
      store.userById(account.id)!,
      rememberMe: false,
    );
    final membership = store.activeMembershipsForUser(account.id).first;
    await store.selectSchoolMembership(membership);

    final next = await AppNavigation.resolveGuardianEntry(store);
    expect(next, isA<GuardianHomeScreen>());
    expect(store.guardianStudentId, student.id);
  });

  test('multiple linked children show child selection', () async {
    await store.addSchoolClass(name: 'CS4Б');
    await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('CS4Б'),
        className: 'CS4Б',
        lastName: 'Олон',
        firstName: 'Нэг',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Олон эцэг',
      guardianPhone: '95556666',
      relationship: 'Аав',
    );
    await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('CS4Б'),
        className: 'CS4Б',
        lastName: 'Олон',
        firstName: 'Хоёр',
        gender: StudentGender.female,
      ),
      guardianFullName: 'Олон эцэг',
      guardianPhone: '95556666',
      relationship: 'Аав',
    );
    final account = store.findGuardianAccountByNormalizedPhone('95556666')!;
    await store.activateAccountWithPin(userId: account.id, pin: '5678');
    await store.selectDevelopmentUser(
      store.userById(account.id)!,
      rememberMe: false,
    );
    final membership = store.activeMembershipsForUser(account.id).first;
    await store.selectSchoolMembership(membership);

    final next = await AppNavigation.resolveGuardianEntry(store);
    expect(next, isA<GuardianChildSelectionScreen>());
  });
}
