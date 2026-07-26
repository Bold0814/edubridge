import 'package:flutter/material.dart';

import '../models/attendance_record.dart';
import '../models/grade.dart';
import '../models/homework.dart';
import '../models/lesson_occurrence.dart';
import '../services/journal_schedule_service.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'attendance_take_screen.dart';
import 'bulk_grade_entry_screen.dart';
import 'homework_screen.dart';
import 'journal_history_screen.dart';
import 'teacher_notes_screen.dart';

/// Schedule-driven lesson-occurrence journal (not a full class dashboard).
class ClassJournalScreen extends StatefulWidget {
  const ClassJournalScreen({
    super.key,
    required this.selectedClass,
    required this.store,
    this.subjectId,
    this.initialPeriodId,
    this.initialDate,
  });

  final String selectedClass;
  final AppStore store;
  final int? subjectId;
  final String? initialPeriodId;
  final DateTime? initialDate;

  @override
  State<ClassJournalScreen> createState() => _ClassJournalScreenState();
}

class _ClassJournalScreenState extends State<ClassJournalScreen> {
  ScheduledJournalLesson? _current;
  List<ScheduledJournalLesson> _timeline = const [];
  LessonOccurrence? _occurrence;
  String? _statusMessage;
  bool _loading = true;
  bool _noTimetable = false;

  int? get _subjectId =>
      widget.subjectId ?? widget.store.activeContext.subjectId;

  String? get _teacherId =>
      widget.store.activeContext.teacherId ??
      widget.store.authenticatedUser?.teacherId;

  /// Wall clock, or [ClassJournalScreen.initialDate] when opening a fixed day.
  DateTime get _referenceNow => widget.initialDate ?? DateTime.now();

  DateTime get _today => LessonOccurrence.dateOnly(_referenceNow);

  bool get _canEdit {
    final subjectId = _subjectId;
    if (subjectId == null) return false;
    return widget.store.teacherCanEditClassSubject(
      classId: widget.selectedClass,
      subjectId: subjectId,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final subjectId = _subjectId;
    if (subjectId == null) {
      setState(() {
        _loading = false;
        _statusMessage = 'Хичээл сонгогдоогүй байна.';
      });
      return;
    }

    final hasTemplate = widget.store
        .timetableForClass(widget.selectedClass)
        .any((e) => e.subjectId == subjectId);
    if (!hasTemplate &&
        widget.store
            .lessonOccurrencesFor(
              classId: widget.selectedClass,
              subjectId: subjectId,
              teacherId: _teacherId,
            )
            .isEmpty) {
      setState(() {
        _loading = false;
        _noTimetable = true;
        _statusMessage = 'Энэ анги, хичээлд хуваарь оруулаагүй байна.';
      });
      return;
    }

    final timeline = JournalScheduleService.dedupeLessons(
      JournalScheduleService.buildTimeline(
        widget.store,
        classId: widget.selectedClass,
        subjectId: subjectId,
        teacherId: _teacherId,
        around: widget.initialDate ?? DateTime.now(),
      ),
    );

    ScheduledJournalLesson? selected;
    if (widget.initialDate != null && widget.initialPeriodId != null) {
      final day = LessonOccurrence.dateOnly(widget.initialDate!);
      for (final item in timeline) {
        if (item.lessonDate == day && item.periodId == widget.initialPeriodId) {
          selected = item;
          break;
        }
      }
    }
    selected ??= JournalScheduleService.resolveDefault(
      widget.store,
      classId: widget.selectedClass,
      subjectId: subjectId,
      teacherId: _teacherId,
      preferredPeriodId: widget.initialPeriodId,
      now: _referenceNow,
    );

    final today = _today;
    final hasLessonToday = timeline.any((item) => item.lessonDate == today);
    final message = hasLessonToday
        ? null
        : 'Өнөөдөр энэ хичээл хуваарьгүй байна.';

    setState(() {
      _timeline = timeline;
      _current = selected;
      _statusMessage = message;
      _loading = false;
    });

    if (selected != null) {
      await _ensureCurrent(selected);
    }
  }

  Future<void> _ensureCurrent(ScheduledJournalLesson lesson) async {
    final occurrence = await widget.store.ensureLessonOccurrence(
      classId: lesson.classId,
      subjectId: lesson.subjectId,
      lessonDate: lesson.lessonDate,
      periodId: lesson.periodId,
      teacherId: lesson.teacherId.isEmpty ? _teacherId : lesson.teacherId,
      timetableEntryId: lesson.timetableEntryId,
    );
    if (!mounted) return;
    setState(() => _occurrence = occurrence);
  }

  Future<void> _selectLesson(ScheduledJournalLesson lesson) async {
    final today = _today;
    final hasLessonToday = _timeline.any((item) => item.lessonDate == today);
    setState(() {
      _current = lesson;
      _statusMessage = hasLessonToday
          ? null
          : 'Өнөөдөр энэ хичээл хуваарьгүй байна.';
    });
    await _ensureCurrent(lesson);
  }

  Future<void> _goRelative(int delta) async {
    final current = _current;
    if (current == null || _timeline.isEmpty) return;
    final index = _timeline.indexWhere(
      (item) => item.identityKey == current.identityKey,
    );
    final nextIndex = index < 0 ? -1 : index + delta;
    if (nextIndex < 0 || nextIndex >= _timeline.length) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delta < 0
                ? 'Өмнөх хичээл олдсонгүй.'
                : 'Дараагийн хичээл олдсонгүй.',
          ),
        ),
      );
      return;
    }
    await _selectLesson(_timeline[nextIndex]);
  }

  Future<void> _openHistory() async {
    final subjectId = _subjectId;
    if (subjectId == null) return;
    final picked = await Navigator.push<ScheduledJournalLesson>(
      context,
      MaterialPageRoute(
        builder: (context) => JournalHistoryScreen(
          store: widget.store,
          classId: widget.selectedClass,
          subjectId: subjectId,
          teacherId: _teacherId,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _selectLesson(picked);
  }

  Future<void> _openAttendance() async {
    if (!_canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStore.subjectEditDeniedMessage)),
      );
      return;
    }
    final lesson = _current;
    if (lesson == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceTakeScreen(
          selectedClass: widget.selectedClass,
          store: widget.store,
          lessonDate: lesson.lessonDate,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openGrades() async {
    if (!_canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStore.subjectEditDeniedMessage)),
      );
      return;
    }
    final subjectId = _subjectId;
    final subject = subjectId == null
        ? null
        : widget.store.subjectById(subjectId);
    if (subject == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkGradeEntryScreen(
          selectedClass: widget.selectedClass,
          store: widget.store,
          initialSubject: subject.name,
          initialTerm: widget.store.journalTermFor(widget.selectedClass),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openHomework() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeworkScreen(
          selectedClass: widget.selectedClass,
          store: widget.store,
          subjectId: _subjectId,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openNotes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherNotesScreen(
          selectedClass: widget.selectedClass,
          store: widget.store,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  List<AttendanceRecord> _attendanceForLesson(ScheduledJournalLesson lesson) {
    return widget.store
        .attendanceFor(widget.selectedClass)
        .where((r) => r.isOnCalendarDay(lesson.lessonDate))
        .toList(growable: false);
  }

  List<Grade> _gradesForSubject() {
    final subject = _subjectId == null
        ? null
        : widget.store.subjectById(_subjectId!);
    if (subject == null) return const [];
    return widget.store
        .gradesFor(widget.selectedClass)
        .where((g) => g.subject == subject.name)
        .toList(growable: false);
  }

  List<Homework> _homeworkForSubject() {
    return widget.store.homeworkFor(
      widget.selectedClass,
      subjectId: _subjectId,
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
            tooltip: 'Журналын түүх',
            icon: const Icon(Icons.history),
            onPressed: _loading || _noTimetable ? null : _openHistory,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_noTimetable || _current == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Text(
                  _statusMessage ??
                      'Энэ анги, хичээлд хуваарь оруулаагүй байна.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            );
          }

          final lesson = _current!;
          final subject = widget.store.subjectById(lesson.subjectId);
          final classLabel = '${lesson.classId} анги';
          final subjectName = subject?.name ?? 'Хичээл';
          final attendance = _attendanceForLesson(lesson);
          final grades = _gradesForSubject();
          final homework = _homeworkForSubject();
          final notes = widget.store.teacherNotesForClass(widget.selectedClass);
          final notePreview = _occurrence?.note?.trim();
          final gradedStudentIds = grades.map((g) => g.studentId).toSet();

          var present = 0;
          var late = 0;
          var absent = 0;
          for (final record in attendance) {
            present += record.presentCount;
            late += record.lateCount;
            absent += record.absentCount;
          }

          final dayLessons = JournalScheduleService.dedupeLessons(
            _timeline.where(
              (item) =>
                  LessonOccurrence.dateOnly(item.lessonDate) ==
                  LessonOccurrence.dateOnly(lesson.lessonDate),
            ),
          );
          final periodItems = <DropdownMenuItem<String>>[
            for (final item in dayLessons)
              DropdownMenuItem(
                value: item.occurrenceKey,
                child: Text('${item.periodNumber}-р цаг · ${item.timeLabel}'),
              ),
          ];
          final validKeys = periodItems.map((item) => item.value).toSet();
          final safeSelectedKey = validKeys.contains(lesson.occurrenceKey)
              ? lesson.occurrenceKey
              : null;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$classLabel · $subjectName',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          JournalScheduleService.mongolianDateLabel(
                            lesson.lessonDate,
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          '${lesson.periodNumber}-р цаг · ${lesson.timeLabel}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Журналын түүх',
                    icon: const Icon(Icons.calendar_month_outlined),
                    onPressed: _openHistory,
                  ),
                ],
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: AppSpacing.itemSm),
                Text(
                  _statusMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
              if (dayLessons.isEmpty) ...[
                const SizedBox(height: AppSpacing.gap),
                Text(
                  'Энэ өдөр тохирох хичээл олдсонгүй.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ] else if (dayLessons.length > 1 && periodItems.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.gap),
                DropdownButtonFormField<String>(
                  key: ValueKey('period-select-$safeSelectedKey'),
                  initialValue: safeSelectedKey,
                  decoration: const InputDecoration(
                    labelText: 'Цаг',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: periodItems,
                  onChanged: (key) async {
                    if (key == null) return;
                    ScheduledJournalLesson? match;
                    for (final item in dayLessons) {
                      if (item.occurrenceKey == key) {
                        match = item;
                        break;
                      }
                    }
                    if (match != null) await _selectLesson(match);
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.sectionSm),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _JournalActionButton(
                        width: width,
                        icon: Icons.fact_check,
                        label: 'Ирц авах',
                        onPressed: _canEdit ? _openAttendance : null,
                      ),
                      _JournalActionButton(
                        width: width,
                        icon: Icons.grade,
                        label: 'Дүн оруулах',
                        onPressed: _canEdit ? _openGrades : null,
                      ),
                      _JournalActionButton(
                        width: width,
                        icon: Icons.assignment,
                        label: 'Даалгавар',
                        onPressed: _openHomework,
                      ),
                      _JournalActionButton(
                        width: width,
                        icon: Icons.sticky_note_2_outlined,
                        label: 'Тэмдэглэл',
                        onPressed: _openNotes,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              Text(
                'Өнөөдрийн бүртгэл',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.item),
              _SummaryCard(
                title: 'Ирц',
                body: attendance.isEmpty
                    ? 'Ирц бүртгээгүй'
                    : 'Ирсэн: $present · Тасалсан: $absent · Хоцорсон: $late',
                onTap: _canEdit ? _openAttendance : null,
              ),
              _SummaryCard(
                title: 'Дүн / үнэлгээ',
                body: gradedStudentIds.isEmpty
                    ? 'Дүн бүртгээгүй'
                    : '${gradedStudentIds.length} сурагчид дүн авсан',
                onTap: _canEdit ? _openGrades : null,
              ),
              _SummaryCard(
                title: 'Даалгавар',
                body: homework.isEmpty
                    ? 'Даалгавар байхгүй'
                    : '${homework.length} · ${homework.first.title}',
                onTap: _openHomework,
              ),
              _SummaryCard(
                title: 'Багшийн тэмдэглэл',
                body: (notePreview == null || notePreview.isEmpty)
                    ? (notes.isEmpty
                          ? 'Тэмдэглэл байхгүй'
                          : notes.first.message)
                    : notePreview,
                onTap: _openNotes,
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _goRelative(-1),
                      child: const Text('Өмнөх хичээл'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _goRelative(1),
                      child: const Text('Дараагийн хичээл'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.body, this.onTap});

  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(body),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
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
  final VoidCallback? onPressed;

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
