import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/grade_create_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/firestore_grade_repository.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

class _PermissionDeniedStore extends MemoryGradeDocumentStore {
  @override
  Future<void> set(
    String path,
    Map<String, Object?> data, {
    bool merge = false,
  }) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );
  }
}

class _SlowCreateStore extends MemoryGradeDocumentStore {
  final gate = Completer<void>();
  int createAttempts = 0;

  @override
  Future<void> set(
    String path,
    Map<String, Object?> data, {
    bool merge = false,
  }) async {
    createAttempts++;
    await gate.future;
    await super.set(path, data, merge: merge);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late GradeDocumentStore documentStore;
  late AppStore store;
  late Student student;
  var phoneSeq = 77001000;

  Future<void> seed(GradeDocumentStore storeImpl) async {
    database = await DatabaseService.instance.openInMemoryForTest();
    documentStore = storeImpl;
    store = AppStore(
      EduBridgeRepository(database),
      gradeRepository: FirestoreGradeRepository(store: documentStore),
    );
    await store.load();
    phoneSeq = 77001000;

    await store.createSchool(
      id: 'sch-save',
      name: 'Хадгалалт',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-save',
      fullName: 'А. Админ',
      username: 'saveadmin',
      password: 'test123',
    );
    await store.addSchoolClass(name: 'S6А');
    await store.addSubject('SaveМат');
    student = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId('S6А'),
        className: 'S6А',
        lastName: 'Болд',
        firstName: 'Ану',
        gender: StudentGender.female,
      ),
      guardianFullName: 'Ээж',
      guardianPhone: '${phoneSeq++}',
      relationship: 'Ээж',
    );
  }

  tearDown(() async {
    await database.close();
  });

  test('valid grade saves through shared repository', () async {
    final memory = MemoryGradeDocumentStore();
    await seed(memory);
    final subject = store.subjectByName('SaveМат')!;
    final saved = await store.saveGrade(
      Grade(
        id: store.nextGradeId(),
        className: 'S6А',
        studentId: student.id,
        studentName: student.fullName,
        subject: subject.name,
        subjectId: subject.id,
        score: '87',
        term: '1-р улирал',
        termId: '1-р улирал',
      ),
      isUpdate: false,
    );

    expect(saved.score, '87');
    expect(saved.letterGrade, 'B+');
    expect(saved.studentId, student.id);
    expect(saved.subjectId, subject.id);
    expect(saved.teacherId, isNotNull);
    expect(saved.schoolId, 'sch-save');
    expect(store.gradesForStudent(student), hasLength(1));
    expect(
      await memory.get(FirestoreGradeRepository.pathFor(saved.id)),
      isNotNull,
    );
  });

  test('missing studentId fails visibly', () async {
    await seed(MemoryGradeDocumentStore());
    final prepared = store.prepareGradeForSave(
      Grade(
        id: 'gr-missing-student',
        className: 'S6А',
        studentId: '',
        studentName: student.fullName,
        subject: 'SaveМат',
        score: '80',
        term: '1-р улирал',
      ),
      isCreate: true,
    );
    expect(
      () => store.validatePreparedGrade(prepared),
      throwsA(
        isA<GradeSaveException>().having(
          (e) => e.message,
          'message',
          Grade.missingStudentIdMessage,
        ),
      ),
    );
  });

  test('missing subjectId fails visibly', () async {
    await seed(MemoryGradeDocumentStore());
    final prepared = store.prepareGradeForSave(
      Grade(
        id: 'gr-missing-subject',
        className: 'S6А',
        studentId: student.id,
        studentName: student.fullName,
        subject: 'UnknownSubject',
        score: '80',
        term: '1-р улирал',
      ),
      isCreate: true,
    );
    expect(prepared.subjectId, isNull);
    expect(
      () => store.validatePreparedGrade(prepared),
      throwsA(
        isA<GradeSaveException>().having(
          (e) => e.message,
          'message',
          Grade.missingSubjectIdMessage,
        ),
      ),
    );
  });

  test('missing termId fails visibly', () async {
    await seed(MemoryGradeDocumentStore());
    final prepared = store.prepareGradeForSave(
      Grade(
        id: 'gr-missing-term',
        className: 'S6А',
        studentId: student.id,
        studentName: student.fullName,
        subject: 'SaveМат',
        score: '80',
        term: '',
        termId: '',
      ),
      isCreate: true,
    );
    expect(
      () => store.validatePreparedGrade(prepared),
      throwsA(
        isA<GradeSaveException>().having(
          (e) => e.message,
          'message',
          Grade.missingTermIdMessage,
        ),
      ),
    );
  });

  test('Firestore permission-denied shows an error', () async {
    await seed(_PermissionDeniedStore());

    await expectLater(
      store.saveGrade(
        Grade(
          id: store.nextGradeId(),
          className: 'S6А',
          studentId: student.id,
          studentName: student.fullName,
          subject: 'SaveМат',
          score: '80',
          term: '1-р улирал',
        ),
        isUpdate: false,
      ),
      throwsA(
        isA<GradeSaveException>().having(
          (e) => e.message,
          'message',
          contains(Grade.permissionDeniedMessage),
        ),
      ),
    );
    expect(store.gradesForStudent(student), isEmpty);
  });

  testWidgets('permission-denied shows Mongolian snackbar on screen', (
    tester,
  ) async {
    await seed(_PermissionDeniedStore());
    final messengerKey = GlobalKey<ScaffoldMessengerState>();

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messengerKey,
        home: GradeCreateScreen(
          className: 'S6А',
          store: store,
          initialStudent: student,
          initialSubject: 'SaveМат',
          initialTerm: '1-р улирал',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '90');
    await tester.tap(find.text('Дүн хадгалах'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.textContaining(Grade.permissionDeniedMessage), findsOneWidget);
    expect(find.text('Дүн амжилттай хадгалагдлаа.'), findsNothing);
    expect(store.gradesForStudent(student), isEmpty);
  });

  testWidgets('double tap creates only one grade', (tester) async {
    final slow = _SlowCreateStore();
    await seed(slow);

    await tester.pumpWidget(
      MaterialApp(
        home: GradeCreateScreen(
          className: 'S6А',
          store: store,
          initialStudent: student,
          initialSubject: 'SaveМат',
          initialTerm: '1-р улирал',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '91');

    await tester.tap(find.text('Дүн хадгалах'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(slow.createAttempts, 1);

    slow.gate.complete();
    await tester.pumpAndSettle();

    expect(store.gradesForStudent(student), hasLength(1));
  });

  test('successful save refreshes the list from repository', () async {
    final memory = MemoryGradeDocumentStore();
    await seed(memory);
    final before = store.gradesForStudent(student).length;
    final saved = await store.saveGrade(
      Grade(
        id: store.nextGradeId(),
        className: 'S6А',
        studentId: student.id,
        studentName: student.fullName,
        subject: 'SaveМат',
        score: '93',
        term: '1-р улирал',
      ),
      isUpdate: false,
    );

    await store.reloadGrades();
    final after = store.gradesForStudent(student);
    expect(after.length, before + 1);
    expect(after.any((g) => g.id == saved.id && g.score == '93'), isTrue);
  });
}
