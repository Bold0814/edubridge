import 'package:flutter/material.dart';

import '../models/attendance_record.dart';
import '../models/grade.dart';
import '../models/homework.dart';
import '../models/school_settings.dart';
import '../models/student.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'announcement_create_screen.dart';
import 'announcement_screen.dart';
import 'attendance_take_screen.dart';
import 'bulk_grade_entry_screen.dart';
import 'class_teacher_assignment_screen.dart';
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
  List<String> get _terms => SchoolSettings.semesterOptions;

  List<String> get _subjects => widget.store.subjects;

  /// Live search query for student names.
  final _searchController = TextEditingController();
  String _searchQuery = '';

  /// Attendance filter chip selection.
  _AttendanceFilter _attendanceFilter = _AttendanceFilter.all;

  /// Table sort mode.
  _JournalSort _sortMode = _JournalSort.nameAsc;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final next = _searchController.text;
      if (next == _searchQuery) return;
      setState(() => _searchQuery = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  /// Builds visible student rows: search → filter → sort.
  List<_JournalStudentRowData> _visibleRows({
    required List<Student> students,
    required List<AttendanceRecord> attendance,
    required List<Grade> grades,
    required String? selectedSubject,
    required String? selectedTerm,
    required String homeworkText,
  }) {
    final query = _searchQuery.trim().toLowerCase();

    final rows = <_JournalStudentRowData>[];
    for (final student in students) {
      final status = _todayStatusFor(student, attendance);
      final grade = _latestGradeFor(
        student,
        grades,
        selectedSubject,
        selectedTerm,
      );

      // Case-insensitive name search.
      if (query.isNotEmpty && !student.fullName.toLowerCase().contains(query)) {
        continue;
      }

      // Attendance filter chips.
      switch (_attendanceFilter) {
        case _AttendanceFilter.all:
          break;
        case _AttendanceFilter.present:
          if (status != AttendanceStatus.present) continue;
        case _AttendanceFilter.late:
          if (status != AttendanceStatus.late) continue;
        case _AttendanceFilter.absent:
          if (status != AttendanceStatus.absent) continue;
      }

      rows.add(
        _JournalStudentRowData(
          student: student,
          status: status,
          grade: grade,
          homeworkText: homeworkText,
        ),
      );
    }

    rows.sort((a, b) {
      switch (_sortMode) {
        case _JournalSort.nameAsc:
          return a.student.fullName.toLowerCase().compareTo(
            b.student.fullName.toLowerCase(),
          );
        case _JournalSort.grade:
          final aScore = a.gradeScore;
          final bScore = b.gradeScore;
          if (aScore == null && bScore == null) {
            return a.student.fullName.compareTo(b.student.fullName);
          }
          if (aScore == null) return 1;
          if (bScore == null) return -1;
          final byScore = bScore.compareTo(aScore); // high → low
          if (byScore != 0) return byScore;
          return a.student.fullName.compareTo(b.student.fullName);
        case _JournalSort.attendance:
          final byStatus = a.attendanceRank.compareTo(b.attendanceRank);
          if (byStatus != 0) return byStatus;
          return a.student.fullName.compareTo(b.student.fullName);
      }
    });

    return rows;
  }

  Future<void> _showSortMenu() async {
    final selected = await showMenu<_JournalSort>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 80, 16, 0),
      items: const [
        PopupMenuItem(value: _JournalSort.nameAsc, child: Text('Нэрээр (А-Я)')),
        PopupMenuItem(value: _JournalSort.grade, child: Text('Дүнгээр')),
        PopupMenuItem(value: _JournalSort.attendance, child: Text('Ирцээр')),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() => _sortMode = selected);
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

  Future<void> _openAnnouncementCreate() async {
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

  Future<void> _openAnnouncementList() async {
    widget.store.markAnnouncementsViewed(widget.selectedClass);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnnouncementScreen(
          selectedClass: widget.selectedClass,
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
          subjectId: widget.store.activeContext.subjectId,
          selectedSubject: _selectedSubject,
          selectedTerm: _selectedTerm,
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
      final entries = record.entries;
      if (entries == null) continue;
      for (final entry in entries) {
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

  String _homeworkText(List<Homework> homework, String? subject) {
    if (subject == null) return '—';

    for (final item in homework) {
      if (item.className == widget.selectedClass && item.subject == subject) {
        return item.title;
      }
    }
    return 'Байхгүй';
  }

  _ClassAttendanceStats _classAttendanceStats(List<AttendanceRecord> records) {
    var present = 0;
    var late = 0;
    var absent = 0;
    final today = DateTime.now();

    for (final record in records) {
      if (!record.isOnCalendarDay(today) || !record.hasStudentDetails) {
        continue;
      }
      final entries = record.entries;
      if (entries == null) continue;
      for (final entry in entries) {
        switch (entry.status) {
          case AttendanceStatus.present:
            present += 1;
          case AttendanceStatus.late:
            late += 1;
          case AttendanceStatus.absent:
            absent += 1;
        }
      }
      break;
    }

    return _ClassAttendanceStats(present: present, late: late, absent: absent);
  }

  _SubjectGradeStats? _subjectGradeStats(
    List<Grade> grades,
    String? subject,
    String? term,
  ) {
    if (subject == null) return null;

    final scores = <double>[];
    for (final grade in grades) {
      if (grade.className != widget.selectedClass) continue;
      if (grade.subject != subject) continue;
      if (term != null && grade.term != term) continue;
      final value = num.tryParse(grade.score.trim());
      if (value == null) continue;
      scores.add(value.toDouble());
    }

    if (scores.isEmpty) return null;

    final sum = scores.reduce((a, b) => a + b);
    final average = sum / scores.length;
    var highest = scores.first;
    var lowest = scores.first;
    for (final score in scores) {
      if (score > highest) highest = score;
      if (score < lowest) lowest = score;
    }

    return _SubjectGradeStats(
      average: average,
      highest: highest,
      lowest: lowest,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Хичээлийн журнал'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Эрэмбэлэх',
            onPressed: _showSortMenu,
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final selectedSubject = _selectedSubject;
          final selectedTerm = _selectedTerm;
          final students = widget.store.studentsFor(widget.selectedClass);
          final attendance = widget.store.attendanceFor(widget.selectedClass);
          final grades = widget.store.gradesFor(widget.selectedClass);
          final homework = widget.store.homeworkFor(widget.selectedClass);
          final announcements = widget.store.announcementsFor(
            widget.selectedClass,
          );
          final homeworkText = _homeworkText(homework, selectedSubject);
          final attendanceStats = _classAttendanceStats(attendance);
          final gradeStats = _subjectGradeStats(
            grades,
            selectedSubject,
            selectedTerm,
          );
          final hasUnread = widget.store.hasUnreadAnnouncements(
            widget.selectedClass,
          );
          final homeworkCount = selectedSubject == null
              ? homework.length
              : homework
                    .where((item) => item.subject == selectedSubject)
                    .length;
          final averageLabel = gradeStats == null
              ? '—'
              : gradeStats.average.round().toString();
          final visibleRows = students.isEmpty
              ? const <_JournalStudentRowData>[]
              : _visibleRows(
                  students: students,
                  attendance: attendance,
                  grades: grades,
                  selectedSubject: selectedSubject,
                  selectedTerm: selectedTerm,
                  homeworkText: homeworkText,
                );

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.card),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.selectedClass} анги',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (hasUnread)
                            InkWell(
                              onTap: _openAnnouncementList,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Шинэ',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.gap),
                      Text('Ирц ${attendanceStats.percentageLabel}'),
                      Text('Дундаж дүн $averageLabel'),
                      Text('Даалгавар $homeworkCount'),
                      Text('Зарлал ${announcements.length}'),
                      const SizedBox(height: AppSpacing.gap),
                      Wrap(
                        spacing: AppSpacing.item,
                        runSpacing: AppSpacing.item,
                        children: [
                          StatusBadge(
                            label: 'Ирсэн: ${attendanceStats.present}',
                            color: AppColors.present,
                          ),
                          StatusBadge(
                            label: 'Хоцорсон: ${attendanceStats.late}',
                            color: AppColors.late,
                          ),
                          StatusBadge(
                            label: 'Тасалсан: ${attendanceStats.absent}',
                            color: AppColors.absent,
                          ),
                        ],
                      ),
                      if (gradeStats != null) ...[
                        const SizedBox(height: AppSpacing.gap),
                        Text(
                          'Дундаж: ${gradeStats.average.toStringAsFixed(1)}  '
                          'Хамгийн өндөр: ${gradeStats.highest.round()}  '
                          'Хамгийн бага: ${gradeStats.lowest.round()}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sectionSm),
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
              const SizedBox(height: AppSpacing.itemSm),
              _JournalTeacherRow(
                store: widget.store,
                classId: widget.selectedClass,
                selectedSubject: selectedSubject,
              ),
              const SizedBox(height: AppSpacing.gap),
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
              const SizedBox(height: AppSpacing.sectionSm),
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
                        onPressed: _openAnnouncementCreate,
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
              const SizedBox(height: AppSpacing.sectionSm),
              if (students.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Сурагч бүртгэлгүй',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                )
              else ...[
                // Search field above the student table.
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Сурагч хайх...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Цэвэрлэх',
                            onPressed: () {
                              _searchController.clear();
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.gap),
                // Attendance filter chips.
                Wrap(
                  spacing: AppSpacing.item,
                  runSpacing: AppSpacing.item,
                  children: [
                    for (final filter in _AttendanceFilter.values)
                      FilterChip(
                        label: Text(filter.label),
                        selected: _attendanceFilter == filter,
                        onSelected: (_) {
                          setState(() => _attendanceFilter = filter);
                        },
                        selectedColor: filter.color.withValues(alpha: 0.18),
                        checkmarkColor: filter.color,
                        labelStyle: TextStyle(
                          color: _attendanceFilter == filter
                              ? filter.color
                              : AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color: _attendanceFilter == filter
                              ? filter.color
                              : AppColors.outlineSubtle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.gap),
                const _JournalHeader(),
                const SizedBox(height: AppSpacing.item),
                if (visibleRows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Мэдээлэл байхгүй',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  )
                else
                  ...visibleRows.map((row) {
                    return _JournalRow(
                      studentName: row.student.fullName,
                      attendanceLabel: row.status?.label ?? 'Бүртгээгүй',
                      attendanceColor:
                          row.status?.color ?? AppColors.onSurfaceVariant,
                      gradeText: row.grade?.scoreWithLetter ?? '—',
                      homeworkText: row.homeworkText,
                      onTap: () => _openStudentDetail(row.student),
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

/// Attendance filter chip options for the journal table.
enum _AttendanceFilter {
  all,
  present,
  late,
  absent;

  String get label {
    switch (this) {
      case _AttendanceFilter.all:
        return 'Бүгд';
      case _AttendanceFilter.present:
        return 'Ирсэн';
      case _AttendanceFilter.late:
        return 'Хоцорсон';
      case _AttendanceFilter.absent:
        return 'Тасалсан';
    }
  }

  Color get color {
    switch (this) {
      case _AttendanceFilter.all:
        return AppColors.primary;
      case _AttendanceFilter.present:
        return AppColors.present;
      case _AttendanceFilter.late:
        return AppColors.late;
      case _AttendanceFilter.absent:
        return AppColors.absent;
    }
  }
}

/// Sort modes for the journal student table.
enum _JournalSort { nameAsc, grade, attendance }

/// One prepared row used for search / filter / sort.
class _JournalStudentRowData {
  const _JournalStudentRowData({
    required this.student,
    required this.status,
    required this.grade,
    required this.homeworkText,
  });

  final Student student;
  final AttendanceStatus? status;
  final Grade? grade;
  final String homeworkText;

  double? get gradeScore {
    final raw = grade?.score;
    if (raw == null) return null;
    return num.tryParse(raw.trim())?.toDouble();
  }

  /// Lower rank appears first when sorting by attendance.
  int get attendanceRank {
    switch (status) {
      case AttendanceStatus.present:
        return 0;
      case AttendanceStatus.late:
        return 1;
      case AttendanceStatus.absent:
        return 2;
      case null:
        return 3;
    }
  }
}

class _ClassAttendanceStats {
  const _ClassAttendanceStats({
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
    return '${(present / total * 100).round()}%';
  }
}

class _SubjectGradeStats {
  const _SubjectGradeStats({
    required this.average,
    required this.highest,
    required this.lowest,
  });

  final double average;
  final double highest;
  final double lowest;
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
      height: AppSpacing.buttonHeight,
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
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.card,
            vertical: AppSpacing.gap,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  studentName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.itemSm),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(
                    label: attendanceLabel,
                    color: attendanceColor,
                    compact: true,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  gradeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.grade,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  homeworkText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
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

class _JournalTeacherRow extends StatelessWidget {
  const _JournalTeacherRow({
    required this.store,
    required this.classId,
    required this.selectedSubject,
  });

  final AppStore store;
  final String classId;
  final String? selectedSubject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String label;
    final bool missing;

    if (selectedSubject == null || selectedSubject!.isEmpty) {
      final home = store.homeroomTeacherForClass(classId);
      if (home != null) {
        label = 'Хичээлийн багш: ${home.fullName}';
        missing = false;
      } else {
        label = 'Багш оноогоогүй';
        missing = true;
      }
    } else {
      final assigned = store.teacherForClassSubjectName(
        classId,
        selectedSubject,
      );
      if (assigned != null) {
        label = 'Хичээлийн багш: ${assigned.fullName}';
        missing = false;
      } else {
        label = 'Багш оноогоогүй';
        missing = true;
      }
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: missing
                  ? AppColors.warning
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ClassTeacherAssignmentScreen(
                  store: store,
                  initialClassId: classId,
                ),
              ),
            );
          },
          child: const Text('Тохиргоо хийх'),
        ),
      ],
    );
  }
}
