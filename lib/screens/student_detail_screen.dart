import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../models/attendance_record.dart';
import '../models/grade.dart';
import '../models/homework.dart';
import '../models/student.dart';
import '../state/app_store.dart';
import 'attendance_take_screen.dart';
import 'grade_create_screen.dart';
import 'homework_screen.dart';

class StudentDetailScreen extends StatelessWidget {
  const StudentDetailScreen({
    super.key,
    required this.studentId,
    required this.selectedClass,
    required this.store,
  });

  final String studentId;
  final String selectedClass;
  final AppStore store;

  Future<void> _openAttendance(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AttendanceTakeScreen(selectedClass: selectedClass, store: store),
      ),
    );
  }

  Future<void> _openGradeEdit(BuildContext context, Student student) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GradeCreateScreen(
          className: selectedClass,
          store: store,
          initialStudent: student,
          initialSubject: store.journalSubjectFor(selectedClass),
          initialTerm: store.journalTermFor(selectedClass),
        ),
      ),
    );
  }

  Future<void> _openHomework(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Даалгавар'), centerTitle: true),
          body: HomeworkScreen(selectedClass: selectedClass, store: store),
        ),
      ),
    );
  }

  _AttendanceSummary _attendanceSummary(
    Student student,
    List<AttendanceRecord> records,
  ) {
    var present = 0;
    var late = 0;
    var absent = 0;

    for (final record in records) {
      if (!record.hasStudentDetails) continue;
      for (final entry in record.entries!) {
        if (entry.studentName != student.fullName) continue;
        switch (entry.status) {
          case AttendanceStatus.present:
            present += 1;
          case AttendanceStatus.late:
            late += 1;
          case AttendanceStatus.absent:
            absent += 1;
        }
      }
    }

    return _AttendanceSummary(present: present, late: late, absent: absent);
  }

  List<Grade> _latestGradesBySubject(Student student, List<Grade> grades) {
    final latestBySubject = <String, Grade>{};
    for (final grade in grades) {
      if (grade.className != selectedClass) continue;
      if (grade.studentId != student.id) continue;
      latestBySubject.putIfAbsent(grade.subject, () => grade);
    }
    final result = latestBySubject.values.toList()
      ..sort((a, b) => a.subject.compareTo(b.subject));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сурагчийн дэлгэрэнгүй'),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final students = store.studentsFor(selectedClass);
          Student? student;
          for (final item in students) {
            if (item.id == studentId) {
              student = item;
              break;
            }
          }

          if (student == null) {
            return const Center(child: Text('Сурагч олдсонгүй.'));
          }

          final currentStudent = student;
          final attendance = store.attendanceFor(selectedClass);
          final grades = store.gradesFor(selectedClass);
          final homework = store.homeworkFor(selectedClass);
          final announcements = store.announcementsFor(selectedClass);
          final summary = _attendanceSummary(currentStudent, attendance);
          final latestGrades = _latestGradesBySubject(currentStudent, grades);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                currentStudent.fullName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$selectedClass анги',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: width,
                        height: 48,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _openAttendance(context),
                          icon: const Icon(Icons.fact_check, size: 20),
                          label: const Text(
                            'Ирц засах',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        height: 48,
                        child: FilledButton.tonalIcon(
                          onPressed: () =>
                              _openGradeEdit(context, currentStudent),
                          icon: const Icon(Icons.grade, size: 20),
                          label: const Text(
                            'Дүн засах',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        height: 48,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _openHomework(context),
                          icon: const Icon(Icons.assignment, size: 20),
                          label: const Text(
                            'Даалгавар харах',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Ирц',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ирцийн хувь: ${summary.percentageLabel}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatChip(
                    label: 'Ирсэн',
                    count: summary.present,
                    color: Colors.green,
                  ),
                  _StatChip(
                    label: 'Хоцорсон',
                    count: summary.late,
                    color: Colors.orange,
                  ),
                  _StatChip(
                    label: 'Тасалсан',
                    count: summary.absent,
                    color: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Сүүлийн дүн (хичээлээр)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (latestGrades.isEmpty)
                const Text('Дүн бүртгэгдээгүй')
              else
                ...latestGrades.map((grade) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(grade.subject),
                      subtitle: Text(grade.term),
                      trailing: Text(
                        grade.scoreWithLetter,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),
              Text(
                'Даалгавар',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (homework.isEmpty)
                const Text('Даалгавар байхгүй')
              else
                ...homework.map((item) => _HomeworkTile(homework: item)),
              const SizedBox(height: 24),
              Text(
                'Сүүлийн зарлал',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (announcements.isEmpty)
                const Text('Зарлал байхгүй')
              else
                ...announcements
                    .take(5)
                    .map((item) => _AnnouncementTile(announcement: item)),
            ],
          );
        },
      ),
    );
  }
}

class _AttendanceSummary {
  const _AttendanceSummary({
    required this.present,
    required this.late,
    required this.absent,
  });

  final int present;
  final int late;
  final int absent;

  int get total => present + late + absent;

  String get percentageLabel {
    if (total == 0) return '0%';
    final percent = (present / total * 100).round();
    return '$percent%';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _HomeworkTile extends StatelessWidget {
  const _HomeworkTile({required this.homework});

  final Homework homework;

  @override
  Widget build(BuildContext context) {
    final isDone = homework.status == HomeworkStatus.done;
    final color = isDone ? Colors.green : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isDone ? Icons.assignment_turned_in : Icons.assignment,
          color: color,
        ),
        title: Text(homework.title),
        subtitle: Text('${homework.subject} • ${homework.dueDate}'),
        trailing: Text(
          homework.status.label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          announcement.isFeatured ? Icons.star : Icons.campaign,
          color: announcement.isFeatured ? Colors.amber : Colors.blue,
        ),
        title: Text(announcement.title),
        subtitle: Text(announcement.date),
      ),
    );
  }
}
