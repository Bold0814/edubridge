import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/subject_create_screen.dart';
import 'package:edubridge/screens/subjects_settings_screen.dart';
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
      id: 'sch-subj',
      name: 'Хичээл сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-subj',
      fullName: 'А. Админ',
      username: 'subjadmin',
      password: 'test123',
    );
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('opening SubjectCreateScreen does not throw', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SubjectCreateScreen(store: store)),
    );
    await tester.pump();
    expect(find.text('Хичээл нэмэх'), findsOneWidget);
    expect(find.text('Хичээлийн нэр'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving a subject returns true and list refreshes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SubjectsSettingsScreen(store: store)),
    );
    await tester.pump();

    await tester.tap(find.text('Хичээл нэмэх'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SubjectCreateScreen), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'SetupБиологи');
    await tester.tap(find.text('Хадгалах'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SubjectCreateScreen), findsNothing);
    expect(find.text('SetupБиологи'), findsOneWidget);
    expect(
      store.allSubjects.where((s) => s.name == 'SetupБиологи'),
      hasLength(1),
    );
  });

  test('no duplicate subject on repeated addSubject', () async {
    await store.addSubject('SetupХими');
    expect(
      () => store.addSubject('SetupХими'),
      throwsA(
        isA<ArgumentError>().having((e) => e.message, 'message', 'DUPLICATE'),
      ),
    );
    expect(store.allSubjects.where((s) => s.name == 'SetupХими'), hasLength(1));
  });

  test('reloadSubjectsForActiveSchool refreshes list', () async {
    await store.addSubject('SetupФизик');
    await store.reloadSubjectsForActiveSchool();
    expect(store.allSubjects.any((s) => s.name == 'SetupФизик'), isTrue);
  });

  testWidgets('disposing SubjectCreateScreen does not dispose AppStore', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SubjectCreateScreen(store: store)),
    );
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(store.isLoaded, isTrue);
    await store.reloadSubjectsForActiveSchool();
    expect(() => store.allSubjects, returnsNormally);
  });
}
