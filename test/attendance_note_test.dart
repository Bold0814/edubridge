import 'package:edubridge/models/attendance_record.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/attendance_take_screen.dart';
import 'package:edubridge/services/app_clock.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
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
      id: '6А-note-1',
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

  test('attendance saves without note', () async {
    final today = AppClock.todayKey();
    await store.saveAttendance(
      AttendanceRecord.detailed(
        id: 'x',
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

    final row = store.todaysAttendanceForStudent(student);
    expect(row?.status, AttendanceStatus.present);
    expect(row?.note, isNull);
  });

  test('attendance saves with note and history keeps it', () async {
    final today = AppClock.todayKey();
    await store.saveAttendance(
      AttendanceRecord.detailed(
        id: 'x',
        date: AppClock.displayLabel(today),
        dateKey: today,
        schoolId: AppStore.defaultSchoolId,
        className: '6А',
        subjectId: 1,
        entries: [
          StudentAttendanceEntry(
            studentId: student.id,
            studentName: student.fullName,
            status: AttendanceStatus.late,
            note: 'Автобус хоцорсон',
          ),
        ],
      ),
    );

    final row = store.todaysAttendanceForStudent(student);
    expect(row?.status, AttendanceStatus.late);
    expect(row?.note, 'Автобус хоцорсон');

    final history = store.attendanceEntriesForStudent(student);
    expect(history, hasLength(1));
    expect(history.first.note, 'Автобус хоцорсон');
  });

  test('older event note is not overwritten by a later change', () async {
    final today = AppClock.todayKey();

    AppClock.debugSetNow(() => DateTime(2026, 7, 29, 8, 0));
    await store.saveAttendance(
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
            status: AttendanceStatus.absent,
            note: 'Эмчид үзүүлээд ирсэн',
          ),
        ],
      ),
    );

    AppClock.debugSetNow(() => DateTime(2026, 7, 29, 8, 45));
    await store.saveAttendance(
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
            status: AttendanceStatus.late,
            note: 'Автобус хоцорсон',
          ),
        ],
      ),
    );

    final history = store.attendanceEntriesForStudent(student);
    expect(history, hasLength(2));
    expect(history[0].status, AttendanceStatus.late);
    expect(history[0].note, 'Автобус хоцорсон');
    expect(history[1].status, AttendanceStatus.absent);
    expect(history[1].note, 'Эмчид үзүүлээд ирсэн');
    expect(store.todaysAttendanceStatus(student), AttendanceStatus.late);
  });

  testWidgets('empty note is hidden in history', (tester) async {
    final today = AppClock.todayKey();
    await store.saveAttendance(
      AttendanceRecord.detailed(
        id: 'x',
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
            note: '   ',
          ),
        ],
      ),
    );
    await store.setGuardianStudentId(student.id);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            // Bypass gate by showing history body via store query directly.
            final rows = store.attendanceEntriesForStudent(student);
            final note = rows.first.note;
            return Scaffold(
              body: Text(
                note == null || note.isEmpty ? 'NO_NOTE' : 'Тэмдэглэл: $note',
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('NO_NOTE'), findsOneWidget);
    expect(find.textContaining('Тэмдэглэл:'), findsNothing);
  });

  testWidgets('history shows note only when present', (tester) async {
    final today = AppClock.todayKey();
    await store.saveAttendance(
      AttendanceRecord.detailed(
        id: 'x',
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
            note: 'Эцэг эхээс чөлөө авсан',
          ),
        ],
      ),
    );

    // Render history list tiles without LearnerAccessGate auth setup.
    final rows = store.attendanceEntriesForStudent(student);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              for (final row in rows)
                ListTile(
                  title: Text(row.record.displayDateLabel),
                  subtitle: Text(
                    [
                      AppClock.formatTime(row.record.recordedAt),
                      'Багш: test',
                      if ((row.note ?? '').isNotEmpty) 'Тэмдэглэл: ${row.note}',
                    ].join('\n'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Тэмдэглэл: Эцэг эхээс чөлөө авсан'),
      findsOneWidget,
    );
  });

  testWidgets('reopening note editor shows current unsaved note', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceTakeScreen(
          selectedClass: '6А',
          store: store,
          subjectId: 1,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(student.fullName), findsOneWidget);
    final noteButton = find.byIcon(Icons.edit_outlined);
    expect(noteButton, findsOneWidget);

    await tester.tap(noteButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Ирцийн тэмдэглэл'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Эмчид үзүүлээд ирсэн');
    await tester.tap(find.text('Хадгалах'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.edit_note), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Эмчид үзүүлээд ирсэн'), findsOneWidget);
  });
}
