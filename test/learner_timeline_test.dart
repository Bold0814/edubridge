import 'package:edubridge/models/announcement.dart';
import 'package:edubridge/models/attendance_record.dart';
import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/homework.dart';
import 'package:edubridge/models/student.dart';
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

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(EduBridgeRepository(database));
    await store.load();

    student = const Student(
      id: '6А-tl-1',
      className: '6А',
      lastName: 'Бат',
      firstName: 'Болд',
      gender: StudentGender.male,
    );
    await store.addStudent(student);

    await store.addAttendance(
      '6А',
      AttendanceRecord.detailed(
        id: store.nextAttendanceId(),
        date: 'Өнөөдөр',
        className: '6А',
        entries: const [
          StudentAttendanceEntry(
            studentName: 'Бат Болд',
            status: AttendanceStatus.late,
          ),
        ],
      ),
    );
    await store.addGrade(
      Grade(
        id: store.nextGradeId(),
        className: '6А',
        studentId: student.id,
        studentName: student.fullName,
        subject: 'Математик',
        score: '80',
        term: '1-р улирал',
      ),
    );
    await store.addHomework(
      Homework(
        id: store.nextHomeworkId(),
        className: '6А',
        subject: 'Математик',
        title: 'Дасгал',
        description: 'Хуудас 1',
        dueDate: 'Маргааш',
        status: HomeworkStatus.pending,
      ),
    );
    await store.addAnnouncement(
      Announcement(
        id: store.nextAnnouncementId(),
        schoolId: AppStore.defaultSchoolId,
        className: '6А',
        title: 'Хурал',
        body: 'Баасан',
        date: 'Өнөөдөр',
        isFeatured: false,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('StudentTimeline and GuardianTimeline reuse the same store data', () {
    final studentTl = StudentTimeline.fromStore(store, student);
    final guardianTl = GuardianTimeline.fromStore(store, student);

    expect(studentTl.data.todaysAttendance, AttendanceStatus.late);
    expect(studentTl.data.averageGrade, 80);
    expect(studentTl.data.dueSoonHomework, hasLength(1));
    expect(studentTl.data.latestAnnouncement?.title, 'Хурал');

    expect(guardianTl.data.todaysAttendance, studentTl.data.todaysAttendance);
    expect(guardianTl.data.averageGrade, studentTl.data.averageGrade);
    expect(guardianTl.data.attendanceLateCount, 1);
    expect(guardianTl.data.unreadAnnouncementCount, 1);
  });

  test('timeline reflects teacher updates through AppStore', () async {
    await store.addGrade(
      Grade(
        id: store.nextGradeId(),
        className: '6А',
        studentId: student.id,
        studentName: student.fullName,
        subject: 'Физик',
        score: '100',
        term: '1-р улирал',
      ),
    );

    final tl = StudentTimeline.fromStore(store, student);
    expect(tl.data.averageGrade, 90);
  });
}
