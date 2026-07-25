import 'package:edubridge/models/account_status.dart';
import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/school.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/navigation/app_navigation.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/auth/login_screen.dart';
import 'package:edubridge/screens/guardian/guardian_child_selection_screen.dart';
import 'package:edubridge/screens/guardian/guardian_home_screen.dart';
import 'package:edubridge/screens/student_form_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/password_hasher.dart';
import 'package:edubridge/services/student_login_ids.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;
  late String schoolId;
  late String className;
  late String adminUsername;
  var seq = 0;

  setUp(() async {
    seq += 1;
    schoolId = 'sch-mvp-$seq';
    className = 'MVP$seq';
    adminUsername = 'mvpadmin$seq';
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();
    await store.createSchool(
      id: schoolId,
      name: 'MVP сургууль',
      code: '${100 + seq}',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: schoolId,
      fullName: 'А. Админ',
      username: adminUsername,
      password: 'test123',
    );
    await store.addSchoolClass(name: className);
  });

  tearDown(() async {
    await database.close();
  });

  Future<Student> createStudent({
    required String lastName,
    required String firstName,
    required String phone,
    String? forClass,
  }) {
    final cls = forClass ?? className;
    return store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId(cls),
        className: cls,
        lastName: lastName,
        firstName: firstName,
        gender: StudentGender.male,
      ),
      guardianFullName: 'Э. Эцэг',
      guardianPhone: phone,
      relationship: 'Аав',
      schoolId: schoolId,
    );
  }

  Future<void> activateGuardian(
    String phone,
    String studentCode,
    String pin,
  ) async {
    final lookup = store.lookupGuardianActivation(
      phone: phone,
      studentCode: studentCode,
    );
    expect(lookup.result, ActivationLookupResult.ok);
    await store.activateAccountWithPin(userId: lookup.account!.id, pin: pin);
  }

  Future<void> activateStudent(
    String studentCode,
    String guardianPhone,
    String pin,
  ) async {
    final lookup = store.lookupStudentActivation(
      studentCode: studentCode,
      guardianPhone: guardianPhone,
    );
    expect(lookup.result, ActivationLookupResult.ok);
    await store.activateAccountWithPin(userId: lookup.account!.id, pin: pin);
  }

  group('student code', () {
    test('code is generated automatically in school format', () async {
      final student = await createStudent(
        lastName: 'Бат',
        firstName: 'Болд',
        phone: '99112233',
      );
      expect(student.studentCode, isNotNull);
      expect(student.studentCode, matches(RegExp(r'^\d+-S\d{4}$')));
      expect(student.studentCode!.startsWith('${100 + seq}-S'), isTrue);
    });

    testWidgets('create form has no editable student-code or PIN fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StudentFormScreen(
            classId: className,
            schoolId: schoolId,
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Сурагчийн нэвтрэх эрх'), findsNothing);
      expect(find.text('Сурагчийн код'), findsNothing);
      expect(find.text('Асран хамгаалагчийн PIN'), findsNothing);
      expect(find.text('PIN давтах'), findsNothing);
    });

    test('code is unique within a school', () async {
      final a = await createStudent(
        lastName: 'Нэг',
        firstName: 'А',
        phone: '90001111',
      );
      final b = await createStudent(
        lastName: 'Хоёр',
        firstName: 'Б',
        phone: '90002222',
      );
      expect(a.studentCode, isNot(equals(b.studentCode)));
    });

    test('class change does not change code', () async {
      final student = await createStudent(
        lastName: 'Бат',
        firstName: 'Болд',
        phone: '99110000',
      );
      final code = student.studentCode!;
      expect(code.contains(className), isFalse);
      expect(StudentLoginIds.sequenceFromCode(code), isNotNull);

      final otherClass = '${className}B';
      await store.addSchoolClass(name: otherClass);
      final moved = Student(
        id: student.id,
        className: otherClass,
        lastName: student.lastName,
        firstName: student.firstName,
        gender: student.gender,
        studentCode: code,
        guardian: student.guardian,
      );
      await store.repository.updateStudent(moved);
      await store.load();
      expect(store.studentById(student.id)?.studentCode, code);
      expect(store.studentById(student.id)?.className, otherClass);
    });

    test('another school has its own prefix', () async {
      final first = await createStudent(
        lastName: 'Нэг',
        firstName: 'А',
        phone: '90001111',
      );
      final otherSchoolId = '$schoolId-b';
      final otherClass = '${className}X';
      await store.addSchool(
        School(id: otherSchoolId, name: 'B', code: '${200 + seq}'),
      );
      await store.repository.insertSchoolSettings(
        SchoolSettings.emptyFor(otherSchoolId).copyWith(schoolName: 'B'),
      );
      await store.addSchoolClass(name: otherClass, schoolId: otherSchoolId);
      await store.createFirstSchoolAdmin(
        schoolId: otherSchoolId,
        fullName: 'B Admin',
        username: 'badmin$seq',
        password: 'test123',
      );
      final other = await store.addStudentWithRequiredGuardian(
        student: Student(
          id: store.nextStudentId(otherClass),
          className: otherClass,
          lastName: 'Хоёр',
          firstName: 'Б',
          gender: StudentGender.female,
        ),
        guardianFullName: 'Ээж',
        guardianPhone: '90003333',
        relationship: 'Ээж',
        schoolId: otherSchoolId,
      );
      expect(first.studentCode!.split('-').first, '${100 + seq}');
      expect(other.studentCode!.split('-').first, '${200 + seq}');
    });

    test('existing students receive safe backfilled codes', () async {
      await store.addStudent(
        Student(
          id: store.nextStudentId(className),
          className: className,
          lastName: 'Хуучин',
          firstName: 'Сурагч',
          gender: StudentGender.female,
        ),
      );
      expect(store.studentsFor(className).first.studentCode, isNull);
      await store.backfillStudentCodesIfNeeded();
      final code = store.studentsFor(className).first.studentCode;
      expect(code, isNotNull);
      expect(code, matches(RegExp(r'^\d+-S\d{4}$')));
    });

    test('deleted codes are not reused', () async {
      final student = await createStudent(
        lastName: 'Устгах',
        firstName: 'Сурагч',
        phone: '95550001',
      );
      final deletedCode = student.studentCode!;
      await store.deleteStudent(className, student.id);
      final next = await createStudent(
        lastName: 'Дараа',
        firstName: 'Сурагч',
        phone: '95550002',
      );
      expect(next.studentCode, isNot(equals(deletedCode)));
      expect(
        await store.isStudentCodeTakenInSchool(deletedCode, schoolId: schoolId),
        isTrue,
      );
    });

    test('double allocation does not duplicate codes', () async {
      final futures = <Future<Student>>[
        createStudent(lastName: 'A', firstName: '1', phone: '91110001'),
        createStudent(lastName: 'B', firstName: '2', phone: '91110002'),
        createStudent(lastName: 'C', firstName: '3', phone: '91110003'),
      ];
      final students = await Future.wait(futures);
      final codes = students.map((s) => s.studentCode!).toSet();
      expect(codes, hasLength(3));
    });
  });

  group('PIN and activation', () {
    test('admin create starts accounts pending without PIN hash', () async {
      final student = await createStudent(
        lastName: 'Бат',
        firstName: 'Болд',
        phone: '99112233',
      );
      final studentAccount = store.accountForStudentId(student.id)!;
      final guardianAccount = store.findGuardianAccountByNormalizedPhone(
        '99112233',
      )!;
      expect(studentAccount.status, AccountStatus.pendingActivation);
      expect(guardianAccount.status, AccountStatus.pendingActivation);
      expect(studentAccount.passwordHash, isEmpty);
      expect(guardianAccount.passwordHash, isEmpty);
      expect(studentAccount.passwordHash.contains('1234'), isFalse);
    });

    test('valid activation stores only a hash', () async {
      final student = await createStudent(
        lastName: 'Бат',
        firstName: 'Болд',
        phone: '99112233',
      );
      await activateStudent(student.studentCode!, '99112233', '2468');
      final account = store.accountForStudentId(student.id)!;
      expect(account.status, AccountStatus.active);
      expect(account.passwordHash.contains('2468'), isFalse);
      expect(
        PasswordHasher.verifyPassword('2468', account.passwordHash),
        isTrue,
      );
    });

    test('activated account cannot reactivate', () async {
      final student = await createStudent(
        lastName: 'Бат',
        firstName: 'Болд',
        phone: '99112233',
      );
      await activateGuardian('99112233', student.studentCode!, '5678');
      final again = store.lookupGuardianActivation(
        phone: '99112233',
        studentCode: student.studentCode!,
      );
      expect(again.result, ActivationLookupResult.alreadyActive);
    });

    test('common PIN is rejected', () async {
      final student = await createStudent(
        lastName: 'Бат',
        firstName: 'Болд',
        phone: '99112233',
      );
      final lookup = store.lookupStudentActivation(
        studentCode: student.studentCode!,
        guardianPhone: '99112233',
      );
      expect(lookup.result, ActivationLookupResult.ok);
      expect(
        () => store.activateAccountWithPin(
          userId: lookup.account!.id,
          pin: '1234',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('guardian', () {
    test('phone + linked student code activates account', () async {
      final student = await createStudent(
        lastName: 'Бат',
        firstName: 'Болд',
        phone: '88-00 11-22',
      );
      final lookup = store.lookupGuardianActivation(
        phone: '88001122',
        studentCode: student.studentCode!,
      );
      expect(lookup.result, ActivationLookupResult.ok);
    });

    test('phone + unrelated code fails', () async {
      await createStudent(
        lastName: 'Бат',
        firstName: 'Болд',
        phone: '88001122',
      );
      final other = await createStudent(
        lastName: 'Бусад',
        firstName: 'Хүүхэд',
        phone: '88009999',
      );
      final lookup = store.lookupGuardianActivation(
        phone: '88001122',
        studentCode: other.studentCode!,
      );
      expect(lookup.result, ActivationLookupResult.mismatch);
    });

    test('normal login uses phone + PIN', () async {
      final student = await createStudent(
        lastName: 'Бат',
        firstName: 'Болд',
        phone: '+976 99-11 2233',
      );
      await activateGuardian('+97699112233', student.studentCode!, '5678');
      await store.logout();
      final result = await store.login(
        username: '+976 99-11 2233',
        password: '5678',
        rememberMe: false,
      );
      expect(result, LoginResult.success);
      expect(store.authenticatedUser?.role, AppRole.guardian);
    });

    test('multiple children use one guardian account and one PIN', () async {
      final first = await createStudent(
        lastName: 'Нэг',
        firstName: 'А',
        phone: '99110000',
      );
      await activateGuardian('99110000', first.studentCode!, '5678');
      final second = await createStudent(
        lastName: 'Хоёр',
        firstName: 'Б',
        phone: '99110000',
      );
      expect(
        store.findGuardianAccountByNormalizedPhone('99110000')!.passwordHash,
        isNotEmpty,
      );
      expect(
        store.accountForStudentId(second.id)!.status,
        AccountStatus.pendingActivation,
      );
      await store.logout();
      final result = await store.login(
        username: '99110000',
        password: '5678',
        rememberMe: false,
      );
      expect(result, LoginResult.success);
      await store.selectSchoolMembership(
        store.activeMembershipsForUser(store.authenticatedUser!.id).first,
      );
      expect(store.guardianPortalStudents, hasLength(2));
    });

    testWidgets('multiple children show selector', (tester) async {
      final first = await createStudent(
        lastName: 'Нэг',
        firstName: 'А',
        phone: '99110000',
      );
      await createStudent(lastName: 'Хоёр', firstName: 'Б', phone: '99110000');
      await activateGuardian('99110000', first.studentCode!, '5678');
      await store.logout();
      await store.login(
        username: '99110000',
        password: '5678',
        rememberMe: false,
      );
      await store.selectSchoolMembership(
        store.activeMembershipsForUser(store.authenticatedUser!.id).first,
      );
      final entry = await AppNavigation.resolveGuardianEntry(store);
      expect(entry, isA<GuardianChildSelectionScreen>());
      await tester.pumpWidget(MaterialApp(home: entry));
      await tester.pumpAndSettle();
      expect(find.text('Миний хүүхдүүд'), findsWidgets);
    });

    testWidgets('one child opens dashboard directly', (tester) async {
      final student = await createStudent(
        lastName: 'Бат',
        firstName: 'Болд',
        phone: '99110000',
      );
      await activateGuardian('99110000', student.studentCode!, '5678');
      await store.logout();
      await store.login(
        username: '99110000',
        password: '5678',
        rememberMe: false,
      );
      await store.selectSchoolMembership(
        store.activeMembershipsForUser(store.authenticatedUser!.id).first,
      );
      final entry = await AppNavigation.resolveGuardianEntry(store);
      expect(entry, isA<GuardianHomeScreen>());
    });
  });

  group('student', () {
    test('student code + linked guardian phone activates account', () async {
      final student = await createStudent(
        lastName: 'Бат',
        firstName: 'Болд',
        phone: '99110000',
      );
      final lookup = store.lookupStudentActivation(
        studentCode: student.studentCode!,
        guardianPhone: '99110000',
      );
      expect(lookup.result, ActivationLookupResult.ok);
    });

    test('normal login uses student code + PIN', () async {
      final student = await createStudent(
        lastName: 'Бат',
        firstName: 'Болд',
        phone: '99110000',
      );
      await activateStudent(student.studentCode!, '99110000', '2468');
      await store.logout();
      final result = await store.login(
        username: student.studentCode!,
        password: '2468',
        rememberMe: false,
      );
      expect(result, LoginResult.success);
      expect(store.authenticatedUser?.role, AppRole.student);
    });

    test('class change does not affect login', () async {
      final student = await createStudent(
        lastName: 'Бат',
        firstName: 'Болд',
        phone: '99110000',
      );
      final code = student.studentCode!;
      await activateStudent(code, '99110000', '2468');
      await store.logout();
      final result = await store.login(
        username: code,
        password: '2468',
        rememberMe: false,
      );
      expect(result, LoginResult.success);
    });

    test('pending account cannot login with PIN', () async {
      final student = await createStudent(
        lastName: 'Бат',
        firstName: 'Болд',
        phone: '99110000',
      );
      await store.logout();
      final result = await store.login(
        username: student.studentCode!,
        password: '2468',
        rememberMe: false,
      );
      expect(result, LoginResult.pendingActivation);
    });
  });

  group('login screen + admin', () {
    testWidgets('login screen has first-time access action', (tester) async {
      await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
      expect(find.text('Анх удаа нэвтрэх'), findsOneWidget);
      expect(
        find.text('Нэвтрэх нэр, утас эсвэл сурагчийн код'),
        findsOneWidget,
      );
    });

    test('teacher/admin login still works', () async {
      final admin = await store.login(
        username: adminUsername,
        password: 'test123',
        rememberMe: false,
      );
      expect(admin, LoginResult.success);
      expect(store.authenticatedUser?.role, AppRole.admin);
    });

    test(
      'existing student can receive pending login without PIN overwrite',
      () async {
        final student = await store.addStudentWithRequiredGuardian(
          student: Student(
            id: store.nextStudentId(className),
            className: className,
            lastName: 'Хуучин',
            firstName: 'Сурагч',
            gender: StudentGender.female,
          ),
          guardianFullName: 'Ээж',
          guardianPhone: '96660000',
          relationship: 'Ээж',
        );
        // Already has pending account from create — provision should fail.
        expect(store.accountForStudentId(student.id), isNotNull);
        expect(
          () => store.provisionLoginForExistingStudent(studentId: student.id),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              'STUDENT_ACCOUNT_EXISTS',
            ),
          ),
        );
      },
    );

    test('existing guardian PIN is not overwritten on second child', () async {
      final first = await createStudent(
        lastName: 'Нэг',
        firstName: 'А',
        phone: '96661111',
      );
      await activateGuardian('96661111', first.studentCode!, '5555');
      final hash = store
          .findGuardianAccountByNormalizedPhone('96661111')!
          .passwordHash;
      await createStudent(lastName: 'Хоёр', firstName: 'Б', phone: '96661111');
      expect(
        store.findGuardianAccountByNormalizedPhone('96661111')!.passwordHash,
        hash,
      );
      expect(PasswordHasher.verifyPassword('5555', hash), isTrue);
    });
  });
}
