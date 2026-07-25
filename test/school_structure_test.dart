import 'package:edubridge/models/class_subject_teacher.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;
  late EduBridgeRepository repository;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    repository = EduBridgeRepository(database);
    store = AppStore(repository);
    await store.load();
  });

  tearDown(() async {
    await database.close();
  });

  test('homeroom teacher lookup', () async {
    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: AppStore.defaultSchoolId,
      fullName: 'Д.Эрдэнэ',
    );
    await store.addTeacher(teacher);
    await store.saveClassAssignments(
      classId: '7А',
      homeroomTeacherId: teacher.id,
      subjectTeacherIds: const {},
    );

    expect(store.homeroomTeacherForClass('7А')?.fullName, 'Д.Эрдэнэ');
    expect(store.homeroomTeacherForClass('7Б'), isNull);
  });

  test('class + subject teacher lookup', () async {
    final erdene = Teacher(
      id: store.nextTeacherId(),
      schoolId: AppStore.defaultSchoolId,
      fullName: 'Д.Эрдэнэ',
    );
    final bolor = Teacher(
      id: store.nextTeacherId(),
      schoolId: AppStore.defaultSchoolId,
      fullName: 'Б.Болор',
    );
    await store.addTeacher(erdene);
    await store.addTeacher(bolor);

    final math = store.activeSubjects.firstWhere((s) => s.name == 'Математик');
    await store.saveClassAssignments(
      classId: '7А',
      homeroomTeacherId: erdene.id,
      subjectTeacherIds: {math.id: bolor.id},
    );

    expect(store.teacherForClassSubject('7А', math.id)?.fullName, 'Б.Болор');
    expect(
      store.teacherForClassSubjectName('7А', 'Математик')?.fullName,
      'Б.Болор',
    );
  });

  test('primary shortcut assignment', () async {
    final teacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: AppStore.defaultSchoolId,
      fullName: 'Д.Эрдэнэ',
    );
    await store.addTeacher(teacher);
    await store.saveClassAssignments(
      classId: '6А',
      homeroomTeacherId: teacher.id,
      subjectTeacherIds: const {},
    );

    await store.assignHomeroomToAllSubjects('6А');

    for (final subject in store.activeSubjects) {
      expect(store.teacherForClassSubject('6А', subject.id)?.id, teacher.id);
    }
  });

  test('dashboard greeting fallback', () async {
    expect(store.greetingLabelForClass('7А'), 'Багш');

    final home = Teacher(
      id: store.nextTeacherId(),
      schoolId: AppStore.defaultSchoolId,
      fullName: 'Д.Эрдэнэ',
    );
    final subjectTeacher = Teacher(
      id: store.nextTeacherId(),
      schoolId: AppStore.defaultSchoolId,
      fullName: 'Б.Болор',
    );
    await store.addTeacher(home);
    await store.addTeacher(subjectTeacher);

    await store.saveClassAssignments(
      classId: '7А',
      homeroomTeacherId: home.id,
      subjectTeacherIds: const {},
    );
    expect(store.greetingLabelForClass('7А'), 'Д.Эрдэнэ багш');

    final math = store.activeSubjects.firstWhere((s) => s.name == 'Математик');
    await store.saveClassAssignments(
      classId: '7А',
      homeroomTeacherId: home.id,
      subjectTeacherIds: {math.id: subjectTeacher.id},
    );
    store.setJournalSubject('7А', 'Математик');
    expect(store.greetingLabelForClass('7А'), 'Б.Болор багш');

    store.setJournalSubject('7А', 'Физик');
    expect(store.greetingLabelForClass('7А'), 'Д.Эрдэнэ багш');
  });

  test('missing teacher state', () async {
    expect(store.teacherForClassSubjectName('7А', 'Математик'), isNull);
    expect(store.homeroomTeacherForClass('7А'), isNull);

    final math = store.activeSubjects.firstWhere((s) => s.name == 'Математик');
    await store.saveClassAssignments(
      classId: '7А',
      homeroomTeacherId: null,
      subjectTeacherIds: {math.id: null},
    );
    expect(store.teacherForClassSubject('7А', math.id), isNull);
  });

  test('SQLite migration preserves existing data', () async {
    final upgraded = await DatabaseService.instance.openInMemoryUpgradingFrom(
      3,
    );
    addTearDown(upgraded.close);
    final repo = EduBridgeRepository(upgraded);

    final classes = await repo.loadClasses();
    expect(classes, containsAll(['6А', '7А']));

    final school = await repo.loadSchoolSettings();
    expect(school.academicYear, isNotEmpty);

    final schoolClasses = await repo.loadSchoolClasses();
    final sixA = schoolClasses.firstWhere((c) => c.name == '6А');
    expect(sixA.homeroomTeacherId, isNull);

    await repo.insertTeacher(
      const Teacher(
        id: 'tch-mig-1',
        schoolId: AppStore.defaultSchoolId,
        fullName: 'Ш.Шинэ',
      ),
    );
    await repo.replaceClassAssignments(
      classId: '6А',
      homeroomTeacherId: 'tch-mig-1',
      assignments: const <ClassSubjectTeacher>[],
    );
    final after = await repo.loadSchoolClasses();
    expect(
      after.firstWhere((c) => c.name == '6А').homeroomTeacherId,
      'tch-mig-1',
    );
  });
}
