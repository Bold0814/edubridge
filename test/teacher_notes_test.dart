import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/teacher_note.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/learner_timeline.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;
  late Student student;
  late Teacher teacher;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();

    teacher = Teacher(
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

    student = const Student(
      id: '6А-note-1',
      className: '6А',
      lastName: 'Бат',
      firstName: 'Болд',
      gender: StudentGender.male,
    );
    await store.addStudent(student);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'teacher can create update delete notes in SQLite via AppStore',
    () async {
      final note = TeacherNote(
        id: store.nextTeacherNoteId(),
        studentId: student.id,
        teacherId: teacher.id,
        subjectId: store.activeSubjects.first.id,
        createdAt: DateTime(2026, 7, 24, 10).toIso8601String(),
        title: 'Гэрийн даалгавар',
        message: 'Дасгалаа давтана уу',
        priority: NotePriority.high,
        isVisibleToGuardian: true,
        isVisibleToStudent: true,
      );

      await store.addTeacherNote(note);
      expect(store.teacherNotesForClass('6А'), hasLength(1));

      final updated = note.copyWith(title: 'Шинэчилсэн', message: 'Сайжруул');
      await store.updateTeacherNote(updated);
      expect(store.teacherNotesForClass('6А').first.title, 'Шинэчилсэн');

      await store.deleteTeacherNote(note.id);
      expect(store.teacherNotesForClass('6А'), isEmpty);
    },
  );

  test('student and guardian see only visible notes newest first', () async {
    final older = TeacherNote(
      id: store.nextTeacherNoteId(),
      studentId: student.id,
      teacherId: teacher.id,
      createdAt: DateTime(2026, 7, 20).toIso8601String(),
      title: 'Хуучин',
      message: 'A',
      priority: NotePriority.normal,
      isVisibleToGuardian: true,
      isVisibleToStudent: true,
    );
    final newer = TeacherNote(
      id: store.nextTeacherNoteId(),
      studentId: student.id,
      teacherId: teacher.id,
      createdAt: DateTime(2026, 7, 24).toIso8601String(),
      title: 'Шинэ',
      message: 'B',
      priority: NotePriority.urgent,
      isVisibleToGuardian: true,
      isVisibleToStudent: true,
    );
    final studentOnly = TeacherNote(
      id: store.nextTeacherNoteId(),
      studentId: student.id,
      teacherId: teacher.id,
      createdAt: DateTime(2026, 7, 25).toIso8601String(),
      title: 'Зөвхөн сурагч',
      message: 'C',
      priority: NotePriority.normal,
      isVisibleToGuardian: false,
      isVisibleToStudent: true,
    );
    final guardianOnly = TeacherNote(
      id: store.nextTeacherNoteId(),
      studentId: student.id,
      teacherId: teacher.id,
      createdAt: DateTime(2026, 7, 26).toIso8601String(),
      title: 'Зөвхөн асран',
      message: 'D',
      priority: NotePriority.normal,
      isVisibleToGuardian: true,
      isVisibleToStudent: false,
    );

    await store.addTeacherNote(older);
    await store.addTeacherNote(newer);
    await store.addTeacherNote(studentOnly);
    await store.addTeacherNote(guardianOnly);

    final studentNotes = store.notesVisibleToStudent(student);
    expect(studentNotes.map((n) => n.title), [
      'Зөвхөн сурагч',
      'Шинэ',
      'Хуучин',
    ]);

    final guardianNotes = store.notesVisibleToGuardian(student);
    expect(guardianNotes.map((n) => n.title), [
      'Зөвхөн асран',
      'Шинэ',
      'Хуучин',
    ]);

    final studentTl = StudentTimeline.fromStore(store, student);
    expect(studentTl.data.latestTeacherNote?.title, 'Зөвхөн сурагч');

    final guardianTl = GuardianTimeline.fromStore(store, student);
    expect(guardianTl.data.latestTeacherNote?.title, 'Зөвхөн асран');
  });

  test('SQLite migration creates teacher_notes from v6', () async {
    final upgraded = await DatabaseService.instance.openInMemoryUpgradingFrom(
      6,
    );
    final rows = await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='teacher_notes'",
    );
    expect(rows, isNotEmpty);
    await upgraded.close();
  });
}
