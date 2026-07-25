import 'package:edubridge/models/announcement.dart';
import 'package:edubridge/models/app_role.dart';
import 'package:edubridge/models/attendance_record.dart';
import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/homework.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/state/app_store.dart';
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

    final student = Student(
      id: '6А-2001',
      className: '6А',
      lastName: 'Бат',
      firstName: 'Болд',
      gender: StudentGender.male,
    );
    await store.addStudent(student);
    await store.setGuardianStudentId(student.id);

    await store.addAttendance(
      '6А',
      AttendanceRecord.detailed(
        id: store.nextAttendanceId(),
        date: 'Өнөөдөр',
        className: '6А',
        entries: const [
          StudentAttendanceEntry(
            studentName: 'Бат Болд',
            status: AttendanceStatus.present,
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
        score: '90',
        term: '1-р улирал',
        letterGrade: 'A',
      ),
    );

    await store.addHomework(
      Homework(
        id: store.nextHomeworkId(),
        className: '6А',
        subject: 'Математик',
        title: 'Дасгал 1',
        description: 'Хуудас 12',
        dueDate: 'Маргааш',
        status: HomeworkStatus.pending,
      ),
    );

    await store.addAnnouncement(
      Announcement(
        id: store.nextAnnouncementId(),
        schoolId: AppStore.defaultSchoolId,
        className: '6А',
        title: 'Эцэг эхийн хурал',
        body: 'Баасан гарагт',
        date: 'Өнөөдөр',
        isFeatured: false,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('guardian reuses teacher data for selected child', () {
    final student = store.selectedGuardianStudent!;
    expect(student.fullName, 'Бат Болд');
    expect(store.todaysAttendanceStatus(student), AttendanceStatus.present);
    expect(store.averageGradeForStudent(student), 90);
    expect(store.pendingHomeworkCountForStudent(student), 1);
    expect(store.unreadGuardianAnnouncementCount(student), 1);
  });

  test('guardian can mark announcements read in SQLite', () async {
    final student = store.selectedGuardianStudent!;
    final announcement = store.announcementsForStudentClass(student).first;
    expect(store.isGuardianAnnouncementRead(announcement.id), isFalse);

    await store.markGuardianAnnouncementRead(announcement.id);
    expect(store.isGuardianAnnouncementRead(announcement.id), isTrue);
    expect(store.unreadGuardianAnnouncementCount(student), 0);
  });

  test('last role persists in prefs', () async {
    await store.setLastRole(AppRole.guardian);
    expect(store.lastRole, AppRole.guardian);

    final reloaded = AppStore(EduBridgeRepository(database));
    await reloaded.load();
    expect(reloaded.lastRole, AppRole.guardian);
    expect(reloaded.guardianStudentId, store.guardianStudentId);
  });
}
