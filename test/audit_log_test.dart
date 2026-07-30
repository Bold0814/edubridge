import 'package:edubridge/models/announcement.dart';
import 'package:edubridge/models/attendance_record.dart';
import 'package:edubridge/models/audit_log.dart';
import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/homework.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/teacher_note.dart';
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
  const schoolId = 'sch-audit';
  const classId = '12a';
  late int mathId;
  late Teacher teacherA;
  late Teacher teacherB;
  late Teacher homeroom;
  late Student student;

  Future<void> loginAs(
    Teacher teacher, {
    required String phone,
    bool openWorkspace = true,
  }) async {
    try {
      await store.logout();
    } catch (_) {}
    await store.login(
      username: phone,
      password: 'Teach2026',
      rememberMe: false,
    );
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(store.authenticatedUser!.id).first,
    );
    if (openWorkspace) {
      await store.setTeacherWorkspace(classId: classId, subjectId: mathId);
    }
  }

  setUp(() async {
    database = await DatabaseService.instance.openInMemoryForTest();
    store = AppStore(
      EduBridgeRepository(database),
      cloudAuthProvisionOverride: (request) async {
        final email = request.internalEmail;
        if (email.contains('99110001')) return 'firebase-a';
        if (email.contains('99110002')) return 'firebase-b';
        if (email.contains('99110003')) return 'firebase-h';
        return 'firebase-${request.role.wireValue}';
      },
    );
    await store.load();

    await store.createSchool(
      id: schoolId,
      name: 'Audit School',
      academicYear: SchoolSettings.currentAcademicYear(),
      currentSemester: SchoolSettings.semesterOptions.first,
    );
    await store.createFirstSchoolAdmin(
      schoolId: schoolId,
      fullName: 'Admin',
      username: 'audadmin',
      password: 'test123',
    );

    await store.addSchoolClass(name: classId);
    await store.addSubject('Math');
    mathId = store.subjectByName('Math')!.id;

    teacherA = Teacher(
      id: store.nextTeacherId(),
      schoolId: schoolId,
      fullName: 'Bold',
      phone: '99110001',
      authUid: 'firebase-a',
    );
    await store.createTeacherWithOptionalLogin(
      teacher: teacherA,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );

    teacherB = Teacher(
      id: store.nextTeacherId(),
      schoolId: schoolId,
      fullName: 'Dulmaa',
      phone: '99110002',
      authUid: 'firebase-b',
    );
    await store.createTeacherWithOptionalLogin(
      teacher: teacherB,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );

    homeroom = Teacher(
      id: store.nextTeacherId(),
      schoolId: schoolId,
      fullName: 'Homeroom',
      phone: '99110003',
      authUid: 'firebase-h',
    );
    await store.createTeacherWithOptionalLogin(
      teacher: homeroom,
      createLogin: true,
      password: 'Teach2026',
      passwordConfirm: 'Teach2026',
    );

    await store.saveClassAssignments(
      classId: classId,
      homeroomTeacherId: homeroom.id,
      subjectTeacherIds: {mathId: teacherA.id},
    );

    student = await store.addStudentWithRequiredGuardian(
      student: Student(
        id: store.nextStudentId(classId),
        className: classId,
        lastName: 'Бат',
        firstName: 'Болд',
        gender: StudentGender.male,
      ),
      guardianFullName: 'Ээж',
      guardianPhone: '88001122',
      relationship: 'Ээж',
    );
  });

  tearDown(() async {
    AppClock.debugResetNow();
    await database.close();
  });

  test('grade create writes audit log', () async {
    await loginAs(teacherA, phone: '99110001');
    AppClock.debugSetNow(() => DateTime(2026, 7, 24, 9, 14));

    await store.saveGrade(
      Grade(
        id: store.nextGradeId(),
        className: classId,
        studentId: student.id,
        studentName: student.fullName,
        subject: 'Math',
        subjectId: mathId,
        score: '85',
        term: SchoolSettings.semesterOptions.first,
        schoolId: schoolId,
        teacherId: teacherA.id,
        createdByUid: 'firebase-a',
      ),
      isUpdate: false,
    );

    final logs = store.auditLogsVisible(entityType: AuditEntityType.grade);
    expect(logs, hasLength(1));
    expect(logs.first.action, AuditAction.create);
    expect(logs.first.teacherName, 'Bold');
    expect(logs.first.newValue, contains('85'));
  });

  test('announcement update/delete write audit logs', () async {
    await loginAs(teacherA, phone: '99110001');
    final id = store.nextAnnouncementId();
    await store.addAnnouncement(
      Announcement(
        id: id,
        schoolId: schoolId,
        className: classId,
        title: '85',
        body: 'body',
        date: '2026-07-24',
        isFeatured: false,
        createdByTeacherId: teacherA.id,
        createdByUid: 'firebase-a',
      ),
    );
    final existing =
        store.announcementsFor(classId).firstWhere((a) => a.id == id);
    await store.updateAnnouncement(existing.copyWith(title: '92'));
    var logs = store.auditLogsVisible(
      entityType: AuditEntityType.announcement,
      action: AuditAction.update,
    );
    expect(logs, isNotEmpty);
    expect(logs.first.valueChangeLabel, '85 → 92');

    await store.deleteAnnouncement(id);
    logs = store.auditLogsVisible(
      entityType: AuditEntityType.announcement,
      action: AuditAction.delete,
    );
    expect(logs, isNotEmpty);
    expect(logs.first.oldValue, '92');
  });

  test('attendance status change logs single-student diff', () async {
    await loginAs(teacherA, phone: '99110001');
    final today = AppClock.todayKey();

    await store.saveAttendance(
      AttendanceRecord.detailed(
        id: 'x',
        date: AppClock.displayLabel(today),
        dateKey: today,
        schoolId: schoolId,
        className: classId,
        subjectId: mathId,
        entries: [
          StudentAttendanceEntry(
            studentId: student.id,
            studentName: student.fullName,
            status: AttendanceStatus.late,
          ),
        ],
      ),
    );

    await store.saveAttendance(
      AttendanceRecord.detailed(
        id: 'y',
        date: AppClock.displayLabel(today),
        dateKey: today,
        schoolId: schoolId,
        className: classId,
        subjectId: mathId,
        entries: [
          StudentAttendanceEntry(
            studentId: student.id,
            studentName: student.fullName,
            status: AttendanceStatus.present,
          ),
        ],
      ),
    );

    final logs = store.auditLogsVisible(
      entityType: AuditEntityType.attendance,
      action: AuditAction.update,
    );
    expect(logs, isNotEmpty);
    expect(logs.first.oldValue, 'Хоцорсон');
    expect(logs.first.newValue, 'Ирсэн');
  });

  test('homework announcement advice create audit logs', () async {
    await loginAs(teacherA, phone: '99110001');

    await store.addHomework(
      Homework(
        id: store.nextHomeworkId(),
        className: classId,
        subject: 'Math',
        subjectId: mathId,
        title: 'Даалгавар 1',
        description: 'desc',
        dueDate: '2026-07-30',
        status: HomeworkStatus.pending,
        schoolId: schoolId,
      ),
    );
    await store.addAnnouncement(
      Announcement(
        id: store.nextAnnouncementId(),
        schoolId: schoolId,
        className: classId,
        title: 'Зарлал',
        body: 'body',
        date: '2026-07-24',
        isFeatured: false,
      ),
    );
    await store.addTeacherNote(
      TeacherNote(
        id: store.nextTeacherNoteId(),
        studentId: student.id,
        teacherId: teacherA.id,
        subjectId: mathId,
        schoolId: schoolId,
        classId: classId,
        createdAt: DateTime(2026, 7, 24).toIso8601String(),
        title: 'Зөвлөгөө',
        message: 'Сайн',
        priority: NotePriority.normal,
        isVisibleToGuardian: true,
        isVisibleToStudent: true,
      ),
    );

    expect(
      store.auditLogsVisible(entityType: AuditEntityType.homework),
      hasLength(1),
    );
    expect(
      store.auditLogsVisible(entityType: AuditEntityType.announcement),
      hasLength(1),
    );
    expect(
      store.auditLogsVisible(entityType: AuditEntityType.advice),
      hasLength(1),
    );
  });

  test('visibility: admin all, teacher own, homeroom class', () async {
    await loginAs(teacherA, phone: '99110001');
    await store.saveGrade(
      Grade(
        id: store.nextGradeId(),
        className: classId,
        studentId: student.id,
        studentName: student.fullName,
        subject: 'Math',
        subjectId: mathId,
        score: '80',
        term: SchoolSettings.semesterOptions.first,
        schoolId: schoolId,
        teacherId: teacherA.id,
        createdByUid: 'firebase-a',
      ),
      isUpdate: false,
    );

    expect(store.auditLogsVisible(), hasLength(1));

    await loginAs(teacherB, phone: '99110002', openWorkspace: false);
    expect(store.canViewAuditLogs, isTrue);
    expect(store.auditLogsVisible(), isEmpty);

    await loginAs(homeroom, phone: '99110003', openWorkspace: false);
    expect(store.auditLogsVisible(), hasLength(1));

    try {
      await store.logout();
    } catch (_) {}
    await store.login(
      username: 'audadmin',
      password: 'test123',
      rememberMe: false,
    );
    await store.selectSchoolMembership(
      store.activeMembershipsForUser(store.authenticatedUser!.id).first,
    );
    expect(store.hasAdminPermissionForActiveSchool, isTrue);
    expect(store.auditLogsVisible(), hasLength(1));
  });

  test('audit logs reload from repository after restart', () async {
    await loginAs(teacherA, phone: '99110001');
    await store.addAnnouncement(
      Announcement(
        id: store.nextAnnouncementId(),
        schoolId: schoolId,
        className: classId,
        title: 'Persist',
        body: 'body',
        date: '2026-07-24',
        isFeatured: false,
      ),
    );

    final store2 = AppStore(EduBridgeRepository(database));
    await store2.load();
    final rows = await EduBridgeRepository(database).loadAuditLogs(
      schoolId: schoolId,
    );
    expect(rows, isNotEmpty);
    expect(rows.first.entityType, AuditEntityType.announcement);
  });
}
