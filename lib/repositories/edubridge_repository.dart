import 'package:sqflite/sqflite.dart';

import '../models/account_status.dart';
import '../models/announcement.dart';
import '../models/app_role.dart';
import '../models/app_settings.dart';
import '../models/attendance_record.dart';
import '../models/class_subject_teacher.dart';
import '../models/grade.dart';
import '../models/guardian.dart';
import '../models/guardian_student.dart';
import '../models/homework.dart';
import '../models/school.dart';
import '../models/school_class.dart';
import '../models/school_settings.dart';
import '../models/student.dart';
import '../models/subject.dart';
import '../models/teacher.dart';
import '../models/teacher_note.dart';
import '../models/timetable.dart';
import '../models/user_account.dart';
import '../services/database_service.dart';
import '../services/student_login_ids.dart';

/// Data access layer between AppStore and SQLite.
class EduBridgeRepository {
  EduBridgeRepository(this._db);

  final Database _db;

  /// Exposed for batch/dev tooling that needs transactions.
  Database get database => _db;

  // --- Classes ---

  Future<List<SchoolClass>> loadSchoolClasses() async {
    final rows = await _db.query('classes');
    final items = rows.map(_schoolClassFromRow).toList();
    items.sort((a, b) => _compareClassNames(a.name, b.name));
    return items;
  }

  Future<List<String>> loadClasses() async {
    final classes = await loadSchoolClasses();
    return classes.map((c) => c.name).toList();
  }

  static int _compareClassNames(String a, String b) {
    final aNum = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final bNum = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (aNum != bNum) return aNum.compareTo(bNum);
    return a.compareTo(b);
  }

  Future<void> insertClasses(
    List<String> names, {
    String schoolId = DatabaseService.defaultSchoolId,
  }) async {
    if (names.isEmpty) return;
    final batch = _db.batch();
    for (final name in names) {
      batch.insert('classes', {
        'name': name,
        'school_id': schoolId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertSchoolClass(SchoolClass schoolClass) async {
    // SQLite PK remains `name`; for multi-school use unique [SchoolClass.id].
    await _db.insert('classes', {
      'name': schoolClass.id,
      'homeroom_teacher_id': schoolClass.homeroomTeacherId,
      'school_id': schoolClass.schoolId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateClassHomeroom({
    required String classId,
    String? teacherId,
  }) async {
    await _db.update(
      'classes',
      {'homeroom_teacher_id': teacherId},
      where: 'name = ?',
      whereArgs: [classId],
    );
  }

  SchoolClass _schoolClassFromRow(Map<String, Object?> row) {
    final name = row['name']! as String;
    return SchoolClass(
      id: name,
      name: name,
      schoolId: row['school_id'] as String? ?? DatabaseService.defaultSchoolId,
      homeroomTeacherId: row['homeroom_teacher_id'] as String?,
    );
  }

  // --- Schools ---

  Future<List<School>> loadSchools() async {
    final rows = await _db.query('schools', orderBy: 'name ASC');
    return rows.map(_schoolFromRow).toList();
  }

  Future<void> insertSchool(School school) async {
    await _db.insert('schools', _schoolToRow(school));
  }

  Future<void> updateSchool(School school) async {
    await _db.update(
      'schools',
      _schoolToRow(school),
      where: 'id = ?',
      whereArgs: [school.id],
    );
  }

  Map<String, Object?> _schoolToRow(School school) => {
    'id': school.id,
    'name': school.name,
    'code': school.code,
    'address': school.address,
    'is_active': school.isActive ? 1 : 0,
    'login_prefix': school.loginPrefix,
    'student_code_seq': school.studentCodeSeq,
  };

  School _schoolFromRow(Map<String, Object?> row) {
    return School(
      id: row['id']! as String,
      name: row['name']! as String,
      code: row['code'] as String?,
      address: row['address'] as String?,
      isActive: (row['is_active'] as int?) != 0,
      loginPrefix: row['login_prefix'] as String?,
      studentCodeSeq: (row['student_code_seq'] as int?) ?? 0,
    );
  }

  Future<void> reserveStudentCode({
    required String schoolId,
    required String code,
  }) async {
    await _db.insert('used_student_codes', {
      'school_id': schoolId,
      'code_key': StudentLoginIds.compareKey(code),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<bool> isStudentCodeReserved({
    required String schoolId,
    required String code,
  }) async {
    final rows = await _db.query(
      'used_student_codes',
      where: 'school_id = ? AND code_key = ?',
      whereArgs: [schoolId, StudentLoginIds.compareKey(code)],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Atomically allocates the next school-scoped student code.
  Future<({String code, School school})> allocateNextStudentCode(
    String schoolId,
  ) async {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'schools',
        where: 'id = ?',
        whereArgs: [schoolId],
        limit: 1,
      );
      if (rows.isEmpty) throw ArgumentError('SCHOOL_NOT_FOUND');
      var school = _schoolFromRow(rows.first);
      var prefix = school.loginPrefix?.trim();
      if (prefix == null || prefix.isEmpty) {
        prefix =
            StudentLoginIds.prefixFromSchoolCode(school.code) ??
            StudentLoginIds.deriveStablePrefix(schoolId);
        await txn.update(
          'schools',
          {'login_prefix': prefix},
          where: 'id = ?',
          whereArgs: [schoolId],
        );
        school = school.copyWith(loginPrefix: prefix);
      }

      var seq = school.studentCodeSeq;
      String code;
      while (true) {
        seq += 1;
        code = StudentLoginIds.formatCode(prefix: prefix, sequence: seq);
        final reserved = await txn.query(
          'used_student_codes',
          where: 'school_id = ? AND code_key = ?',
          whereArgs: [schoolId, StudentLoginIds.compareKey(code)],
          limit: 1,
        );
        if (reserved.isEmpty) break;
      }

      await txn.update(
        'schools',
        {'student_code_seq': seq, 'login_prefix': prefix},
        where: 'id = ?',
        whereArgs: [schoolId],
      );
      await txn.insert('used_student_codes', {
        'school_id': schoolId,
        'code_key': StudentLoginIds.compareKey(code),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      return (
        code: code,
        school: school.copyWith(loginPrefix: prefix, studentCodeSeq: seq),
      );
    });
  }

  // --- User school memberships ---

  Future<List<UserSchoolMembership>> loadMemberships() async {
    final rows = await _db.query(
      'user_school_memberships',
      orderBy: 'user_id ASC, school_id ASC',
    );
    return rows.map(_membershipFromRow).toList();
  }

  Future<void> insertMembership(UserSchoolMembership membership) async {
    await _db.insert('user_school_memberships', _membershipToRow(membership));
  }

  Future<void> updateMembership(UserSchoolMembership membership) async {
    await _db.update(
      'user_school_memberships',
      _membershipToRow(membership),
      where: 'id = ?',
      whereArgs: [membership.id],
    );
  }

  Map<String, Object?> _membershipToRow(UserSchoolMembership membership) => {
    'id': membership.id,
    'user_id': membership.userId,
    'school_id': membership.schoolId,
    'role': membership.role.storageValue,
    'teacher_id': membership.teacherId,
    'guardian_id': membership.guardianId,
    'student_id': membership.studentId,
    'is_active': membership.isActive ? 1 : 0,
  };

  UserSchoolMembership _membershipFromRow(Map<String, Object?> row) {
    return UserSchoolMembership(
      id: row['id']! as String,
      userId: row['user_id']! as String,
      schoolId: row['school_id']! as String,
      role: AppRole.tryParse(row['role'] as String?) ?? AppRole.teacher,
      teacherId: row['teacher_id'] as String?,
      guardianId: row['guardian_id'] as String?,
      studentId: row['student_id'] as String?,
      isActive: (row['is_active'] as int?) != 0,
    );
  }

  // --- Students ---

  Future<List<Student>> loadStudents() async {
    final rows = await _db.query('students', orderBy: 'last_name, first_name');
    return rows.map(_studentFromRow).toList();
  }

  Future<void> insertStudent(Student student) async {
    await _db.insert('students', _studentToRow(student));
  }

  Future<void> insertStudents(List<Student> students) async {
    if (students.isEmpty) return;
    final batch = _db.batch();
    for (final student in students) {
      batch.insert('students', _studentToRow(student));
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateStudent(Student student) async {
    await _db.update(
      'students',
      _studentToRow(student),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  Future<void> deleteStudent(String studentId) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'guardian_students',
        where: 'student_id = ?',
        whereArgs: [studentId],
      );
      await txn.delete(
        'user_school_memberships',
        where: 'student_id = ?',
        whereArgs: [studentId],
      );
      await txn.delete(
        'user_accounts',
        where: 'student_id = ?',
        whereArgs: [studentId],
      );
      await txn.delete('students', where: 'id = ?', whereArgs: [studentId]);
    });
  }

  // --- Attendance ---

  Future<List<AttendanceRecord>> loadAttendance() async {
    final rows = await _db.query('attendance', orderBy: 'rowid DESC');
    return rows.map(_attendanceFromRow).toList();
  }

  Future<void> insertAttendance(AttendanceRecord record) async {
    await _db.insert('attendance', _attendanceToRow(record));
  }

  Future<void> insertAttendanceRecords(List<AttendanceRecord> records) async {
    if (records.isEmpty) return;
    final batch = _db.batch();
    for (final record in records) {
      batch.insert('attendance', _attendanceToRow(record));
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateAttendance(AttendanceRecord record) async {
    await _db.update(
      'attendance',
      _attendanceToRow(record),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> deleteAttendance(String id) async {
    await _db.delete('attendance', where: 'id = ?', whereArgs: [id]);
  }

  // --- Grades ---

  Future<List<Grade>> loadGrades() async {
    final rows = await _db.query('grades', orderBy: 'rowid DESC');
    return rows.map(_gradeFromRow).toList();
  }

  Future<void> insertGrade(Grade grade) async {
    await _db.insert('grades', _gradeToRow(grade));
  }

  Future<void> insertGrades(List<Grade> grades) async {
    if (grades.isEmpty) return;
    final batch = _db.batch();
    for (final grade in grades) {
      batch.insert('grades', _gradeToRow(grade));
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateGrade(Grade grade) async {
    await _db.update(
      'grades',
      _gradeToRow(grade),
      where: 'id = ?',
      whereArgs: [grade.id],
    );
  }

  Future<void> deleteGrade(String id) async {
    await _db.delete('grades', where: 'id = ?', whereArgs: [id]);
  }

  // --- Homework ---

  Future<List<Homework>> loadHomework() async {
    final rows = await _db.query('homework', orderBy: 'rowid DESC');
    return rows.map(_homeworkFromRow).toList();
  }

  /// Class-scoped homework query; optional subject name filter.
  Future<List<Homework>> loadHomeworkForClass(
    String className, {
    String? subject,
  }) async {
    final trimmed = subject?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      final rows = await _db.query(
        'homework',
        where: 'class_name = ? AND subject = ?',
        whereArgs: [className, trimmed],
        orderBy: 'rowid DESC',
      );
      return rows.map(_homeworkFromRow).toList();
    }
    final rows = await _db.query(
      'homework',
      where: 'class_name = ?',
      whereArgs: [className],
      orderBy: 'rowid DESC',
    );
    return rows.map(_homeworkFromRow).toList();
  }

  Future<void> insertHomework(Homework homework) async {
    await _db.insert('homework', _homeworkToRow(homework));
  }

  Future<void> insertHomeworkList(List<Homework> items) async {
    if (items.isEmpty) return;
    final batch = _db.batch();
    for (final item in items) {
      batch.insert('homework', _homeworkToRow(item));
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateHomework(Homework homework) async {
    await _db.update(
      'homework',
      _homeworkToRow(homework),
      where: 'id = ?',
      whereArgs: [homework.id],
    );
  }

  Future<void> deleteHomework(String id) async {
    await _db.delete('homework', where: 'id = ?', whereArgs: [id]);
  }

  // --- Announcements ---

  Future<List<Announcement>> loadAnnouncements() async {
    final rows = await _db.query('announcements', orderBy: 'rowid DESC');
    return rows.map(_announcementFromRow).toList();
  }

  Future<void> insertAnnouncement(Announcement announcement) async {
    await _db.insert('announcements', _announcementToRow(announcement));
  }

  Future<void> insertAnnouncements(List<Announcement> items) async {
    if (items.isEmpty) return;
    final batch = _db.batch();
    for (final item in items) {
      batch.insert('announcements', _announcementToRow(item));
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateAnnouncement(Announcement announcement) async {
    await _db.update(
      'announcements',
      _announcementToRow(announcement),
      where: 'id = ?',
      whereArgs: [announcement.id],
    );
  }

  Future<void> deleteAnnouncement(String id) async {
    await _db.delete('announcements', where: 'id = ?', whereArgs: [id]);
  }

  // --- Teacher notes ---

  Future<List<TeacherNote>> loadTeacherNotes() async {
    final rows = await _db.query('teacher_notes', orderBy: 'created_at DESC');
    return rows.map(_teacherNoteFromRow).toList();
  }

  Future<void> insertTeacherNote(TeacherNote note) async {
    await _db.insert('teacher_notes', _teacherNoteToRow(note));
  }

  Future<void> updateTeacherNote(TeacherNote note) async {
    await _db.update(
      'teacher_notes',
      _teacherNoteToRow(note),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> deleteTeacherNote(String id) async {
    await _db.delete('teacher_notes', where: 'id = ?', whereArgs: [id]);
  }

  // --- Timetable ---

  Future<List<LessonPeriod>> loadLessonPeriods() async {
    final rows = await _db.query(
      'lesson_periods',
      orderBy: 'period_number ASC',
    );
    return rows.map(_lessonPeriodFromRow).toList();
  }

  Future<void> insertLessonPeriod(LessonPeriod period) async {
    await _db.insert('lesson_periods', _lessonPeriodToRow(period));
  }

  Future<void> updateLessonPeriod(LessonPeriod period) async {
    await _db.update(
      'lesson_periods',
      _lessonPeriodToRow(period),
      where: 'id = ?',
      whereArgs: [period.id],
    );
  }

  Future<void> deleteLessonPeriod(String id) async {
    await _db.delete(
      'class_timetable',
      where: 'period_id = ?',
      whereArgs: [id],
    );
    await _db.delete('lesson_periods', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ClassTimetable>> loadClassTimetable() async {
    final rows = await _db.query('class_timetable');
    return rows.map(_classTimetableFromRow).toList();
  }

  Future<void> insertClassTimetable(ClassTimetable entry) async {
    await _db.insert('class_timetable', _classTimetableToRow(entry));
  }

  Future<void> updateClassTimetable(ClassTimetable entry) async {
    await _db.update(
      'class_timetable',
      _classTimetableToRow(entry),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteClassTimetable(String id) async {
    await _db.delete('class_timetable', where: 'id = ?', whereArgs: [id]);
  }

  // --- School settings ---

  Future<SchoolSettings> loadSchoolSettings({String? schoolId}) async {
    final id = schoolId ?? DatabaseService.defaultSchoolId;
    final rows = await _db.query(
      'school_settings',
      where: 'school_id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return SchoolSettings.emptyFor(id);
    final row = rows.first;
    return SchoolSettings(
      schoolId: id,
      schoolName: row['school_name'] as String? ?? '',
      academicYear:
          row['academic_year'] as String? ??
          SchoolSettings.defaults.academicYear,
      currentSemester:
          row['current_semester'] as String? ??
          SchoolSettings.defaults.currentSemester,
    );
  }

  Future<void> saveSchoolSettings(SchoolSettings settings) async {
    await _db.insert('school_settings', {
      'school_id': settings.schoolId,
      'school_name': settings.schoolName,
      'academic_year': settings.academicYear,
      'current_semester': settings.currentSemester,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Keep school name in sync on the schools table.
    await _db.update(
      'schools',
      {'name': settings.schoolName},
      where: 'id = ?',
      whereArgs: [settings.schoolId],
    );

    // Keep legacy settings row in sync for older backup tooling.
    if (settings.schoolId == DatabaseService.defaultSchoolId) {
      await _db.update(
        'settings',
        {
          'school_name': settings.schoolName,
          'academic_year': settings.academicYear,
          'current_semester': settings.currentSemester,
        },
        where: 'id = ?',
        whereArgs: [1],
      );
    }
  }

  Future<void> insertSchoolSettings(SchoolSettings settings) async {
    await _db.insert('school_settings', {
      'school_id': settings.schoolId,
      'school_name': settings.schoolName,
      'academic_year': settings.academicYear,
      'current_semester': settings.currentSemester,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // --- Legacy settings (backup compatibility) ---

  Future<AppSettings> loadSettings() async {
    final school = await loadSchoolSettings();
    final rows = await _db.query('settings', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) {
      return AppSettings.defaults.copyWith(
        schoolName: school.schoolName,
        academicYear: school.academicYear,
        currentSemester: school.currentSemester,
      );
    }
    final row = rows.first;
    return AppSettings(
      schoolName: school.schoolName,
      schoolCode: row['school_code'] as String? ?? '',
      teacherName: row['teacher_name'] as String? ?? '',
      teacherPhone: row['teacher_phone'] as String? ?? '',
      teacherEmail: row['teacher_email'] as String? ?? '',
      academicYear: school.academicYear,
      currentSemester: school.currentSemester,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    await saveSchoolSettings(
      SchoolSettings(
        schoolId: DatabaseService.defaultSchoolId,
        schoolName: settings.schoolName,
        academicYear: settings.academicYear,
        currentSemester: settings.currentSemester,
      ),
    );
    await _db.insert('settings', {
      'id': 1,
      'school_name': settings.schoolName,
      'school_code': settings.schoolCode,
      'teacher_name': settings.teacherName,
      'teacher_phone': settings.teacherPhone,
      'teacher_email': settings.teacherEmail,
      'theme_mode': 'light',
      'language_code': 'mn',
      'academic_year': settings.academicYear,
      'current_semester': settings.currentSemester,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Teachers ---

  Future<List<Teacher>> loadTeachers() async {
    final rows = await _db.query('teachers', orderBy: 'full_name ASC');
    return rows.map(_teacherFromRow).toList();
  }

  Future<void> insertTeacher(Teacher teacher) async {
    await _db.insert('teachers', _teacherToRow(teacher));
  }

  Future<void> insertTeachers(List<Teacher> teachers) async {
    if (teachers.isEmpty) return;
    final batch = _db.batch();
    for (final teacher in teachers) {
      batch.insert(
        'teachers',
        _teacherToRow(teacher),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateTeacher(Teacher teacher) async {
    await _db.update(
      'teachers',
      _teacherToRow(teacher),
      where: 'id = ?',
      whereArgs: [teacher.id],
    );
  }

  Future<bool> teacherIsLinked(String teacherId) async {
    final home = await _db.query(
      'classes',
      where: 'homeroom_teacher_id = ?',
      whereArgs: [teacherId],
      limit: 1,
    );
    if (home.isNotEmpty) return true;
    final assigned = await _db.query(
      'class_subject_teachers',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
      limit: 1,
    );
    return assigned.isNotEmpty;
  }

  Map<String, Object?> _teacherToRow(Teacher teacher) => {
    'id': teacher.id,
    'full_name': teacher.fullName,
    'school_id': teacher.schoolId,
    'phone': teacher.phone,
    'email': teacher.email,
    'is_active': teacher.isActive ? 1 : 0,
  };

  Teacher _teacherFromRow(Map<String, Object?> row) {
    return Teacher(
      id: row['id']! as String,
      fullName: row['full_name']! as String,
      schoolId: row['school_id'] as String? ?? DatabaseService.defaultSchoolId,
      phone: row['phone'] as String? ?? '',
      email: row['email'] as String? ?? '',
      isActive: (row['is_active'] as int?) != 0,
    );
  }

  // --- Subjects ---

  /// Loads subjects; seeds defaults once if the table is empty.
  Future<List<Subject>> loadSubjectModels() async {
    var rows = await _db.query('subjects', orderBy: 'sort_order ASC, name ASC');
    if (rows.isEmpty) {
      await _seedDefaultSubjects();
      rows = await _db.query('subjects', orderBy: 'sort_order ASC, name ASC');
    }
    return rows.map(_subjectFromRow).toList();
  }

  Future<List<String>> loadSubjects() async {
    final subjects = await loadSubjectModels();
    return subjects
        .where((s) => s.isActive)
        .map((s) => s.name)
        .toList(growable: false);
  }

  Future<void> _seedDefaultSubjects({
    String schoolId = DatabaseService.defaultSchoolId,
  }) async {
    final batch = _db.batch();
    for (var i = 0; i < Subject.defaultNames.length; i++) {
      batch.insert('subjects', {
        'name': Subject.defaultNames[i],
        'school_id': schoolId,
        'sort_order': i,
        'is_active': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<Subject> insertSubject(
    String name, {
    required int sortOrder,
    required String schoolId,
  }) async {
    final id = await _db.insert('subjects', {
      'name': name,
      'school_id': schoolId,
      'sort_order': sortOrder,
      'is_active': 1,
    });
    return Subject(
      id: id,
      name: name,
      schoolId: schoolId,
      sortOrder: sortOrder,
    );
  }

  Future<void> updateSubject(Subject subject) async {
    await _db.update(
      'subjects',
      {
        'name': subject.name,
        'school_id': subject.schoolId,
        'sort_order': subject.sortOrder,
        'is_active': subject.isActive ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [subject.id],
    );
  }

  Future<void> updateSubjectName({
    required String oldName,
    required String newName,
  }) async {
    await _db.update(
      'subjects',
      {'name': newName},
      where: 'name = ?',
      whereArgs: [oldName],
    );
  }

  Future<void> deleteSubject(String name) async {
    await _db.delete('subjects', where: 'name = ?', whereArgs: [name]);
  }

  Future<bool> subjectIsAssigned(int subjectId) async {
    final rows = await _db.query(
      'class_subject_teachers',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Subject _subjectFromRow(Map<String, Object?> row) {
    return Subject(
      id: row['id']! as int,
      name: row['name']! as String,
      schoolId: row['school_id'] as String? ?? DatabaseService.defaultSchoolId,
      sortOrder: row['sort_order'] as int? ?? 0,
      isActive: (row['is_active'] as int?) != 0,
    );
  }

  // --- Class ↔ subject ↔ teacher ---

  Future<List<ClassSubjectTeacher>> loadClassSubjectTeachers() async {
    final rows = await _db.query('class_subject_teachers');
    return rows
        .map(
          (row) => ClassSubjectTeacher(
            classId: row['class_id']! as String,
            subjectId: row['subject_id']! as int,
            teacherId: row['teacher_id']! as String,
          ),
        )
        .toList();
  }

  Future<void> replaceClassAssignments({
    required String classId,
    required String? homeroomTeacherId,
    required List<ClassSubjectTeacher> assignments,
  }) async {
    await _db.transaction((txn) async {
      await txn.update(
        'classes',
        {'homeroom_teacher_id': homeroomTeacherId},
        where: 'name = ?',
        whereArgs: [classId],
      );
      await txn.delete(
        'class_subject_teachers',
        where: 'class_id = ?',
        whereArgs: [classId],
      );
      for (final item in assignments) {
        await txn.insert('class_subject_teachers', {
          'class_id': item.classId,
          'subject_id': item.subjectId,
          'teacher_id': item.teacherId,
        });
      }
    });
  }

  Future<void> insertClassSubjectTeachers(
    List<ClassSubjectTeacher> items,
  ) async {
    if (items.isEmpty) return;
    final batch = _db.batch();
    for (final item in items) {
      batch.insert('class_subject_teachers', {
        'class_id': item.classId,
        'subject_id': item.subjectId,
        'teacher_id': item.teacherId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // --- Dev test-data helpers (IDs / registers / class names marked TEST) ---

  Future<bool> hasTestData() async {
    final testClass = await _db.query(
      'classes',
      where: 'name LIKE ?',
      whereArgs: const ['Тест %'],
      limit: 1,
    );
    if (testClass.isNotEmpty) return true;

    final testTeacher = await _db.query(
      'teachers',
      where: 'id LIKE ?',
      whereArgs: const ['TEST-T-%'],
      limit: 1,
    );
    if (testTeacher.isNotEmpty) return true;

    final testStudent = await _db.query(
      'students',
      where: 'id LIKE ? OR register LIKE ?',
      whereArgs: const ['TEST%', 'TEST%'],
      limit: 1,
    );
    return testStudent.isNotEmpty;
  }

  /// Deletes only generated test rows; leaves real teacher-entered data intact.
  Future<void> deleteAllTestData() async {
    await _db.transaction((txn) async {
      await txn.delete(
        'user_accounts',
        where:
            'id LIKE ? OR username IN (?, ?, ?) OR teacher_id LIKE ? OR '
            'guardian_id LIKE ? OR student_id LIKE ?',
        whereArgs: const [
          'TEST-U-%',
          'teacher1',
          'guardian1',
          'student1',
          'TEST-T-%',
          'TEST-G-%',
          'TEST%',
        ],
      );
      await txn.delete(
        'guardian_students',
        where: 'guardian_id LIKE ? OR student_id LIKE ?',
        whereArgs: const ['TEST-G-%', 'TEST%'],
      );
      await txn.delete(
        'guardians',
        where: 'id LIKE ?',
        whereArgs: const ['TEST-G-%'],
      );
      await txn.delete(
        'class_subject_teachers',
        where: 'class_id LIKE ? OR teacher_id LIKE ?',
        whereArgs: const ['Тест %', 'TEST-T-%'],
      );
      await txn.delete(
        'grades',
        where: 'id LIKE ? OR class_name LIKE ?',
        whereArgs: const ['TEST%', 'Тест %'],
      );
      await txn.delete(
        'homework',
        where: 'id LIKE ? OR class_name LIKE ?',
        whereArgs: const ['TEST%', 'Тест %'],
      );
      await txn.delete(
        'announcements',
        where: 'id LIKE ? OR class_name LIKE ?',
        whereArgs: const ['TEST%', 'Тест %'],
      );
      await txn.delete(
        'attendance',
        where: 'id LIKE ? OR class_name LIKE ?',
        whereArgs: const ['TEST%', 'Тест %'],
      );
      await txn.delete(
        'students',
        where: 'id LIKE ? OR register LIKE ? OR class_name LIKE ?',
        whereArgs: const ['TEST%', 'TEST%', 'Тест %'],
      );
      await txn.delete(
        'classes',
        where: 'name LIKE ?',
        whereArgs: const ['Тест %'],
      );
      await txn.delete(
        'teachers',
        where: 'id LIKE ?',
        whereArgs: const ['TEST-T-%'],
      );
    });
  }

  // --- Mappers ---

  Map<String, Object?> _studentToRow(Student student) => {
    'id': student.id,
    'class_name': student.className,
    'last_name': student.lastName,
    'first_name': student.firstName,
    'gender': student.gender.name,
    'register': student.register,
    'phone': student.phone,
    'guardian': student.guardian,
    'student_code': student.studentCode,
  };

  Student _studentFromRow(Map<String, Object?> row) {
    return Student(
      id: row['id']! as String,
      className: row['class_name']! as String,
      lastName: row['last_name']! as String,
      firstName: row['first_name']! as String,
      gender: row['gender'] == 'female'
          ? StudentGender.female
          : StudentGender.male,
      register: row['register'] as String?,
      phone: row['phone'] as String?,
      guardian: row['guardian'] as String?,
      studentCode: row['student_code'] as String?,
    );
  }

  Map<String, Object?> _attendanceToRow(AttendanceRecord record) {
    String? entriesJson;
    if (record.entries != null) {
      entriesJson = encodeAttendanceEntries(
        record.entries!
            .map((e) => {'studentName': e.studentName, 'status': e.status.name})
            .toList(),
      );
    }

    return {
      'id': record.id,
      'class_name': record.className,
      'date': record.date,
      'present_count': record.presentCount,
      'late_count': record.lateCount,
      'absent_count': record.absentCount,
      'entries_json': entriesJson,
      'legacy_status': record.status?.name,
    };
  }

  AttendanceRecord _attendanceFromRow(Map<String, Object?> row) {
    final entriesRaw = decodeAttendanceEntries(row['entries_json'] as String?);
    final entries = entriesRaw
        .map(
          (e) => StudentAttendanceEntry(
            studentName: e['studentName']?.toString() ?? '',
            status: _attendanceStatusFrom(e['status']?.toString()),
          ),
        )
        .where((e) => e.studentName.isNotEmpty)
        .toList();

    final legacy = row['legacy_status'] as String?;

    return AttendanceRecord(
      id: row['id']! as String,
      date: row['date']! as String,
      className: row['class_name']! as String,
      presentCount: row['present_count']! as int,
      lateCount: row['late_count']! as int,
      absentCount: row['absent_count']! as int,
      entries: entries.isEmpty ? null : List.unmodifiable(entries),
      status: legacy == null ? null : _attendanceStatusFrom(legacy),
    );
  }

  AttendanceStatus _attendanceStatusFrom(String? raw) {
    switch (raw) {
      case 'late':
        return AttendanceStatus.late;
      case 'absent':
        return AttendanceStatus.absent;
      default:
        return AttendanceStatus.present;
    }
  }

  Map<String, Object?> _gradeToRow(Grade grade) => {
    'id': grade.id,
    'class_name': grade.className,
    'student_id': grade.studentId,
    'student_name': grade.studentName,
    'subject': grade.subject,
    'score': grade.score,
    'term': grade.term,
    'letter_grade': grade.letterGrade,
  };

  Grade _gradeFromRow(Map<String, Object?> row) {
    return Grade(
      id: row['id']! as String,
      className: row['class_name']! as String,
      studentId: row['student_id']! as String,
      studentName: row['student_name']! as String,
      subject: row['subject']! as String,
      score: row['score']! as String,
      term: row['term']! as String,
      letterGrade: row['letter_grade'] as String?,
    );
  }

  Map<String, Object?> _homeworkToRow(Homework homework) => {
    'id': homework.id,
    'class_name': homework.className,
    'subject': homework.subject,
    'title': homework.title,
    'description': homework.description,
    'due_date': homework.dueDate,
    'status': homework.status.storageValue,
  };

  Homework _homeworkFromRow(Map<String, Object?> row) {
    return Homework(
      id: row['id']! as String,
      className: row['class_name']! as String,
      subject: row['subject']! as String,
      title: row['title']! as String,
      description: row['description']! as String,
      dueDate: row['due_date']! as String,
      status: HomeworkStatus.fromStorage(row['status']! as String),
    );
  }

  Map<String, Object?> _announcementToRow(Announcement item) => {
    'id': item.id,
    'class_name': item.className,
    'school_id': item.schoolId,
    'title': item.title,
    'body': item.body,
    'date': item.date,
    'is_featured': item.isFeatured ? 1 : 0,
  };

  Announcement _announcementFromRow(Map<String, Object?> row) {
    return Announcement(
      id: row['id']! as String,
      schoolId: row['school_id'] as String? ?? DatabaseService.defaultSchoolId,
      className: row['class_name']! as String,
      title: row['title']! as String,
      body: row['body']! as String,
      date: row['date']! as String,
      isFeatured: (row['is_featured'] as int?) == 1,
    );
  }

  Map<String, Object?> _teacherNoteToRow(TeacherNote note) => {
    'id': note.id,
    'student_id': note.studentId,
    'teacher_id': note.teacherId,
    'subject_id': note.subjectId,
    'created_at': note.createdAt,
    'title': note.title,
    'message': note.message,
    'priority': note.priority.storageValue,
    'is_visible_to_guardian': note.isVisibleToGuardian ? 1 : 0,
    'is_visible_to_student': note.isVisibleToStudent ? 1 : 0,
  };

  TeacherNote _teacherNoteFromRow(Map<String, Object?> row) {
    return TeacherNote(
      id: row['id']! as String,
      studentId: row['student_id']! as String,
      teacherId: row['teacher_id']! as String,
      subjectId: row['subject_id'] as int?,
      createdAt: row['created_at']! as String,
      title: row['title']! as String,
      message: row['message']! as String,
      priority: NotePriority.fromStorage(row['priority']! as String),
      isVisibleToGuardian: (row['is_visible_to_guardian'] as int?) == 1,
      isVisibleToStudent: (row['is_visible_to_student'] as int?) == 1,
    );
  }

  Map<String, Object?> _lessonPeriodToRow(LessonPeriod period) => {
    'id': period.id,
    'school_id': period.schoolId,
    'period_number': period.periodNumber,
    'start_time': period.startTime,
    'end_time': period.endTime,
  };

  LessonPeriod _lessonPeriodFromRow(Map<String, Object?> row) {
    return LessonPeriod(
      id: row['id']! as String,
      schoolId: row['school_id'] as String? ?? DatabaseService.defaultSchoolId,
      periodNumber: row['period_number']! as int,
      startTime: row['start_time']! as String,
      endTime: row['end_time']! as String,
    );
  }

  Map<String, Object?> _classTimetableToRow(ClassTimetable entry) => {
    'id': entry.id,
    'class_id': entry.classId,
    'weekday': entry.weekday,
    'period_id': entry.periodId,
    'subject_id': entry.subjectId,
  };

  ClassTimetable _classTimetableFromRow(Map<String, Object?> row) {
    return ClassTimetable(
      id: row['id']! as String,
      classId: row['class_id']! as String,
      weekday: row['weekday']! as int,
      periodId: row['period_id']! as String,
      subjectId: row['subject_id']! as int,
    );
  }

  // --- App prefs / guardian read state ---

  Future<String?> getPref(String key) async {
    final rows = await _db.query(
      'app_prefs',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setPref(String key, String value) async {
    await _db.insert('app_prefs', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearPref(String key) async {
    await _db.delete('app_prefs', where: 'key = ?', whereArgs: [key]);
  }

  Future<Set<String>> loadGuardianReadAnnouncementIds() async {
    final rows = await _db.query('guardian_read_announcements');
    return rows.map((row) => row['announcement_id']! as String).toSet();
  }

  Future<void> markGuardianAnnouncementRead(String announcementId) async {
    await _db.insert('guardian_read_announcements', {
      'announcement_id': announcementId,
      'read_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Guardians ---

  Future<List<Guardian>> loadGuardians() async {
    final rows = await _db.query('guardians', orderBy: 'full_name ASC');
    return rows.map(_guardianFromRow).toList();
  }

  Future<void> insertGuardian(Guardian guardian) async {
    await _db.insert('guardians', _guardianToRow(guardian));
  }

  Future<void> updateGuardian(Guardian guardian) async {
    await _db.update(
      'guardians',
      _guardianToRow(guardian),
      where: 'id = ?',
      whereArgs: [guardian.id],
    );
  }

  Future<List<GuardianStudent>> loadGuardianStudents() async {
    final rows = await _db.query('guardian_students');
    return rows
        .map(
          (row) => GuardianStudent(
            guardianId: row['guardian_id']! as String,
            studentId: row['student_id']! as String,
            relationship: row['relationship']! as String,
          ),
        )
        .toList();
  }

  Future<void> replaceGuardianStudentLinks({
    required String guardianId,
    required List<GuardianStudent> links,
  }) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'guardian_students',
        where: 'guardian_id = ?',
        whereArgs: [guardianId],
      );
      for (final link in links) {
        await txn.insert('guardian_students', {
          'guardian_id': link.guardianId,
          'student_id': link.studentId,
          'relationship': link.relationship,
        });
      }
    });
  }

  Future<void> insertGuardianStudentLinks(List<GuardianStudent> links) async {
    if (links.isEmpty) return;
    final batch = _db.batch();
    for (final link in links) {
      batch.insert('guardian_students', {
        'guardian_id': link.guardianId,
        'student_id': link.studentId,
        'relationship': link.relationship,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Inserts student (+ optional new guardian) and link atomically.
  Future<void> insertStudentWithGuardianTxn({
    required Student student,
    Guardian? newGuardian,
    required GuardianStudent link,
    required bool createLink,
    UserAccount? newStudentAccount,
    UserSchoolMembership? newStudentMembership,
    UserAccount? newGuardianAccount,
    UserSchoolMembership? newGuardianMembership,
  }) async {
    await _db.transaction((txn) async {
      await txn.insert('students', _studentToRow(student));
      if (newGuardian != null) {
        await txn.insert('guardians', _guardianToRow(newGuardian));
      }
      if (createLink) {
        await txn.insert('guardian_students', {
          'guardian_id': link.guardianId,
          'student_id': link.studentId,
          'relationship': link.relationship,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      if (newStudentAccount != null) {
        await txn.insert('user_accounts', _userToRow(newStudentAccount));
      }
      if (newStudentMembership != null) {
        await txn.insert(
          'user_school_memberships',
          _membershipToRow(newStudentMembership),
        );
      }
      if (newGuardianAccount != null) {
        await txn.insert('user_accounts', _userToRow(newGuardianAccount));
      }
      if (newGuardianMembership != null) {
        await txn.insert(
          'user_school_memberships',
          _membershipToRow(newGuardianMembership),
        );
      }
    });
  }

  /// Provisions login accounts for an existing student (+ optional guardian) atomically.
  Future<void> provisionStudentLoginTxn({
    required Student student,
    required UserAccount studentAccount,
    required UserSchoolMembership studentMembership,
    UserAccount? newGuardianAccount,
    UserSchoolMembership? newGuardianMembership,
  }) async {
    await _db.transaction((txn) async {
      await txn.update(
        'students',
        _studentToRow(student),
        where: 'id = ?',
        whereArgs: [student.id],
      );
      await txn.insert('user_accounts', _userToRow(studentAccount));
      await txn.insert(
        'user_school_memberships',
        _membershipToRow(studentMembership),
      );
      if (newGuardianAccount != null) {
        await txn.insert('user_accounts', _userToRow(newGuardianAccount));
      }
      if (newGuardianMembership != null) {
        await txn.insert(
          'user_school_memberships',
          _membershipToRow(newGuardianMembership),
        );
      }
    });
  }

  Map<String, Object?> _guardianToRow(Guardian g) => {
    'id': g.id,
    'full_name': g.fullName,
    'school_id': g.schoolId,
    'phone': g.phone,
    'email': g.email,
    'is_active': g.isActive ? 1 : 0,
  };

  Guardian _guardianFromRow(Map<String, Object?> row) {
    return Guardian(
      id: row['id']! as String,
      fullName: row['full_name']! as String,
      schoolId: row['school_id'] as String? ?? DatabaseService.defaultSchoolId,
      phone: row['phone'] as String? ?? '',
      email: row['email'] as String? ?? '',
      isActive: (row['is_active'] as int?) != 0,
    );
  }

  // --- User accounts ---

  Future<List<UserAccount>> loadUserAccounts() async {
    final rows = await _db.query('user_accounts', orderBy: 'username ASC');
    return rows.map(_userFromRow).toList();
  }

  Future<void> insertUserAccount(UserAccount user) async {
    await _db.insert('user_accounts', _userToRow(user));
  }

  Future<void> updateUserAccount(UserAccount user) async {
    await _db.update(
      'user_accounts',
      _userToRow(user),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<UserAccount?> findUserByUsername(String username) async {
    final rows = await _db.query(
      'user_accounts',
      where: 'username = ?',
      whereArgs: [username.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _userFromRow(rows.first);
  }

  Map<String, Object?> _userToRow(UserAccount user) => {
    'id': user.id,
    'username': user.username,
    'password_hash': user.passwordHash,
    'role': user.role.storageValue,
    'teacher_id': user.teacherId,
    'guardian_id': user.guardianId,
    'student_id': user.studentId,
    'is_active': user.isActive ? 1 : 0,
    'account_status': user.status.storageValue,
    'created_at': user.createdAt.toIso8601String(),
  };

  UserAccount _userFromRow(Map<String, Object?> row) {
    return UserAccount(
      id: row['id']! as String,
      username: row['username']! as String,
      passwordHash: row['password_hash']! as String,
      role: AppRole.tryParse(row['role'] as String?) ?? AppRole.teacher,
      teacherId: row['teacher_id'] as String?,
      guardianId: row['guardian_id'] as String?,
      studentId: row['student_id'] as String?,
      isActive: (row['is_active'] as int?) != 0,
      status: AccountStatus.fromStorage(row['account_status'] as String?),
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
