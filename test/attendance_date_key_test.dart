import 'package:edubridge/models/attendance_record.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/learner_timeline.dart';
import 'package:edubridge/services/school_date.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:edubridge/widgets/summaries/attendance_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppStore store;
  late Student student;

  String yesterdayKey() {
    final ub = SchoolDate.nowInUlaanbaatar();
    final yesterday = DateTime(
      ub.year,
      ub.month,
      ub.day,
    ).subtract(const Duration(days: 1));
    return SchoolDate.formatDateKey(yesterday);
  }

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();

    student = const Student(
      id: '6А-att-1',
      className: '6А',
      lastName: 'Бат',
      firstName: 'Болд',
      gender: StudentGender.male,
    );
    await store.addStudent(student);
    await store.setGuardianStudentId(student.id);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'yesterday record exists, today does not -> dashboard Бүртгэгдээгүй',
    () async {
      final today = SchoolDate.localDateKey();
      final yesterday = yesterdayKey();
      final ub = SchoolDate.nowInUlaanbaatar();
      final yesterdayDate = DateTime(
        ub.year,
        ub.month,
        ub.day,
      ).subtract(const Duration(days: 1));

      await store.addAttendance(
        '6А',
        AttendanceRecord.detailed(
          id: store.nextAttendanceId(),
          date: SchoolDate.displayLabel(yesterday),
          dateKey: yesterday,
          schoolId: AppStore.defaultSchoolId,
          className: '6А',
          recordedAt: yesterdayDate,
          entries: [
            StudentAttendanceEntry(
              studentId: student.id,
              studentName: student.fullName,
              status: AttendanceStatus.present,
            ),
          ],
        ),
      );

      expect(store.todaysAttendanceForStudent(student), isNull);
      expect(store.todaysAttendanceStatus(student), isNull);
      expect(store.attendanceStatusForStudentOnDate(student, today), isNull);
      expect(
        store.attendanceStatusForStudentOnDate(student, yesterday),
        AttendanceStatus.present,
      );

      final timeline = GuardianTimeline.fromStore(store, student).data;
      expect(timeline.todaysAttendance, isNull);
      expect(timeline.attendancePresentCount, 0);
      expect(timeline.attendanceLateCount, 0);
      expect(timeline.attendanceAbsentCount, 0);

      final history = store.attendanceEntriesForStudent(student);
      expect(history, hasLength(1));
      expect(history.first.record.matchesDateKey(yesterday), isTrue);
      expect(history.first.record.matchesDateKey(today), isFalse);
    },
  );

  test(
    'today query never falls back to yesterday when today is missing',
    () async {
      final today = SchoolDate.localDateKey();
      final yesterday = yesterdayKey();
      final ub = SchoolDate.nowInUlaanbaatar();
      final yesterdayDate = DateTime(
        ub.year,
        ub.month,
        ub.day,
      ).subtract(const Duration(days: 1));

      await store.addAttendance(
        '6А',
        AttendanceRecord.detailed(
          id: store.nextAttendanceId(),
          date: SchoolDate.displayLabel(yesterday),
          dateKey: yesterday,
          schoolId: AppStore.defaultSchoolId,
          className: '6А',
          recordedAt: yesterdayDate,
          entries: [
            StudentAttendanceEntry(
              studentId: student.id,
              studentName: student.fullName,
              status: AttendanceStatus.present,
            ),
          ],
        ),
      );

      // Same query the badge and Өнөөдрийн ирц screen share.
      expect(store.todaysAttendanceForStudent(student), isNull);
      expect(store.todaysAttendanceStatus(student), isNull);

      final studentTl = StudentTimeline.fromStore(store, student).data;
      final guardianTl = GuardianTimeline.fromStore(store, student).data;
      expect(studentTl.todaysAttendance, isNull);
      expect(guardianTl.todaysAttendance, isNull);
      expect(studentTl.attendancePresentCount, 0);
      expect(studentTl.attendanceLateCount, 0);
      expect(studentTl.attendanceAbsentCount, 0);
      expect(guardianTl.attendancePresentCount, 0);

      final history = store.attendanceEntriesForStudent(student);
      expect(history, hasLength(1));
      expect(history.first.record.matchesDateKey(yesterday), isTrue);
      expect(history.any((r) => r.record.matchesDateKey(today)), isFalse);
    },
  );

  test(
    'today record exists -> dashboard and detail show same status',
    () async {
      final today = SchoolDate.localDateKey();
      await store.addAttendance(
        '6А',
        AttendanceRecord.detailed(
          id: store.nextAttendanceId(),
          date: SchoolDate.displayLabel(today),
          dateKey: today,
          schoolId: AppStore.defaultSchoolId,
          className: '6А',
          recordedAt: DateTime.now(),
          entries: [
            StudentAttendanceEntry(
              studentId: student.id,
              studentName: student.fullName,
              status: AttendanceStatus.late,
            ),
          ],
        ),
      );

      expect(store.todaysAttendanceStatus(student), AttendanceStatus.late);
      expect(
        store.attendanceStatusForStudentOnDate(student, today),
        AttendanceStatus.late,
      );
      expect(
        store.todaysAttendanceForStudent(student)?.status,
        store.todaysAttendanceStatus(student),
      );

      final history = store.attendanceEntriesForStudent(student);
      expect(history.first.status, AttendanceStatus.late);
      expect(history.first.record.matchesDateKey(today), isTrue);
      expect(
        GuardianTimeline.fromStore(store, student).data.todaysAttendance,
        AttendanceStatus.late,
      );
      expect(
        StudentTimeline.fromStore(store, student).data.todaysAttendance,
        AttendanceStatus.late,
      );
    },
  );

  test('Asia/Ulaanbaatar dateKey uses UTC+8 wall clock', () {
    // 2026-07-23 20:00 UTC → 2026-07-24 04:00 in Ulaanbaatar.
    final utcEvening = DateTime.utc(2026, 7, 23, 20);
    expect(SchoolDate.localDateKey(utcEvening), '2026-07-24');

    // 2026-07-23 15:00 UTC → still 2026-07-23 in Ulaanbaatar (23:00).
    final utcAfternoon = DateTime.utc(2026, 7, 23, 15);
    expect(SchoolDate.localDateKey(utcAfternoon), '2026-07-23');

    final ub = SchoolDate.nowInUlaanbaatar(utcEvening);
    expect(ub.year, 2026);
    expect(ub.month, 7);
    expect(ub.day, 24);
  });

  test('history includes today and sorts newest first', () async {
    final today = SchoolDate.localDateKey();
    final yesterday = yesterdayKey();
    final ub = SchoolDate.nowInUlaanbaatar();
    final twoDaysAgoDate = DateTime(
      ub.year,
      ub.month,
      ub.day,
    ).subtract(const Duration(days: 2));
    final twoDaysAgo = SchoolDate.formatDateKey(twoDaysAgoDate);

    await store.addAttendance(
      '6А',
      AttendanceRecord.detailed(
        id: store.nextAttendanceId(),
        date: SchoolDate.displayLabel(twoDaysAgo),
        dateKey: twoDaysAgo,
        schoolId: AppStore.defaultSchoolId,
        className: '6А',
        recordedAt: twoDaysAgoDate,
        entries: [
          StudentAttendanceEntry(
            studentId: student.id,
            studentName: student.fullName,
            status: AttendanceStatus.absent,
          ),
        ],
      ),
    );
    await store.addAttendance(
      '6А',
      AttendanceRecord.detailed(
        id: store.nextAttendanceId(),
        date: SchoolDate.displayLabel(yesterday),
        dateKey: yesterday,
        schoolId: AppStore.defaultSchoolId,
        className: '6А',
        recordedAt: DateTime(
          ub.year,
          ub.month,
          ub.day,
        ).subtract(const Duration(days: 1)),
        entries: [
          StudentAttendanceEntry(
            studentId: student.id,
            studentName: student.fullName,
            status: AttendanceStatus.present,
          ),
        ],
      ),
    );
    await store.addAttendance(
      '6А',
      AttendanceRecord.detailed(
        id: store.nextAttendanceId(),
        date: SchoolDate.displayLabel(today),
        dateKey: today,
        schoolId: AppStore.defaultSchoolId,
        className: '6А',
        recordedAt: DateTime.now(),
        entries: [
          StudentAttendanceEntry(
            studentId: student.id,
            studentName: student.fullName,
            status: AttendanceStatus.late,
          ),
        ],
      ),
    );

    final history = store.attendanceEntriesForStudent(student);
    expect(history, hasLength(3));
    expect(history.first.record.matchesDateKey(today), isTrue);
    expect(history[1].record.matchesDateKey(yesterday), isTrue);
    expect(history.last.record.matchesDateKey(twoDaysAgo), isTrue);
    expect(store.todaysAttendanceStatus(student), AttendanceStatus.late);
  });

  testWidgets('returning from detail refreshes the summary', (tester) async {
    final today = SchoolDate.localDateKey();
    await store.addAttendance(
      '6А',
      AttendanceRecord.detailed(
        id: store.nextAttendanceId(),
        date: SchoolDate.displayLabel(today),
        dateKey: today,
        schoolId: AppStore.defaultSchoolId,
        className: '6А',
        recordedAt: DateTime.now(),
        entries: [
          StudentAttendanceEntry(
            studentId: student.id,
            studentName: student.fullName,
            status: AttendanceStatus.present,
          ),
        ],
      ),
    );

    var rebuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            rebuilds++;
            // Badge + detail use the same today-only query.
            final status = store.todaysAttendanceStatus(student);
            final detail = store.todaysAttendanceForStudent(student);
            return Scaffold(
              body: Column(
                children: [
                  AttendanceSummaryCard(todaysStatus: status),
                  Text(
                    detail == null
                        ? 'Бүртгэгдээгүй'
                        : detail.record.displayDateLabel,
                  ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Өнөөдрийн ирц'),
                              leading: BackButton(
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            body: Text(
                              store
                                      .todaysAttendanceForStudent(student)
                                      ?.record
                                      .displayDateLabel ??
                                  'Бүртгэгдээгүй',
                            ),
                          ),
                        ),
                      );
                      store.refreshCalendarBoundViews();
                    },
                    child: const Text('open-detail'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ирсэн'), findsWidgets);
    expect(find.text(SchoolDate.displayLabel(today)), findsWidgets);
    final before = rebuilds;

    await tester.tap(find.text('open-detail'));
    await tester.pumpAndSettle();
    expect(find.text('Өнөөдрийн ирц'), findsOneWidget);
    expect(find.text(SchoolDate.displayLabel(today)), findsWidgets);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(rebuilds, greaterThan(before));
    expect(find.text('Ирсэн'), findsWidgets);
    expect(store.todaysAttendanceStatus(student), AttendanceStatus.present);
  });

  test('legacy Mongolian date without dateKey still matches today', () async {
    final ub = SchoolDate.nowInUlaanbaatar();
    final label = '${ub.year} оны ${ub.month} сарын ${ub.day}';
    await store.addAttendance(
      '6А',
      AttendanceRecord.detailed(
        id: store.nextAttendanceId(),
        date: label,
        className: '6А',
        entries: [
          StudentAttendanceEntry(
            studentId: student.id,
            studentName: student.fullName,
            status: AttendanceStatus.absent,
          ),
        ],
      ),
    );

    expect(store.todaysAttendanceStatus(student), AttendanceStatus.absent);
  });
}
