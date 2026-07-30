import 'package:edubridge/models/attendance_record.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/services/app_clock.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;
  late Student student;

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();

    student = const Student(
      id: '6А-hist-1',
      className: '6А',
      lastName: 'Бат',
      firstName: 'Болд',
      gender: StudentGender.male,
    );
    await store.addStudent(student);
  });

  tearDown(() async {
    AppClock.debugResetNow();
    await database.close();
  });

  test(
    'changing attendance appends history; today shows latest only',
    () async {
      AppClock.debugSetNow(() => DateTime(2026, 7, 29, 8, 0));
      final today = AppClock.todayKey();
      const subjectId = 42;

      await store.saveAttendance(
        AttendanceRecord.detailed(
          id: 'ignored-1',
          date: AppClock.displayLabel(today),
          dateKey: today,
          schoolId: AppStore.defaultSchoolId,
          className: '6А',
          subjectId: subjectId,
          entries: [
            StudentAttendanceEntry(
              studentId: student.id,
              studentName: student.fullName,
              status: AttendanceStatus.absent,
            ),
          ],
        ),
      );

      AppClock.debugSetNow(() => DateTime(2026, 7, 29, 8, 45));
      await store.saveAttendance(
        AttendanceRecord.detailed(
          id: 'ignored-2',
          date: AppClock.displayLabel(today),
          dateKey: today,
          schoolId: AppStore.defaultSchoolId,
          className: '6А',
          subjectId: subjectId,
          entries: [
            StudentAttendanceEntry(
              studentId: student.id,
              studentName: student.fullName,
              status: AttendanceStatus.late,
            ),
          ],
        ),
      );

      final rolls = store.attendanceFor('6А').where((r) {
        return r.subjectId == subjectId && r.matchesDateKey(today);
      }).toList();
      expect(rolls, hasLength(2));

      expect(store.todaysAttendanceStatus(student), AttendanceStatus.late);

      final history = store.attendanceEntriesForStudent(student);
      expect(history, hasLength(2));
      expect(history[0].status, AttendanceStatus.late);
      expect(history[1].status, AttendanceStatus.absent);
      expect(AppClock.formatTime(history[0].record.recordedAt), '08:45');
      expect(AppClock.formatTime(history[1].record.recordedAt), '08:00');
    },
  );

  test('identical re-save does not create duplicate history', () async {
    AppClock.debugSetNow(() => DateTime(2026, 7, 29, 9, 0));
    final today = AppClock.todayKey();

    final first = await store.saveAttendance(
      AttendanceRecord.detailed(
        id: 'a',
        date: AppClock.displayLabel(today),
        dateKey: today,
        schoolId: AppStore.defaultSchoolId,
        className: '6А',
        subjectId: 1,
        entries: [
          StudentAttendanceEntry(
            studentId: student.id,
            studentName: student.fullName,
            status: AttendanceStatus.present,
          ),
        ],
      ),
    );

    AppClock.debugSetNow(() => DateTime(2026, 7, 29, 9, 1));
    final second = await store.saveAttendance(
      AttendanceRecord.detailed(
        id: 'b',
        date: AppClock.displayLabel(today),
        dateKey: today,
        schoolId: AppStore.defaultSchoolId,
        className: '6А',
        subjectId: 1,
        entries: [
          StudentAttendanceEntry(
            studentId: student.id,
            studentName: student.fullName,
            status: AttendanceStatus.present,
          ),
        ],
      ),
    );

    expect(second.id, first.id);
    expect(store.attendanceEntriesForStudent(student), hasLength(1));
  });

  test('history is newest-first across days', () async {
    await store.saveAttendance(
      AttendanceRecord.detailed(
        id: '1',
        date: AppClock.displayLabel('2026-07-26'),
        dateKey: '2026-07-26',
        schoolId: AppStore.defaultSchoolId,
        className: '6А',
        subjectId: 1,
        recordedAt: DateTime(2026, 7, 26, 10),
        entries: [
          StudentAttendanceEntry(
            studentId: student.id,
            studentName: student.fullName,
            status: AttendanceStatus.absent,
          ),
        ],
      ),
    );
    await store.saveAttendance(
      AttendanceRecord.detailed(
        id: '2',
        date: AppClock.displayLabel('2026-07-28'),
        dateKey: '2026-07-28',
        schoolId: AppStore.defaultSchoolId,
        className: '6А',
        subjectId: 1,
        recordedAt: DateTime(2026, 7, 28, 11),
        entries: [
          StudentAttendanceEntry(
            studentId: student.id,
            studentName: student.fullName,
            status: AttendanceStatus.present,
          ),
        ],
      ),
    );
    await store.saveAttendance(
      AttendanceRecord.detailed(
        id: '3',
        date: AppClock.displayLabel('2026-07-27'),
        dateKey: '2026-07-27',
        schoolId: AppStore.defaultSchoolId,
        className: '6А',
        subjectId: 1,
        recordedAt: DateTime(2026, 7, 27, 12),
        entries: [
          StudentAttendanceEntry(
            studentId: student.id,
            studentName: student.fullName,
            status: AttendanceStatus.late,
          ),
        ],
      ),
    );

    final keys = store
        .attendanceEntriesForStudent(student)
        .map((r) => r.record.resolvedDateKey)
        .toList();
    expect(keys, ['2026-07-28', '2026-07-27', '2026-07-26']);
  });
}
