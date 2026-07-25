import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../models/attendance_record.dart';
import '../models/grade.dart';
import '../models/homework.dart';
import '../models/student.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'homework_screen.dart';
import 'student_grade_detail_screen.dart';
import 'student_login_provision_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({
    super.key,
    required this.studentId,
    required this.selectedClass,
    required this.store,
    this.selectedSubject,
    this.subjectId,
    this.selectedTerm,
  });

  final String studentId;
  final String selectedClass;
  final AppStore store;
  final String? selectedSubject;
  final int? subjectId;
  final String? selectedTerm;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final _scrollController = ScrollController();
  final _attendanceKey = GlobalKey();
  final _gradesKey = GlobalKey();
  final _homeworkKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final targetContext = key.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.05,
    );
  }

  int? get _effectiveSubjectId =>
      widget.subjectId ?? widget.store.activeContext.subjectId;

  String? get _effectiveSubjectName {
    final id = _effectiveSubjectId;
    if (id != null) {
      return widget.store.subjectById(id)?.name;
    }
    final named = widget.selectedSubject?.trim();
    if (named == null || named.isEmpty) return null;
    return named;
  }

  String? get _effectiveTerm {
    final selected = widget.selectedTerm?.trim();
    if (selected != null && selected.isNotEmpty) return selected;
    final journal = widget.store.journalTermFor(widget.selectedClass)?.trim();
    if (journal == null || journal.isEmpty) return null;
    return journal;
  }

  List<Grade> _gradesForSummary(Student student) {
    return widget.store.gradesForStudentContext(
      className: widget.selectedClass,
      studentId: student.id,
      subjectId: _effectiveSubjectId,
      subjectName: _effectiveSubjectId == null ? _effectiveSubjectName : null,
      term: _effectiveTerm,
    );
  }

  bool _requireContext({required bool needStudent, required bool needClass}) {
    final missing = <String>[];
    if (widget.store.activeSchoolId == null) missing.add('schoolId');
    if (needClass && widget.selectedClass.trim().isEmpty) {
      missing.add('classId');
    }
    if (needStudent && widget.studentId.trim().isEmpty) {
      missing.add('studentId');
    }
    if (missing.isEmpty) return true;
    if (kDebugMode) {
      debugPrint('StudentDetail missing context: ${missing.join(', ')}');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Мэдээлэл ачаалахад шаардлагатай сонголт дутуу байна.'),
      ),
    );
    return false;
  }

  Future<void> _onAttendanceAction() => _scrollTo(_attendanceKey);

  Future<void> _onGradesAction() async {
    if (!_requireContext(needStudent: true, needClass: true)) return;

    Student? student;
    for (final item in widget.store.studentsFor(widget.selectedClass)) {
      if (item.id == widget.studentId) {
        student = item;
        break;
      }
    }
    if (student == null) {
      if (kDebugMode) debugPrint('StudentDetail grades: student not found');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Мэдээлэл ачаалахад шаардлагатай сонголт дутуу байна.'),
        ),
      );
      return;
    }

    final target = student;
    if (kDebugMode) {
      final preview = _gradesForSummary(target);
      debugPrint(
        'StudentDetail → grades '
        'schoolId=${widget.store.activeSchoolId} '
        'classId=${widget.selectedClass} '
        'studentId=${target.id} '
        'subjectId=$_effectiveSubjectId '
        'subjectName=$_effectiveSubjectName '
        'term=$_effectiveTerm '
        'matchCount=${preview.length}',
      );
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentGradeDetailScreen(
          store: widget.store,
          student: target,
          schoolId: widget.store.activeSchoolId,
          classId: widget.selectedClass,
          subjectId: _effectiveSubjectId,
          subjectName: _effectiveSubjectName,
          term: _effectiveTerm,
        ),
      ),
    );
    if (!context.mounted) return;
  }

  Future<void> _onHomeworkAction() async {
    if (!_requireContext(needStudent: true, needClass: true)) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => HomeworkScreen(
          selectedClass: widget.selectedClass,
          store: widget.store,
          subjectId: _effectiveSubjectId,
        ),
      ),
    );
    if (!context.mounted) return;
  }

  _AttendanceSummary _attendanceSummary(
    Student student,
    List<AttendanceRecord> records,
  ) {
    var present = 0;
    var late = 0;
    var absent = 0;
    final history = <_AttendanceHistoryItem>[];

    for (final record in records) {
      if (!record.hasStudentDetails) continue;
      final entries = record.entries;
      if (entries == null) continue;

      for (final entry in entries) {
        if (entry.studentName != student.fullName) continue;
        switch (entry.status) {
          case AttendanceStatus.present:
            present += 1;
          case AttendanceStatus.late:
            late += 1;
          case AttendanceStatus.absent:
            absent += 1;
        }
        history.add(
          _AttendanceHistoryItem(date: record.date, status: entry.status),
        );
      }
    }

    return _AttendanceSummary(
      present: present,
      late: late,
      absent: absent,
      history: history,
    );
  }

  List<Grade> _latestGradesBySubject(Student student, List<Grade> grades) {
    final latestBySubject = <String, Grade>{};
    for (final grade in grades) {
      latestBySubject.putIfAbsent(grade.subject, () => grade);
    }
    final result = latestBySubject.values.toList()
      ..sort((a, b) => a.subject.compareTo(b.subject));
    return result;
  }

  String _averageGradeLabel(List<Grade> grades) {
    final average = widget.store.averageScore(grades);
    if (average == null) return '—';
    return average.round().toString();
  }

  List<Homework> _displayHomework(List<Homework> classHomework) {
    final subject = _effectiveSubjectName?.trim();
    final Iterable<Homework> preferred;
    if (subject != null && subject.isNotEmpty) {
      preferred = classHomework.where((item) => item.subject.trim() == subject);
    } else {
      preferred = classHomework;
    }
    return preferred.take(3).toList(growable: false);
  }

  List<Announcement> _displayAnnouncements(
    List<Announcement> classAnnouncements,
  ) {
    return classAnnouncements.take(3).toList(growable: false);
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
        listenable: widget.store,
        builder: (context, _) {
          final students = widget.store.studentsFor(widget.selectedClass);
          Student? student;
          for (final item in students) {
            if (item.id == widget.studentId) {
              student = item;
              break;
            }
          }

          if (student == null) {
            return const Center(child: Text('Сурагч олдсонгүй.'));
          }

          final currentStudent = student;
          final attendance = widget.store.attendanceFor(widget.selectedClass);
          final grades = _gradesForSummary(currentStudent);
          final homework = widget.store.homeworkFor(
            widget.selectedClass,
            subjectId: _effectiveSubjectId,
            subjectName: _effectiveSubjectId == null
                ? _effectiveSubjectName
                : null,
          );
          final announcements = widget.store.announcementsFor(
            widget.selectedClass,
          );
          final summary = _attendanceSummary(currentStudent, attendance);
          final latestGrades = _latestGradesBySubject(currentStudent, grades);
          final visibleHomework = _displayHomework(homework);
          final visibleAnnouncements = _displayAnnouncements(announcements);
          final averageGrade = _averageGradeLabel(grades);
          final guardian = currentStudent.guardian?.trim();
          final phone = currentStudent.phone?.trim();
          final subject = _effectiveSubjectName;
          final term = _effectiveTerm;

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text(
                currentStudent.fullName,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.itemSm),
              Text(
                '${widget.selectedClass} анги',
                style: theme.textTheme.bodySmall,
              ),
              if (guardian != null && guardian.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.item),
                Text('Асран хамгаалагч: $guardian'),
              ],
              if (phone != null && phone.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.itemSm),
                Text('Утас: $phone'),
              ],
              if (widget.store.canViewStudentCode(currentStudent.id) &&
                  (currentStudent.studentCode?.isNotEmpty ?? false)) ...[
                const SizedBox(height: AppSpacing.gap),
                Text(
                  'Сурагчийн код: ${currentStudent.studentCode}',
                  style: theme.textTheme.titleSmall,
                ),
              ],
              if (widget.store.canManageStudents &&
                  widget.store.accountForStudentId(currentStudent.id) ==
                      null) ...[
                const SizedBox(height: AppSpacing.gap),
                OutlinedButton(
                  onPressed: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentLoginProvisionScreen(
                          store: widget.store,
                          studentId: currentStudent.id,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Нэвтрэх эрх үүсгэх'),
                ),
              ],
              if ((subject != null && subject.isNotEmpty) ||
                  (term != null && term.isNotEmpty)) ...[
                const SizedBox(height: AppSpacing.gap),
                Wrap(
                  spacing: AppSpacing.item,
                  runSpacing: AppSpacing.item,
                  children: [
                    if (subject != null && subject.isNotEmpty)
                      Chip(label: Text(subject)),
                    if (term != null && term.isNotEmpty)
                      Chip(label: Text(term)),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.gap),
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
                              'Ирцийн хувь',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            summary.percentageLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.present,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.item),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                        child: LinearProgressIndicator(
                          value: summary.progress,
                          minHeight: AppSpacing.progressHeight,
                          backgroundColor: AppColors.outlineSubtle,
                          color: AppColors.present,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.gap),
                      Text(
                        'Дундаж дүн: $averageGrade',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.grade,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.itemSm),
                      Text('Даалгаврын тоо: ${homework.length}'),
                      Text('Зарлалын тоо: ${announcements.length}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - AppSpacing.item) / 2;
                  return Wrap(
                    spacing: AppSpacing.item,
                    runSpacing: AppSpacing.item,
                    children: [
                      _QuickActionButton(
                        width: width,
                        icon: Icons.fact_check,
                        label: 'Ирц харах',
                        onPressed: _onAttendanceAction,
                      ),
                      _QuickActionButton(
                        width: width,
                        icon: Icons.grade,
                        label: 'Дүн харах',
                        onPressed: _onGradesAction,
                      ),
                      _QuickActionButton(
                        width: width,
                        icon: Icons.assignment,
                        label: 'Даалгавар харах',
                        onPressed: _onHomeworkAction,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.section),
              KeyedSubtree(
                key: _attendanceKey,
                child: const _SectionTitle(title: 'Ирц'),
              ),
              const SizedBox(height: AppSpacing.item),
              if (summary.total == 0)
                const Text('Мэдээлэл байхгүй')
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.card),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Нийт бүртгэл: ${summary.total}'),
                        const SizedBox(height: AppSpacing.item),
                        Wrap(
                          spacing: AppSpacing.item,
                          runSpacing: AppSpacing.item,
                          children: [
                            StatusBadge(
                              label: 'Ирсэн: ${summary.present}',
                              color: AppColors.present,
                            ),
                            StatusBadge(
                              label: 'Хоцорсон: ${summary.late}',
                              color: AppColors.late,
                            ),
                            StatusBadge(
                              label: 'Тасалсан: ${summary.absent}',
                              color: AppColors.absent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.gap),
                Text('Сүүлийн ирц', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.item),
                ...summary.history.take(10).map((item) {
                  return Card(
                    child: ListTile(
                      dense: true,
                      title: Text(item.date),
                      trailing: StatusBadge(
                        label: item.status.label,
                        color: item.status.color,
                        compact: true,
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: AppSpacing.section),
              KeyedSubtree(
                key: _gradesKey,
                child: const _SectionTitle(title: 'Дүн'),
              ),
              const SizedBox(height: AppSpacing.item),
              if (latestGrades.isEmpty)
                const Text('Дүн бүртгэгдээгүй')
              else
                ...latestGrades.map((grade) {
                  return Card(
                    child: ListTile(
                      title: Text(grade.subject),
                      subtitle: Text(grade.term),
                      trailing: Text(
                        grade.scoreWithLetter,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.grade,
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.section),
              KeyedSubtree(
                key: _homeworkKey,
                child: const _SectionTitle(title: 'Даалгавар'),
              ),
              const SizedBox(height: AppSpacing.item),
              if (visibleHomework.isEmpty)
                const Text('Даалгавар байхгүй')
              else
                ...visibleHomework.map((item) => _HomeworkTile(homework: item)),
              const SizedBox(height: AppSpacing.section),
              const _SectionTitle(title: 'Зарлал'),
              const SizedBox(height: AppSpacing.item),
              if (visibleAnnouncements.isEmpty)
                const Text('Зарлал байхгүй')
              else
                ...visibleAnnouncements.map(
                  (item) => _AnnouncementTile(announcement: item),
                ),
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
    required this.history,
  });

  final int present;
  final int late;
  final int absent;
  final List<_AttendanceHistoryItem> history;

  int get total => present + late + absent;

  double get progress => total == 0 ? 0 : present / total;

  String get percentageLabel {
    if (total == 0) return '0%';
    final percent = (present / total * 100).round();
    return '$percent%';
  }
}

class _AttendanceHistoryItem {
  const _AttendanceHistoryItem({required this.date, required this.status});

  final String date;
  final AttendanceStatus status;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
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

class _HomeworkTile extends StatelessWidget {
  const _HomeworkTile({required this.homework});

  final Homework homework;

  @override
  Widget build(BuildContext context) {
    final isDone = homework.status == HomeworkStatus.done;
    final color = isDone ? AppColors.success : AppColors.homework;

    return Card(
      child: ListTile(
        dense: true,
        leading: Icon(
          isDone ? Icons.assignment_turned_in : Icons.assignment,
          color: color,
        ),
        title: Text(homework.title),
        subtitle: Text('${homework.subject} • ${homework.dueDate}'),
        trailing: StatusBadge(
          label: homework.status.label,
          color: color,
          compact: true,
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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              announcement.isFeatured ? Icons.star : Icons.campaign,
              color: announcement.isFeatured
                  ? AppColors.warning
                  : AppColors.announcement,
            ),
            const SizedBox(width: AppSpacing.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          announcement.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (announcement.isFeatured)
                        StatusBadge(
                          label: 'Онцлох',
                          color: AppColors.warning,
                          compact: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.itemSm),
                  Text(announcement.date),
                  const SizedBox(height: AppSpacing.itemSm),
                  Text(
                    announcement.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
