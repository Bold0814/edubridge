import 'package:edubridge/models/homework.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/homework_create_screen.dart';
import 'package:edubridge/screens/homework_screen.dart';
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
      id: 'sch-hw',
      name: 'Даалгавар сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: 'sch-hw',
      fullName: 'А. Админ',
      username: 'hwadmin',
      password: 'test123',
    );
    await store.addSchoolClass(name: 'H6А');
    await store.addSchoolClass(name: 'H6Б');
    await store.addSubject('HwМат');
    await store.addSubject('HwГазар');
    await store.addSubject('HwТүүх');
    await store.addSubject('HwБио');
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> addHomework({
    required String className,
    required String subject,
    required String title,
  }) {
    return store.addHomework(
      Homework(
        id: store.nextHomeworkId(),
        className: className,
        subject: subject,
        title: title,
        description: 'Тайлбар',
        dueDate: '2026 оны 7 сарын 30',
        status: HomeworkStatus.pending,
      ),
    );
  }

  testWidgets('selected Mathematics context shows only Mathematics homework', (
    tester,
  ) async {
    await addHomework(
      className: 'H6А',
      subject: 'HwМат',
      title: 'Математик даалгавар',
    );
    await addHomework(
      className: 'H6А',
      subject: 'HwГазар',
      title: 'Газар зүй даалгавар',
    );
    await addHomework(
      className: 'H6А',
      subject: 'HwТүүх',
      title: 'Түүх даалгавар',
    );
    await addHomework(
      className: 'H6А',
      subject: 'HwБио',
      title: 'Биологи даалгавар',
    );
    await addHomework(className: 'H6Б', subject: 'HwМат', title: 'Бусад анги');

    final math = store.activeSubjects.firstWhere((s) => s.name == 'HwМат');
    await store.setTeacherWorkspace(classId: 'H6А', subjectId: math.id);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeworkScreen(
          selectedClass: 'H6А',
          store: store,
          subjectId: math.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('H6А · HwМат · Даалгавар'), findsOneWidget);
    expect(find.text('Математик даалгавар'), findsOneWidget);
    expect(find.text('Газар зүй даалгавар'), findsNothing);
    expect(find.text('Түүх даалгавар'), findsNothing);
    expect(find.text('Биологи даалгавар'), findsNothing);
    expect(find.text('Бусад анги'), findsNothing);
  });

  test('repository query excludes other subjects and classes', () async {
    await addHomework(
      className: 'H6А',
      subject: 'HwМат',
      title: 'Математик даалгавар',
    );
    await addHomework(
      className: 'H6А',
      subject: 'HwГазар',
      title: 'Газар зүй даалгавар',
    );
    await addHomework(className: 'H6Б', subject: 'HwМат', title: 'Бусад анги');

    final rows = await store.repository.loadHomeworkForClass(
      'H6А',
      subject: 'HwМат',
    );
    expect(rows, hasLength(1));
    expect(rows.first.title, 'Математик даалгавар');
  });

  test('another school class homework is excluded by store filter', () async {
    await store.createSchool(
      id: 'sch-other',
      name: 'Бусад сургууль',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    // Stay on sch-hw — H6А is local; foreign class name must not leak.
    await addHomework(
      className: 'H6А',
      subject: 'HwМат',
      title: 'Орон нутгийн',
    );
    final math = store.activeSubjects.firstWhere((s) => s.name == 'HwМат');
    final filtered = store.homeworkFor('H6А', subjectId: math.id);
    expect(filtered.map((h) => h.title), ['Орон нутгийн']);
    expect(store.homeworkFor('UnknownClass', subjectId: math.id), isEmpty);
  });

  testWidgets('null subject context shows all class homework', (tester) async {
    await addHomework(
      className: 'H6А',
      subject: 'HwМат',
      title: 'Математик даалгавар',
    );
    await addHomework(
      className: 'H6А',
      subject: 'HwГазар',
      title: 'Газар зүй даалгавар',
    );
    await store.setTeacherWorkspace(classId: 'H6А', subjectId: null);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeworkScreen(selectedClass: 'H6А', store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('H6А · Даалгавар'), findsOneWidget);
    expect(find.text('HwМат'), findsOneWidget);
    expect(find.text('HwГазар'), findsOneWidget);
    expect(find.text('Математик даалгавар'), findsOneWidget);
    expect(find.text('Газар зүй даалгавар'), findsOneWidget);
  });

  testWidgets('new homework inherits active subject and reloads filter', (
    tester,
  ) async {
    await addHomework(
      className: 'H6А',
      subject: 'HwГазар',
      title: 'Газар зүй даалгавар',
    );
    final math = store.activeSubjects.firstWhere((s) => s.name == 'HwМат');
    await store.setTeacherWorkspace(classId: 'H6А', subjectId: math.id);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeworkScreen(
          selectedClass: 'H6А',
          store: store,
          subjectId: math.id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Газар зүй даалгавар'), findsNothing);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(HomeworkCreateScreen), findsOneWidget);
    expect(find.text('HwМат'), findsWidgets);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Шинэ даалгавар');
    await tester.enterText(fields.at(2), 'Дэлгэрэнгүй');
    await tester.tap(find.widgetWithText(FilledButton, 'Даалгавар хадгалах'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeworkScreen), findsOneWidget);
    expect(find.text('Шинэ даалгавар'), findsOneWidget);
    expect(find.text('Газар зүй даалгавар'), findsNothing);
    final saved = store.homeworkFor('H6А', subjectId: math.id);
    expect(saved, hasLength(1));
    expect(saved.first.subject, 'HwМат');
  });

  test('journal subject alone does not filter without subjectId', () async {
    await addHomework(
      className: 'H6А',
      subject: 'HwМат',
      title: 'Математик даалгавар',
    );
    await addHomework(
      className: 'H6А',
      subject: 'HwГазар',
      title: 'Газар зүй даалгавар',
    );
    await store.setTeacherWorkspace(classId: 'H6А', subjectId: null);
    store.setJournalSubject('H6А', 'HwМат');

    // Without subjectId, class homework stays unfiltered (journal is ignored).
    final all = store.homeworkFor('H6А');
    expect(all, hasLength(2));
  });
}
