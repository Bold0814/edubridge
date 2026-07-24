import 'package:flutter/foundation.dart';

import '../data/sample_announcement.dart';
import '../data/sample_attendance.dart';
import '../data/sample_classes.dart';
import '../data/sample_grades.dart';
import '../data/sample_homework.dart';
import '../data/sample_students.dart';
import '../models/announcement.dart';
import '../models/attendance_record.dart';
import '../models/grade.dart';
import '../models/homework.dart';
import '../models/student.dart';

class AppStore extends ChangeNotifier {
  AppStore() {
    _announcements = List<Announcement>.of(sampleAnnouncementList);
    _homework = List<Homework>.of(sampleHomeworkList);
    _grades = List<Grade>.of(sampleGradeList);
    _attendanceByClass = {
      for (final className in sampleClasses)
        className: List<AttendanceRecord>.of(sampleAttendanceRecords),
    };
    _studentsByClass = {
      for (final className in sampleClasses)
        className: List<Student>.of(
          sampleStudentsByClass[className] ?? const <Student>[],
        ),
    };
  }

  late final List<Announcement> _announcements;
  late final List<Homework> _homework;
  late final List<Grade> _grades;
  late final Map<String, List<AttendanceRecord>> _attendanceByClass;
  late final Map<String, List<Student>> _studentsByClass;
  final Map<String, String?> _journalSubjectByClass = {};
  final Map<String, String?> _journalTermByClass = {};
  int _studentIdCounter = 1000;

  List<Announcement> announcementsFor(String className) {
    return _announcements
        .where((item) => item.className == className)
        .toList(growable: false);
  }

  List<Homework> homeworkFor(String className) {
    return _homework
        .where((item) => item.className == className)
        .toList(growable: false);
  }

  List<Grade> gradesFor(String className) {
    return _grades
        .where((item) => item.className == className)
        .toList(growable: false);
  }

  List<AttendanceRecord> attendanceFor(String className) {
    return List<AttendanceRecord>.unmodifiable(
      _attendanceByClass[className] ?? const <AttendanceRecord>[],
    );
  }

  List<Student> studentsFor(String className) {
    return List<Student>.unmodifiable(
      _studentsByClass[className] ?? const <Student>[],
    );
  }

  String? journalSubjectFor(String className) =>
      _journalSubjectByClass[className];

  String? journalTermFor(String className) => _journalTermByClass[className];

  void setJournalSubject(String className, String? subject) {
    if (_journalSubjectByClass[className] == subject) return;
    _journalSubjectByClass[className] = subject;
    notifyListeners();
  }

  void setJournalTerm(String className, String? term) {
    if (_journalTermByClass[className] == term) return;
    _journalTermByClass[className] = term;
    notifyListeners();
  }

  String nextStudentId(String className) {
    _studentIdCounter += 1;
    return '$className-$_studentIdCounter';
  }

  void addAnnouncement(Announcement announcement) {
    _announcements.insert(0, announcement);
    notifyListeners();
  }

  void addHomework(Homework homework) {
    _homework.insert(0, homework);
    notifyListeners();
  }

  void addGrade(Grade grade) {
    _grades.insert(0, grade);
    notifyListeners();
  }

  void addGrades(List<Grade> grades) {
    if (grades.isEmpty) return;
    _grades.insertAll(0, grades);
    notifyListeners();
  }

  void addAttendance(String className, AttendanceRecord record) {
    final records = _attendanceByClass.putIfAbsent(
      className,
      () => <AttendanceRecord>[],
    );
    records.insert(0, record);
    notifyListeners();
  }

  void addStudent(Student student) {
    final students = _studentsByClass.putIfAbsent(
      student.className,
      () => <Student>[],
    );
    students.add(student);
    notifyListeners();
  }

  void updateStudent(Student student) {
    final students = _studentsByClass[student.className];
    if (students == null) return;

    final index = students.indexWhere((item) => item.id == student.id);
    if (index < 0) return;

    students[index] = student;

    for (var i = 0; i < _grades.length; i++) {
      final grade = _grades[i];
      if (grade.studentId == student.id) {
        _grades[i] = Grade(
          className: grade.className,
          studentId: grade.studentId,
          studentName: student.fullName,
          subject: grade.subject,
          score: grade.score,
          term: grade.term,
          letterGrade: grade.letterGrade ?? grade.resolvedLetterGrade,
        );
      }
    }

    notifyListeners();
  }

  void deleteStudent(String className, String studentId) {
    final students = _studentsByClass[className];
    if (students == null) return;

    students.removeWhere((item) => item.id == studentId);
    notifyListeners();
  }
}
