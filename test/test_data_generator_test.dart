import 'package:flutter_test/flutter_test.dart';
import 'package:edubridge/dev/test_data_generator.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/state/app_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TestDataGenerator builds 25 class names and markers', () {
    final names = TestDataGenerator.buildTestClassNames();
    expect(names, hasLength(25));
    expect(names.first, 'Тест 1А');
    expect(names[1], 'Тест 1Б');
    expect(names.last, startsWith('Тест '));
    expect(names.toSet(), hasLength(25));
  });

  test('TestDataGenerator inserts and deletes only TEST rows', () async {
    final database = await DatabaseService.instance.openInMemoryForTest();
    final repository = EduBridgeRepository(database);
    final store = AppStore(repository);
    await store.load();

    final realClassCount = store.classes.length;
    expect(realClassCount, greaterThan(0));

    final generator = TestDataGenerator(repository: repository, store: store);

    expect(await generator.hasTestData(), isFalse);

    final studentsResult = await generator.generateStudents();
    expect(studentsResult.classes, 25);
    expect(studentsResult.students, 1000);
    expect(await generator.hasTestData(), isTrue);

    // Seeded production classes remain.
    expect(
      store.classes.where((c) => !c.startsWith('Тест ')),
      hasLength(realClassCount),
    );

    final attendance = await generator.generateAttendance();
    expect(attendance.attendanceEntries, greaterThanOrEqualTo(5000));
    expect(attendance.attendanceRecords, 125);

    final extras = await generator.generateGradesHomeworkAnnouncements();
    expect(extras.grades, 3000); // 1000 * 3
    expect(extras.homework, 200); // 25 * 8
    expect(extras.announcements, 100); // 25 * 4

    await generator.deleteAllTestData();
    expect(await generator.hasTestData(), isFalse);
    expect(store.classes, hasLength(realClassCount));
    expect(store.studentsFor(store.classes.first), isEmpty);
  });
}
