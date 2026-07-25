import 'dart:math';

import '../models/announcement.dart';
import '../models/app_role.dart';
import '../models/attendance_record.dart';
import '../models/class_subject_teacher.dart';
import '../models/grade.dart';
import '../models/guardian.dart';
import '../models/guardian_student.dart';
import '../models/homework.dart';
import '../models/student.dart';
import '../models/subject.dart';
import '../models/teacher.dart';
import '../models/user_account.dart';
import '../repositories/edubridge_repository.dart';
import '../services/password_hasher.dart';
import '../state/app_store.dart';

/// Progress callback for long-running generation (keeps UI responsive).
typedef TestDataProgress = void Function(String message, double? progress);

/// Result counters after a generation pass.
class TestDataGenerationResult {
  const TestDataGenerationResult({
    this.classes = 0,
    this.students = 0,
    this.attendanceRecords = 0,
    this.attendanceEntries = 0,
    this.grades = 0,
    this.homework = 0,
    this.announcements = 0,
  });

  final int classes;
  final int students;
  final int attendanceRecords;
  final int attendanceEntries;
  final int grades;
  final int homework;
  final int announcements;
}

/// Development-only SQLite test-data generator for performance testing.
///
/// Identification markers (no schema column):
/// - class names: `Тест …`
/// - student / attendance / grade / homework / announcement IDs: `TEST…`
/// - student registers: `TEST000001` …
class TestDataGenerator {
  TestDataGenerator({
    required this.repository,
    required this.store,
    Random? random,
  }) : _random = random ?? Random(42);

  final EduBridgeRepository repository;
  final AppStore store;
  final Random _random;

  static const int classCount = 25;
  static const int studentsPerClass = 40;
  static const int totalStudents = classCount * studentsPerClass; // 1000
  static const int attendanceDaysPerClass = 5; // 5 * 25 * 40 = 5000 entries
  static const int gradesPerStudent = 3;
  static const int homeworkPerClass = 8;
  static const int announcementsPerClass = 4;

  static const _firstNames = [
    'Амар',
    'Сараа',
    'Наран',
    'Тэмүүлэн',
    'Энхжин',
    'Болд',
    'Мөнх',
    'Ану',
    'Номин',
    'Бат',
    'Оюун',
    'Ганбат',
    'Сэлэнгэ',
    'Төгс',
    'Эрдэнэ',
  ];

  static const _lastNames = [
    'Бат',
    'Дорж',
    'Сүх',
    'Цэцэг',
    'Ган',
    'Энх',
    'Мөнх',
    'Амар',
    'Лхагва',
    'Пүрэв',
  ];

  static const _guardianFirst = [
    'Болд',
    'Сараа',
    'Энхээ',
    'Оюун',
    'Ганзориг',
    'Цэцэг',
  ];

  static const subjects = Subject.defaultNames;

  static const terms = ['1-р улирал', '2-р улирал', '3-р улирал', '4-р улирал'];

  static const _teacherNames = [
    'Д.Эрдэнэ',
    'Б.Болор',
    'Ц.Оюун',
    'С.Бат',
    'Г.Сараа',
    'Н.Тэмүүлэн',
    'А.Мөнх',
    'Л.Энхжин',
  ];

  static List<String> buildTestClassNames() {
    const letters = ['А', 'Б'];
    final names = <String>[];
    var grade = 1;
    var letterIndex = 0;
    while (names.length < classCount) {
      names.add('Тест $grade${letters[letterIndex]}');
      letterIndex++;
      if (letterIndex >= letters.length) {
        letterIndex = 0;
        grade++;
      }
    }
    return names;
  }

  Future<bool> hasTestData() => repository.hasTestData();

  Future<void> deleteAllTestData({TestDataProgress? onProgress}) async {
    onProgress?.call('Тестийн өгөгдөл устгаж байна…', null);
    await repository.deleteAllTestData();
    await store.load(); // single refresh
    onProgress?.call('Тестийн өгөгдөл устгагдлаа', 1);
  }

  /// Yields to the event loop so Flutter can paint progress updates.
  Future<void> _yieldUi() => Future<void>.delayed(Duration.zero);

  String _formatDate(DateTime d) => '${d.year} оны ${d.month} сарын ${d.day}';

  String _padRegister(int n) => 'TEST${n.toString().padLeft(6, '0')}';

  String _phone(int n) => (90000000 + n).toString();

  /// A. 25 classes + 1000 students.
  Future<TestDataGenerationResult> generateStudents({
    TestDataProgress? onProgress,
    bool replaceExisting = false,
  }) async {
    if (await hasTestData()) {
      if (!replaceExisting) {
        throw StateError('TEST_DATA_EXISTS');
      }
      await deleteAllTestData(onProgress: onProgress);
    }

    final classNames = buildTestClassNames();
    onProgress?.call('Тест ангиуд үүсгэж байна…', 0);
    await repository.insertClasses(classNames);
    await _ensureTestTeachersAndAssignments(classNames);
    await _yieldUi();

    final students = <Student>[];
    var index = 0;
    for (final className in classNames) {
      for (var i = 0; i < studentsPerClass; i++) {
        index++;
        final first = _firstNames[_random.nextInt(_firstNames.length)];
        final last = _lastNames[_random.nextInt(_lastNames.length)];
        final gender = index.isEven ? StudentGender.male : StudentGender.female;
        final guardianFirst =
            _guardianFirst[_random.nextInt(_guardianFirst.length)];
        final guardianLast = _lastNames[_random.nextInt(_lastNames.length)];

        students.add(
          Student(
            id: 'TEST-S-${index.toString().padLeft(6, '0')}',
            className: className,
            lastName: last,
            firstName: first,
            gender: gender,
            register: _padRegister(index),
            phone: _phone(index),
            guardian: '$guardianLast $guardianFirst',
          ),
        );
      }
    }

    const chunk = 100;
    for (var offset = 0; offset < students.length; offset += chunk) {
      final end = min(offset + chunk, students.length);
      await repository.insertStudents(students.sublist(offset, end));
      onProgress?.call(
        '$end / $totalStudents сурагч үүсгэж байна',
        end / totalStudents,
      );
      await _yieldUi();
    }

    await store.load();
    await _ensureTestUsersAndGuardians();
    onProgress?.call('1000 сурагчийн тест өгөгдөл амжилттай үүслээ', 1);

    return TestDataGenerationResult(
      classes: classNames.length,
      students: students.length,
    );
  }

  /// Creates reusable test users (teacher1 / guardian1 / student1) once.
  Future<void> _ensureTestUsersAndGuardians() async {
    const password = 'test123';
    final hash = PasswordHasher.hashPassword(password);

    // Ensure at least one TEST teacher exists.
    var teachers = store.teachers.where((t) => t.id.startsWith('TEST-T-'));
    if (teachers.isEmpty && store.activeTeachers.isNotEmpty) {
      teachers = store.activeTeachers;
    }
    final teacher = teachers.isEmpty ? null : teachers.first;

    final testStudents = store.allStudents
        .where((s) => s.id.startsWith('TEST'))
        .toList();
    if (testStudents.isEmpty) return;

    Guardian? guardian;
    for (final g in store.guardians) {
      if (g.id == 'TEST-G-001') {
        guardian = g;
        break;
      }
    }
    if (guardian == null) {
      guardian = const Guardian(
        id: 'TEST-G-001',
        schoolId: AppStore.defaultSchoolId,
        fullName: 'Б. Болормаа',
        phone: '99110011',
        email: 'guardian1@edubridge.local',
      );
      await repository.insertGuardian(guardian);
    }

    final linkStudents = testStudents.take(2).toList();
    await repository.insertGuardianStudentLinks([
      for (var i = 0; i < linkStudents.length; i++)
        GuardianStudent(
          guardianId: guardian.id,
          studentId: linkStudents[i].id,
          relationship: i == 0 ? 'Ээж' : 'Ээж',
        ),
    ]);

    Future<void> upsertUser({
      required String id,
      required String username,
      required AppRole role,
      String? teacherId,
      String? guardianId,
      String? studentId,
    }) async {
      final existing = await repository.findUserByUsername(username);
      if (existing != null) return;
      await repository.insertUserAccount(
        UserAccount(
          id: id,
          username: username,
          passwordHash: hash,
          role: role,
          teacherId: teacherId,
          guardianId: guardianId,
          studentId: studentId,
          createdAt: DateTime.now(),
        ),
      );
    }

    if (teacher != null) {
      await upsertUser(
        id: 'TEST-U-teacher1',
        username: 'teacher1',
        role: AppRole.teacher,
        teacherId: teacher.id,
      );
    }
    await upsertUser(
      id: 'TEST-U-guardian1',
      username: 'guardian1',
      role: AppRole.guardian,
      guardianId: guardian.id,
    );
    await upsertUser(
      id: 'TEST-U-student1',
      username: 'student1',
      role: AppRole.student,
      studentId: testStudents.first.id,
    );

    await store.load();
  }

  Future<List<Student>> _loadTestStudents() async {
    final all = await repository.loadStudents();
    return all.where((s) => s.id.startsWith('TEST')).toList();
  }

  Future<List<String>> _loadTestClasses() async {
    final all = await repository.loadClasses();
    return all.where((c) => c.startsWith('Тест ')).toList();
  }

  /// Creates TEST teachers and assigns them to every test class/subject.
  Future<void> _ensureTestTeachersAndAssignments(
    List<String> classNames,
  ) async {
    final teachers = <Teacher>[
      for (var i = 0; i < _teacherNames.length; i++)
        Teacher(
          id: 'TEST-T-${(i + 1).toString().padLeft(3, '0')}',
          schoolId: AppStore.defaultSchoolId,
          fullName: _teacherNames[i],
          phone: _phone(8000 + i),
          email: 'test.teacher${i + 1}@edubridge.local',
        ),
    ];
    await repository.insertTeachers(teachers);

    // Ensure default subjects exist and load IDs.
    await store.load();
    final subjects = store.activeSubjects;
    if (subjects.isEmpty) return;

    final assignments = <ClassSubjectTeacher>[];
    for (var i = 0; i < classNames.length; i++) {
      final className = classNames[i];
      // Primary-style: grades 1–5 use one teacher for all subjects.
      final isPrimary = className.contains(RegExp(r'Тест [1-5]'));
      final homeroom = teachers[i % teachers.length];
      await repository.updateClassHomeroom(
        classId: className,
        teacherId: homeroom.id,
      );

      for (var s = 0; s < subjects.length; s++) {
        final teacher = isPrimary
            ? homeroom
            : teachers[(i + s) % teachers.length];
        assignments.add(
          ClassSubjectTeacher(
            classId: className,
            subjectId: subjects[s].id,
            teacherId: teacher.id,
          ),
        );
      }
    }
    await repository.insertClassSubjectTeachers(assignments);
  }

  /// B. ≥5000 attendance student-entries across dates/classes.
  Future<TestDataGenerationResult> generateAttendance({
    TestDataProgress? onProgress,
  }) async {
    final students = await _loadTestStudents();
    final classes = await _loadTestClasses();
    if (students.isEmpty || classes.isEmpty) {
      throw StateError('NO_TEST_STUDENTS');
    }

    // Remove previous TEST attendance only (keep students).
    await repository.database.delete(
      'attendance',
      where: 'id LIKE ? OR class_name LIKE ?',
      whereArgs: const ['TEST%', 'Тест %'],
    );

    final byClass = <String, List<Student>>{};
    for (final s in students) {
      byClass.putIfAbsent(s.className, () => []).add(s);
    }

    final now = DateTime.now();
    final records = <AttendanceRecord>[];
    var entryCount = 0;
    var recordIndex = 0;

    for (final className in classes) {
      final classStudents = byClass[className] ?? const <Student>[];
      if (classStudents.isEmpty) continue;

      for (var day = 0; day < attendanceDaysPerClass; day++) {
        recordIndex++;
        final date = now.subtract(Duration(days: day + 1));
        final entries = classStudents.map((s) {
          final roll = _random.nextInt(10);
          final status = roll < 7
              ? AttendanceStatus.present
              : roll < 9
              ? AttendanceStatus.late
              : AttendanceStatus.absent;
          return StudentAttendanceEntry(
            studentName: s.fullName,
            status: status,
          );
        }).toList();

        entryCount += entries.length;
        records.add(
          AttendanceRecord.detailed(
            id: 'TEST-ATT-${recordIndex.toString().padLeft(6, '0')}',
            date: _formatDate(date),
            className: className,
            entries: entries,
          ),
        );
      }
    }

    const chunk = 25;
    for (var offset = 0; offset < records.length; offset += chunk) {
      final end = min(offset + chunk, records.length);
      await repository.insertAttendanceRecords(records.sublist(offset, end));
      onProgress?.call(
        '$end / ${records.length} ирцийн бүртгэл үүсгэж байна',
        end / records.length,
      );
      await _yieldUi();
    }

    await store.load();
    onProgress?.call('$entryCount ирцийн бүртгэл амжилттай үүслээ', 1);

    return TestDataGenerationResult(
      attendanceRecords: records.length,
      attendanceEntries: entryCount,
    );
  }

  /// C. Grades + homework + announcements for all test classes/students.
  Future<TestDataGenerationResult> generateGradesHomeworkAnnouncements({
    TestDataProgress? onProgress,
  }) async {
    final students = await _loadTestStudents();
    final classes = await _loadTestClasses();
    if (students.isEmpty || classes.isEmpty) {
      throw StateError('NO_TEST_STUDENTS');
    }

    final db = repository.database;
    await db.delete(
      'grades',
      where: 'id LIKE ? OR class_name LIKE ?',
      whereArgs: const ['TEST%', 'Тест %'],
    );
    await db.delete(
      'homework',
      where: 'id LIKE ? OR class_name LIKE ?',
      whereArgs: const ['TEST%', 'Тест %'],
    );
    await db.delete(
      'announcements',
      where: 'id LIKE ? OR class_name LIKE ?',
      whereArgs: const ['TEST%', 'Тест %'],
    );

    // --- Grades ---
    onProgress?.call('Дүн үүсгэж байна…', 0);
    final grades = <Grade>[];
    var gradeIndex = 0;
    for (final student in students) {
      for (var g = 0; g < gradesPerStudent; g++) {
        gradeIndex++;
        final score = 40 + _random.nextInt(61); // 40–100
        final subject = subjects[(gradeIndex + g) % subjects.length];
        final term = terms[g % terms.length];
        grades.add(
          Grade(
            id: 'TEST-GR-${gradeIndex.toString().padLeft(6, '0')}',
            className: student.className,
            studentId: student.id,
            studentName: student.fullName,
            subject: subject,
            score: '$score',
            term: term,
            letterGrade: Grade.letterFromScore(score),
          ),
        );
      }
    }

    const gradeChunk = 150;
    for (var offset = 0; offset < grades.length; offset += gradeChunk) {
      final end = min(offset + gradeChunk, grades.length);
      await repository.insertGrades(grades.sublist(offset, end));
      onProgress?.call(
        '$end / ${grades.length} дүн үүсгэж байна',
        end / grades.length * 0.7,
      );
      await _yieldUi();
    }

    // --- Homework ---
    onProgress?.call('Даалгавар үүсгэж байна…', 0.72);
    final now = DateTime.now();
    final homework = <Homework>[];
    var hwIndex = 0;
    for (final className in classes) {
      for (var h = 0; h < homeworkPerClass; h++) {
        hwIndex++;
        final subject = subjects[h % subjects.length];
        final due = now.add(Duration(days: 3 + h * 2));
        homework.add(
          Homework(
            id: 'TEST-HW-${hwIndex.toString().padLeft(6, '0')}',
            className: className,
            subject: subject,
            title: '$subject — тест даалгавар ${h + 1}',
            description: 'Гүйцэтгэлийн тестийг хийж ирээрэй.',
            dueDate: _formatDate(due),
            status: h.isEven ? HomeworkStatus.pending : HomeworkStatus.done,
          ),
        );
      }
    }
    await repository.insertHomeworkList(homework);
    await _yieldUi();

    // --- Announcements ---
    onProgress?.call('Зарлал үүсгэж байна…', 0.88);
    final announcements = <Announcement>[];
    var annIndex = 0;
    for (final className in classes) {
      for (var a = 0; a < announcementsPerClass; a++) {
        annIndex++;
        final day = now.subtract(Duration(days: a));
        announcements.add(
          Announcement(
            id: 'TEST-ANN-${annIndex.toString().padLeft(6, '0')}',
            schoolId: AppStore.defaultSchoolId,
            className: className,
            title: 'Тест зарлал ${a + 1} ($className)',
            body: 'Энэ бол хөгжүүлэлтийн тестийн зарлал юм.',
            date: _formatDate(day),
            isFeatured: a == 0,
          ),
        );
      }
    }
    await repository.insertAnnouncements(announcements);

    await store.load();
    onProgress?.call('Дүн, даалгавар, зарлал амжилттай үүслээ', 1);

    return TestDataGenerationResult(
      grades: grades.length,
      homework: homework.length,
      announcements: announcements.length,
    );
  }
}
