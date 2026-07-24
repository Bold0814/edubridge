import 'package:flutter/material.dart';

import '../models/attendance_record.dart';
import '../models/grade.dart';
import '../models/homework.dart';
import '../models/student.dart';
import '../state/app_store.dart';
import 'announcement_create_screen.dart';
import 'attendance_take_screen.dart';
import 'bulk_grade_entry_screen.dart';
import 'homework_create_screen.dart';
import 'student_detail_screen.dart';

class ClassJournalScreen extends StatefulWidget {
  const ClassJournalScreen({
    super.key,
    required this.selectedClass,
    required this.store,
  });

  final String selectedClass;
  final AppStore store;

  @override
  State<ClassJournalScreen> createState() => _ClassJournalScreenState();
}

class _ClassJournalScreenState extends State<ClassJournalScreen> {
  static const _subjects = [
    'Монгол хэл',
    'Математик',
    'Англи хэл',
    'Физик',
    'Хими',
    'Биологи',
    'Түүх',
    'Газар зүй',
    'Мэдээллийн технологи',
  ];

  static const _terms = [
    '1-р улирал',
    '2-р улирал',
    '3-р улирал',
    '4-р улирал',
  ];

  String? get _selectedSubject {
    final value = widget.store.journalSubjectFor(widget.selectedClass);
    if (value != null && _subjects.contains(value)) return value;
    return null;
  }

  String? get _selectedTerm {
    final value = widget.store.journalTermFor(widget.selectedClass);
    if (value != null && _terms.contains(value)) return value;
    return null;
  }

  Future<void> _openAttendance() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceTakeScreen(
          selectedClass: widget.selectedClass,
          store: widget.store,
        ),
      ),
    );
  }

  Future<void> _openAnnouncement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnnouncementCreateScreen(
          className: widget.selectedClass,
          store: widget.store,
        ),
      ),
    );
  }

  Future<void> _openHomeworkCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeworkCreateScreen(
          className: widget.selectedClass,
          store: widget.store,
          initialSubject: _selectedSubject,
        ),
      ),
    );
  }

  Future<void> _openBulkGrades() async {
    final subject = _selectedSubject;
    final term = _selectedTerm;
    if (subject == null || term == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хичээл болон улирлаа сонгоно уу')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkGradeEntryScreen(
          selectedClass: widget.selectedClass,
          store: widget.store,
          initialSubject: subject,
          initialTerm: term,
        ),
      ),
    );
  }

  Future<void> _openStudentDetail(Student student) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailScreen(
          studentId: student.id,
          selectedClass: widget.selectedClass,
          store: widget.store,
        ),
      ),
    );
  }

  AttendanceStatus? _todayStatusFor(
    Student student,
    List<AttendanceRecord> records,
  ) {
    final today = DateTime.now();

    for (final record in records) {
      if (!record.isOnCalendarDay(today) || !record.hasStudentDetails) {
        continue;
      }
      for (final entry in record.entries!) {
        if (entry.studentName == student.fullName) {
          return entry.status;
        }
      }
    }
    return null;
  }

  Grade? _latestGradeFor(
    Student student,
    List<Grade> grades,
    String? subject,
    String? term,
  ) {
    if (subject == null || term == null) return null;

    for (final grade in grades) {
      if (grade.className == widget.selectedClass &&
          grade.studentId == student.id &&
          grade.subject == subject &&
          grade.term == term) {
        return grade;
      }
    }
    return null;
  }

  String _homeworkStatusText(List<Homework> homework, String? subject) {
    if (subject == null) return '—';

    final hasActive = homework.any(
      (item) =>
          item.className == widget.selectedClass &&
          item.subject == subject &&
          item.status == HomeworkStatus.pending,
    );
    return hasActive ? 'Даалгавартай' : 'Байхгүй';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Хичээлийн журнал'), centerTitle: true),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final selectedSubject = _selectedSubject;
          final selectedTerm = _selectedTerm;
          final students = widget.store.studentsFor(widget.selectedClass);
          final attendance = widget.store.attendanceFor(widget.selectedClass);
          final grades = widget.store.gradesFor(widget.selectedClass);
          final homework = widget.store.homeworkFor(widget.selectedClass);
          final homeworkText = _homeworkStatusText(homework, selectedSubject);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${widget.selectedClass} анги',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'journal-subject-${widget.selectedClass}-$selectedSubject',
                ),
                initialValue: selectedSubject,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Хичээл',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Хичээл сонгох'),
                icon: const Icon(Icons.arrow_drop_down),
                items: _subjects
                    .map(
                      (subject) => DropdownMenuItem<String>(
                        value: subject,
                        child: Text(subject, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  widget.store.setJournalSubject(widget.selectedClass, value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'journal-term-${widget.selectedClass}-$selectedTerm',
                ),
                initialValue: selectedTerm,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Улирал',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Улирал сонгох'),
                icon: const Icon(Icons.arrow_drop_down),
                items: _terms
                    .map(
                      (term) => DropdownMenuItem<String>(
                        value: term,
                        child: Text(term, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  widget.store.setJournalTerm(widget.selectedClass, value);
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final buttonWidth = (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _QuickActionButton(
                        width: buttonWidth,
                        icon: Icons.fact_check,
                        label: 'Ирц авах',
                        onPressed: _openAttendance,
                      ),
                      _QuickActionButton(
                        width: buttonWidth,
                        icon: Icons.campaign,
                        label: 'Зарлал',
                        onPressed: _openAnnouncement,
                      ),
                      _QuickActionButton(
                        width: buttonWidth,
                        icon: Icons.assignment_add,
                        label: 'Шинэ даалгавар',
                        onPressed: _openHomeworkCreate,
                      ),
                      _QuickActionButton(
                        width: buttonWidth,
                        icon: Icons.groups,
                        label: 'Ангийн дүн оруулах',
                        onPressed: _openBulkGrades,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              if (students.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Энэ ангид сурагч бүртгэлгүй байна',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                )
              else ...[
                const _JournalHeader(),
                const SizedBox(height: 8),
                ...students.map((student) {
                  final status = _todayStatusFor(student, attendance);
                  final grade = _latestGradeFor(
                    student,
                    grades,
                    selectedSubject,
                    selectedTerm,
                  );

                  return _JournalRow(
                    studentName: student.fullName,
                    attendanceLabel: status?.label ?? 'Бүртгээгүй',
                    attendanceColor: status?.color ?? Colors.grey,
                    gradeText: grade?.scoreWithLetter ?? '—',
                    homeworkText: homeworkText,
                    onTap: () => _openStudentDetail(student),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.width,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final double width;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 48,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }
}

class _JournalHeader extends StatelessWidget {
  const _JournalHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Сурагч', style: style)),
          Expanded(flex: 2, child: Text('Өнөөдрийн ирц', style: style)),
          Expanded(flex: 2, child: Text('Сүүлийн дүн', style: style)),
          Expanded(flex: 2, child: Text('Даалгавар', style: style)),
        ],
      ),
    );
  }
}

class _JournalRow extends StatelessWidget {
  const _JournalRow({
    required this.studentName,
    required this.attendanceLabel,
    required this.attendanceColor,
    required this.gradeText,
    required this.homeworkText,
    required this.onTap,
  });

  final String studentName;
  final String attendanceLabel;
  final Color attendanceColor;
  final String gradeText;
  final String homeworkText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  studentName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  attendanceLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: attendanceColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  gradeText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  homeworkText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
