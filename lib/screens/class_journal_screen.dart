import 'package:flutter/material.dart';

import '../models/attendance_record.dart';
import '../models/homework.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'attendance_take_screen.dart';
import 'bulk_grade_entry_screen.dart';
import 'homework_create_screen.dart';
import 'homework_screen.dart';
import 'teacher_notes_screen.dart';

/// Date-focused daily lesson record (not a full class management hub).
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
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  String get _dateLabel =>
      '${_selectedDate.year} оны ${_selectedDate.month} сарын ${_selectedDate.day}';

  String? get _selectedSubject {
    final value = widget.store.journalSubjectFor(widget.selectedClass);
    final subjects = widget.store.subjects;
    if (value != null && subjects.contains(value)) return value;
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(_selectedDate.year - 1),
      lastDate: DateTime(_selectedDate.year + 1),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
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

  Future<void> _openHomework() async {
    final subject = _selectedSubject;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeworkScreen(
          selectedClass: widget.selectedClass,
          store: widget.store,
          subjectId: subject == null
              ? widget.store.activeContext.subjectId
              : widget.store.subjectByName(subject)?.id,
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
    final term = widget.store.journalTermFor(widget.selectedClass);
    if (subject == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Хичээлээ сонгоно уу')));
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

  Future<void> _openTeacherNotes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherNotesScreen(
          selectedClass: widget.selectedClass,
          store: widget.store,
        ),
      ),
    );
  }

  List<AttendanceRecord> _attendanceForDay(List<AttendanceRecord> all) {
    return all
        .where((r) => r.isOnCalendarDay(_selectedDate))
        .toList(growable: false);
  }

  List<Homework> _homeworkDueAround(List<Homework> all) {
    final subject = _selectedSubject;
    return all
        .where((h) {
          if (subject != null && h.subject != subject) return false;
          return true;
        })
        .toList(growable: false);
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
          final students = widget.store.studentsFor(widget.selectedClass);
          final attendance = _attendanceForDay(
            widget.store.attendanceFor(widget.selectedClass),
          );
          final homework = _homeworkDueAround(
            widget.store.homeworkFor(widget.selectedClass),
          );
          final notes = widget.store.teacherNotesForClass(widget.selectedClass);

          var present = 0;
          var late = 0;
          var absent = 0;
          for (final record in attendance) {
            present += record.presentCount;
            late += record.lateCount;
            absent += record.absentCount;
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text(
                '${widget.selectedClass} анги',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppSpacing.radius),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Огноо',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(_dateLabel),
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
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
                items: widget.store.subjects
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
              const SizedBox(height: AppSpacing.sectionSm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.card),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Өнөөдрийн ирц',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.item),
                      if (attendance.isEmpty)
                        Text(
                          'Энэ өдөр ирц бүртгээгүй',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        )
                      else
                        Wrap(
                          spacing: AppSpacing.item,
                          runSpacing: AppSpacing.item,
                          children: [
                            StatusBadge(
                              label: 'Ирсэн: $present',
                              color: AppColors.present,
                            ),
                            StatusBadge(
                              label: 'Хоцорсон: $late',
                              color: AppColors.late,
                            ),
                            StatusBadge(
                              label: 'Тасалсан: $absent',
                              color: AppColors.absent,
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Сурагч: ${students.length}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.card),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Даалгавар',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.itemSm),
                      Text(
                        homework.isEmpty
                            ? 'Даалгавар байхгүй'
                            : '${homework.length} даалгавар',
                      ),
                      if (homework.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.item),
                        ...homework.take(3).map((h) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• ${h.title} (${h.dueDate})'),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.card),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Багшийн тэмдэглэл',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.itemSm),
                      Text(
                        notes.isEmpty
                            ? 'Тэмдэглэл байхгүй'
                            : '${notes.length} зөвлөгөө',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              Text(
                'Үйлдлүүд',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.gap),
              LayoutBuilder(
                builder: (context, constraints) {
                  final buttonWidth = (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _JournalActionButton(
                        width: buttonWidth,
                        icon: Icons.fact_check,
                        label: 'Ирц авах',
                        onPressed: _openAttendance,
                      ),
                      _JournalActionButton(
                        width: buttonWidth,
                        icon: Icons.grade,
                        label: 'Дүн оруулах',
                        onPressed: _openBulkGrades,
                      ),
                      _JournalActionButton(
                        width: buttonWidth,
                        icon: Icons.assignment,
                        label: 'Даалгавар',
                        onPressed: _openHomework,
                      ),
                      _JournalActionButton(
                        width: buttonWidth,
                        icon: Icons.assignment_add,
                        label: 'Шинэ даалгавар',
                        onPressed: _openHomeworkCreate,
                      ),
                      _JournalActionButton(
                        width: buttonWidth,
                        icon: Icons.lightbulb_outline,
                        label: 'Зөвлөгөө',
                        onPressed: _openTeacherNotes,
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JournalActionButton extends StatelessWidget {
  const _JournalActionButton({
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
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
