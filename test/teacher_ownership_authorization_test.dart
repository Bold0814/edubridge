import 'package:edubridge/models/announcement.dart';
import 'package:edubridge/models/attendance_record.dart';
import 'package:edubridge/models/grade.dart';
import 'package:edubridge/models/homework.dart';
import 'package:edubridge/models/school_settings.dart';
import 'package:edubridge/models/student.dart';
import 'package:edubridge/models/teacher.dart';
import 'package:edubridge/models/teacher_note.dart';
import 'package:edubridge/repositories/edubridge_repository.dart';
import 'package:edubridge/screens/teacher_notes_screen.dart';
import 'package:edubridge/services/database_service.dart';
import 'package:edubridge/services/teacher_authorization_service.dart';
import 'package:edubridge/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

TeacherAuthorizationService authFor({
  required String? authUid,
  required String? teacherDocId,
  required String schoolId,
  bool isAdmin = false,
  Set<String> homeroomClasses = const {},
  Set<String> assignments = const {},
  Set<String> teachClasses = const {},
}) {
  return TeacherAuthorizationService(
    authUid: authUid,
    teacherDocId: teacherDocId,
    schoolId: schoolId,
    isAdmin: isAdmin,
    isHomeroomOf: homeroomClasses.contains,
    isAssignedTo: (classId, subjectId) =>
        assignments.contains('$classId|$subjectId'),
    teachesInClass: (classId) =>
        teachClasses.contains(classId) || homeroomClasses.contains(classId),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TeacherAuthorizationService unit', () {
    const school = 'sch-1';
    const classId = '7А';
    const mathId = 10;
    const physicsId = 20;

    test('1. Teacher A can edit own advice', () {
      final a = authFor(
        authUid: 'uid-a',
        teacherDocId: 'tch-a',
        schoolId: school,
        homeroomClasses: {classId},
        teachClasses: {classId},
      );
      const ownership = RecordOwnership(
        schoolId: school,
        classId: classId,
        subjectId: mathId,
        createdByUid: 'uid-a',
        createdByTeacherId: 'tch-a',
      );
      expect(
        a.canEditRecord(kind: TeacherRecordKind.advice, ownership: ownership),
        isTrue,
      );
    });

    test('2. Teacher A cannot edit Teacher B advice', () {
      final a = authFor(
        authUid: 'uid-a',
        teacherDocId: 'tch-a',
        schoolId: school,
        assignments: {'$classId|$mathId'},
        teachClasses: {classId},
      );
      const bNote = RecordOwnership(
        schoolId: school,
        classId: classId,
        subjectId: mathId,
        createdByUid: 'uid-b',
        createdByTeacherId: 'tch-b',
      );
      expect(
        a.canEditRecord(kind: TeacherRecordKind.advice, ownership: bNote),
        isFalse,
      );
    });

    test('3. Teacher A cannot delete Teacher B advice', () {
      final a = authFor(
        authUid: 'uid-a',
        teacherDocId: 'tch-a',
        schoolId: school,
        assignments: {'$classId|$mathId'},
        teachClasses: {classId},
      );
      const bNote = RecordOwnership(
        schoolId: school,
        classId: classId,
        createdByUid: 'uid-b',
        createdByTeacherId: 'tch-b',
      );
      expect(
        a.canDeleteRecord(kind: TeacherRecordKind.advice, ownership: bNote),
        isFalse,
      );
    });

    test('4. Homeroom teacher can view another subject teacher advice', () {
      final homeroom = authFor(
        authUid: 'uid-h',
        teacherDocId: 'tch-h',
        schoolId: school,
        homeroomClasses: {classId},
      );
      const subjectNote = RecordOwnership(
        schoolId: school,
        classId: classId,
        subjectId: mathId,
        createdByUid: 'uid-b',
        createdByTeacherId: 'tch-b',
      );
      expect(
        homeroom.canViewRecord(
          kind: TeacherRecordKind.advice,
          ownership: subjectNote,
        ),
        isTrue,
      );
    });

    test('5. Homeroom teacher cannot edit/delete another teacher advice', () {
      final homeroom = authFor(
        authUid: 'uid-h',
        teacherDocId: 'tch-h',
        schoolId: school,
        homeroomClasses: {classId},
      );
      const subjectNote = RecordOwnership(
        schoolId: school,
        classId: classId,
        subjectId: mathId,
        createdByUid: 'uid-b',
        createdByTeacherId: 'tch-b',
      );
      expect(
        homeroom.canEditRecord(
          kind: TeacherRecordKind.advice,
          ownership: subjectNote,
        ),
        isFalse,
      );
      expect(
        homeroom.canDeleteRecord(
          kind: TeacherRecordKind.advice,
          ownership: subjectNote,
        ),
        isFalse,
      );
    });

    test('6. Subject teacher can create grade for assigned subject/class', () {
      final a = authFor(
        authUid: 'uid-a',
        teacherDocId: 'tch-a',
        schoolId: school,
        assignments: {'$classId|$mathId'},
        teachClasses: {classId},
      );
      expect(
        a.canCreateRecord(
          kind: TeacherRecordKind.grade,
          classId: classId,
          subjectId: mathId,
          recordSchoolId: school,
        ),
        isTrue,
      );
    });

    test('7. Subject teacher cannot create grade for unassigned subject', () {
      final a = authFor(
        authUid: 'uid-a',
        teacherDocId: 'tch-a',
        schoolId: school,
        assignments: {'$classId|$mathId'},
        teachClasses: {classId},
      );
      expect(
        a.canCreateRecord(
          kind: TeacherRecordKind.grade,
          classId: classId,
          subjectId: physicsId,
          recordSchoolId: school,
        ),
        isFalse,
      );
    });

    test('8. Subject teacher cannot edit another teacher grade', () {
      final a = authFor(
        authUid: 'uid-a',
        teacherDocId: 'tch-a',
        schoolId: school,
        assignments: {'$classId|$mathId'},
        teachClasses: {classId},
      );
      expect(
        a.canEditRecord(
          kind: TeacherRecordKind.grade,
          ownership: const RecordOwnership(
            schoolId: school,
            classId: classId,
            subjectId: mathId,
            createdByUid: 'uid-b',
            createdByTeacherId: 'tch-b',
          ),
        ),
        isFalse,
      );
    });

    test('9. Teacher cannot delete another teacher homework', () {
      final a = authFor(
        authUid: 'uid-a',
        teacherDocId: 'tch-a',
        schoolId: school,
        assignments: {'$classId|$mathId'},
        teachClasses: {classId},
      );
      expect(
        a.canDeleteRecord(
          kind: TeacherRecordKind.homework,
          ownership: const RecordOwnership(
            schoolId: school,
            classId: classId,
            subjectId: mathId,
            createdByUid: 'uid-b',
            createdByTeacherId: 'tch-b',
          ),
        ),
        isFalse,
      );
    });

    test('10. Teacher cannot edit another teacher announcement', () {
      final a = authFor(
        authUid: 'uid-a',
        teacherDocId: 'tch-a',
        schoolId: school,
        teachClasses: {classId},
      );
      expect(
        a.canEditRecord(
          kind: TeacherRecordKind.announcement,
          ownership: const RecordOwnership(
            schoolId: school,
            classId: classId,
            createdByUid: 'uid-b',
            createdByTeacherId: 'tch-b',
          ),
        ),
        isFalse,
      );
    });

    test('11. Teacher cannot rewrite another teacher attendance history', () {
      final a = authFor(
        authUid: 'uid-a',
        teacherDocId: 'tch-a',
        schoolId: school,
        assignments: {'$classId|$mathId'},
        teachClasses: {classId},
      );
      const other = RecordOwnership(
        schoolId: school,
        classId: classId,
        subjectId: mathId,
        createdByUid: 'uid-b',
        createdByTeacherId: 'tch-b',
      );
      expect(
        a.canEditRecord(kind: TeacherRecordKind.attendance, ownership: other),
        isFalse,
      );
      expect(
        a.canDeleteRecord(kind: TeacherRecordKind.attendance, ownership: other),
        isFalse,
      );
    });

    test('12. Admin can manage records within own school', () {
      final admin = authFor(
        authUid: 'uid-admin',
        teacherDocId: null,
        schoolId: school,
        isAdmin: true,
      );
      const record = RecordOwnership(
        schoolId: school,
        classId: classId,
        subjectId: mathId,
        createdByUid: 'uid-b',
        createdByTeacherId: 'tch-b',
      );
      expect(
        admin.canEditRecord(kind: TeacherRecordKind.grade, ownership: record),
        isTrue,
      );
      expect(
        admin.canDeleteRecord(kind: TeacherRecordKind.grade, ownership: record),
        isTrue,
      );
    });

    test('13. Admin cannot manage another school records', () {
      final admin = authFor(
        authUid: 'uid-admin',
        teacherDocId: null,
        schoolId: school,
        isAdmin: true,
      );
      const otherSchool = RecordOwnership(
        schoolId: 'sch-other',
        classId: classId,
        subjectId: mathId,
        createdByUid: 'uid-b',
        createdByTeacherId: 'tch-b',
      );
      expect(
        admin.canEditRecord(
          kind: TeacherRecordKind.grade,
          ownership: otherSchool,
        ),
        isFalse,
      );
      expect(
        admin.canViewRecord(
          kind: TeacherRecordKind.grade,
          ownership: otherSchool,
        ),
        isFalse,
      );
    });

    test('14. Legacy record without createdByUid is read-only for teacher', () {
      final a = authFor(
        authUid: 'uid-a',
        teacherDocId: 'tch-a',
        schoolId: school,
        assignments: {'$classId|$mathId'},
        teachClasses: {classId},
      );
      const legacy = RecordOwnership(
        schoolId: school,
        classId: classId,
        subjectId: mathId,
      );
      expect(
        a.canViewRecord(kind: TeacherRecordKind.grade, ownership: legacy),
        isTrue,
      );
      expect(
        a.canEditRecord(kind: TeacherRecordKind.grade, ownership: legacy),
        isFalse,
      );
      expect(
        a.canDeleteRecord(kind: TeacherRecordKind.grade, ownership: legacy),
        isFalse,
      );
    });
  });

  group('AppStore ownership enforcement', () {
    late Database database;
    late AppStore store;
    late Teacher teacherA;
    late Teacher teacherB;
    late Teacher homeroom;
    late Student student;
    late int mathId;
    const schoolId = 'sch-own';
    const classId = '12z';

    Future<void> loginAs(Teacher teacher, {required String phone}) async {
      try {
        await store.logout();
      } catch (_) {
        // Firebase may be uninitialized in unit tests.
      }
      await store.login(
        username: phone,
        password: 'Teach2026',
        rememberMe: false,
      );
      await store.selectSchoolMembership(
        store.activeMembershipsForUser(store.authenticatedUser!.id).first,
      );
      await store.setTeacherWorkspace(classId: classId, subjectId: mathId);
    }

    setUp(() async {
      database = await DatabaseService.instance.openInMemoryForTest();
      store = AppStore(EduBridgeRepository(database));
      await store.load();

      await store.createSchool(
        id: schoolId,
        name: 'Ownership School',
        academicYear: SchoolSettings.currentAcademicYear(),
        currentSemester: SchoolSettings.semesterOptions.first,
      );
      await store.createFirstSchoolAdmin(
        schoolId: schoolId,
        fullName: 'Admin',
        username: 'ownadmin',
        password: 'test123',
      );

      await store.addSchoolClass(name: classId);
      await store.addSubject('Math');
      mathId = store.subjectByName('Math')!.id;

      teacherA = Teacher(
        id: store.nextTeacherId(),
        schoolId: schoolId,
        fullName: 'Teacher A',
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
        fullName: 'Teacher B',
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
      await database.close();
    });

    test('16. repository write denied even if UI method called directly', () async {
      await loginAs(teacherA, phone: '99110001');
      final note = TeacherNote(
        id: store.nextTeacherNoteId(),
        studentId: student.id,
        teacherId: teacherA.id,
        subjectId: mathId,
        schoolId: schoolId,
        classId: classId,
        createdByUid: 'firebase-a',
        createdAt: DateTime(2026, 7, 24).toIso8601String(),
        title: 'A note',
        message: 'Mine',
        priority: NotePriority.normal,
        isVisibleToGuardian: true,
        isVisibleToStudent: true,
      );
      await store.addTeacherNote(note);

      await loginAs(teacherB, phone: '99110002');
      expect(
        () => store.updateTeacherNote(note.copyWith(title: 'Hacked')),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(
        () => store.deleteTeacherNote(note.id),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('teacher A owns advice; B and homeroom cannot modify via store', () async {
      await loginAs(teacherA, phone: '99110001');
      final note = TeacherNote(
        id: store.nextTeacherNoteId(),
        studentId: student.id,
        teacherId: teacherA.id,
        subjectId: mathId,
        schoolId: schoolId,
        classId: classId,
        createdByUid: 'firebase-a',
        createdAt: DateTime(2026, 7, 24).toIso8601String(),
        title: 'A note',
        message: 'Mine',
        priority: NotePriority.normal,
        isVisibleToGuardian: true,
        isVisibleToStudent: true,
      );
      await store.addTeacherNote(note);
      await store.updateTeacherNote(note.copyWith(title: 'Updated by A'));
      expect(store.teacherNotesForClass(classId).first.title, 'Updated by A');

      await loginAs(homeroom, phone: '99110003');
      final saved = store.teacherNotesForClass(classId).first;
      expect(
        store.teacherAuthorization.canViewRecord(
          kind: TeacherRecordKind.advice,
          ownership: RecordOwnership(
            schoolId: saved.schoolId,
            classId: classId,
            subjectId: saved.subjectId,
            createdByUid: saved.createdByUid,
            createdByTeacherId: saved.teacherId,
          ),
        ),
        isTrue,
      );
      expect(store.canEditAdvice(saved, classId: classId), isFalse);
      expect(
        () => store.deleteTeacherNote(note.id),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('cannot edit another teacher grade/homework/announcement/attendance', () async {
      await loginAs(teacherA, phone: '99110001');
      final grade = await store.saveGrade(
        Grade(
          id: store.nextGradeId(),
          className: classId,
          studentId: student.id,
          studentName: student.fullName,
          subject: 'Math',
          subjectId: mathId,
          score: '90',
          term: SchoolSettings.semesterOptions.first,
          schoolId: schoolId,
          teacherId: teacherA.id,
          createdByUid: 'firebase-a',
        ),
        isUpdate: false,
      );

      final homework = Homework(
        id: store.nextHomeworkId(),
        className: classId,
        subject: 'Math',
        subjectId: mathId,
        title: 'HW',
        description: 'Do it',
        dueDate: '2026-07-30',
        status: HomeworkStatus.pending,
        schoolId: schoolId,
        createdByUid: 'firebase-a',
        createdByTeacherId: teacherA.id,
      );
      await store.addHomework(homework);

      final announcement = Announcement(
        id: store.nextAnnouncementId(),
        schoolId: schoolId,
        className: classId,
        title: 'News',
        body: 'Body',
        date: '2026-07-24',
        isFeatured: false,
        createdByUid: 'firebase-a',
        createdByTeacherId: teacherA.id,
      );
      await store.addAnnouncement(announcement);

      final savedAttendance = await store.saveAttendance(
        AttendanceRecord.detailed(
          id: store.nextAttendanceId(),
          date: '2026-07-24',
          dateKey: '2026-07-24',
          schoolId: schoolId,
          className: classId,
          subjectId: mathId,
          recordedAt: DateTime(2026, 7, 24),
          recordedByTeacherId: teacherA.id,
          createdByUid: 'firebase-a',
          entries: [
            StudentAttendanceEntry(
              studentId: student.id,
              studentName: student.fullName,
              status: AttendanceStatus.present,
            ),
          ],
        ),
      );

      await loginAs(homeroom, phone: '99110003');
      expect(store.canEditGradeRecord(grade), isFalse);
      expect(store.canEditHomeworkRecord(homework), isFalse);
      expect(store.canEditAnnouncement(announcement), isFalse);
      expect(store.canDeleteAttendanceRecord(savedAttendance), isFalse);

      expect(
        () => store.updateGrade(grade.copyWith(score: '1')),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(
        () => store.deleteHomework(homework.id),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(
        () => store.updateAnnouncement(announcement.copyWith(title: 'Hacked')),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(
        () => store.deleteAttendance(classId, savedAttendance.id),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    testWidgets('15. edit/delete buttons hidden when permission is false', (
      tester,
    ) async {
      await loginAs(teacherA, phone: '99110001');
      final note = TeacherNote(
        id: store.nextTeacherNoteId(),
        studentId: student.id,
        teacherId: teacherA.id,
        subjectId: mathId,
        schoolId: schoolId,
        classId: classId,
        createdByUid: 'firebase-a',
        createdAt: DateTime(2026, 7, 24).toIso8601String(),
        title: 'Visible',
        message: 'Body',
        priority: NotePriority.normal,
        isVisibleToGuardian: true,
        isVisibleToStudent: true,
      );
      await store.addTeacherNote(note);

      await loginAs(homeroom, phone: '99110003');
      await tester.pumpWidget(
        MaterialApp(
          home: TeacherNotesScreen(selectedClass: classId, store: store),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Visible'), findsOneWidget);
      expect(find.byTooltip('Цэс'), findsNothing);
    });
  });
}
