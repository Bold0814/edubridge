import 'package:flutter/material.dart';

import '../models/timetable.dart';
import '../services/timetable_service.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum TimetableViewerMode { teacher, student, guardian }

enum _TimetableTab { today, week, term }

/// Read-only timetable for teacher / student / guardian portals.
class TimetableViewerScreen extends StatefulWidget {
  const TimetableViewerScreen({
    super.key,
    required this.store,
    required this.title,
    required this.mode,
  });

  final AppStore store;
  final String title;
  final TimetableViewerMode mode;

  @override
  State<TimetableViewerScreen> createState() => _TimetableViewerScreenState();
}

class _TimetableViewerScreenState extends State<TimetableViewerScreen> {
  _TimetableTab _tab = _TimetableTab.today;

  String? _resolveTeacherId() {
    final fromContext = widget.store.activeContext.teacherId;
    if (fromContext != null && fromContext.isNotEmpty) return fromContext;
    final fromUser = widget.store.selectedDevelopmentUser?.teacherId;
    if (fromUser != null && fromUser.isNotEmpty) return fromUser;
    return null;
  }

  String? _resolveClassId() {
    switch (widget.mode) {
      case TimetableViewerMode.teacher:
        return null;
      case TimetableViewerMode.student:
        final studentId =
            widget.store.activeContext.studentId ??
            widget.store.authenticatedUser?.studentId;
        if (studentId == null) return null;
        return widget.store.studentById(studentId)?.className;
      case TimetableViewerMode.guardian:
        return widget.store.selectedGuardianStudent?.className;
    }
  }

  Map<int, List<ResolvedLesson>> _weekMap() {
    if (widget.mode == TimetableViewerMode.teacher) {
      final teacherId = _resolveTeacherId();
      if (teacherId == null) return const {};
      return TimetableService.weekLessonsForTeacher(widget.store, teacherId);
    }
    final classId = _resolveClassId();
    if (classId == null || classId.isEmpty) return const {};
    return TimetableService.weekLessonsForClass(widget.store, classId);
  }

  List<ResolvedLesson> _todayLessons() {
    if (widget.mode == TimetableViewerMode.teacher) {
      final teacherId = _resolveTeacherId();
      if (teacherId == null) return const [];
      return TimetableService.todayLessonsForTeacher(widget.store, teacherId);
    }
    final classId = _resolveClassId();
    if (classId == null || classId.isEmpty) return const [];
    return TimetableService.todayLessonsForClass(widget.store, classId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final semester = widget.store.schoolSettings.currentSemester;

        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              SegmentedButton<_TimetableTab>(
                segments: const [
                  ButtonSegment(
                    value: _TimetableTab.today,
                    label: Text('Өнөөдөр'),
                  ),
                  ButtonSegment(
                    value: _TimetableTab.week,
                    label: Text('7 хоног'),
                  ),
                  ButtonSegment(
                    value: _TimetableTab.term,
                    label: Text('Улирал'),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (next) {
                  setState(() => _tab = next.first);
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: AppSpacing.sectionSm),
              if (_tab == _TimetableTab.today)
                _TodayBody(
                  lessons: _todayLessons(),
                  showClass: widget.mode == TimetableViewerMode.teacher,
                  showTeacher: widget.mode != TimetableViewerMode.teacher,
                )
              else ...[
                if (_tab == _TimetableTab.term) ...[
                  Text(
                    'Улирлын хуваарь (долоо хоног бүрийн давталт)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.itemSm),
                  Text(
                    'Идэвхтэй улирал: $semester. Энэ хуваарь улирлын туршид '
                    'долоо хоног бүр давтагдана.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sectionSm),
                ],
                _WeekBody(
                  week: _weekMap(),
                  showClass: widget.mode == TimetableViewerMode.teacher,
                  showTeacher: widget.mode != TimetableViewerMode.teacher,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TodayBody extends StatelessWidget {
  const _TodayBody({
    required this.lessons,
    required this.showClass,
    required this.showTeacher,
  });

  final List<ResolvedLesson> lessons;
  final bool showClass;
  final bool showTeacher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekday = DateTime.now().weekday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Өнөөдөр · ${TimetableWeekday.label(weekday)}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.gap),
        if (lessons.isEmpty)
          Text(
            'Өнөөдөр хичээл байхгүй',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...lessons.map(
            (lesson) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.item),
              child: _LessonTile(
                lesson: lesson,
                showClass: showClass,
                showTeacher: showTeacher,
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekBody extends StatelessWidget {
  const _WeekBody({
    required this.week,
    required this.showClass,
    required this.showTeacher,
  });

  final Map<int, List<ResolvedLesson>> week;
  final bool showClass;
  final bool showTeacher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAny = week.values.any((list) => list.isNotEmpty);

    if (!hasAny) {
      return Text(
        'Хуваарь бүртгэгдээгүй',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (
          var weekday = DateTime.monday;
          weekday <= DateTime.sunday;
          weekday++
        ) ...[
          if (week[weekday]?.isNotEmpty ?? false) ...[
            Text(
              TimetableWeekday.label(weekday),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.item),
            for (final lesson in week[weekday]!)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.item),
                child: _LessonTile(
                  lesson: lesson,
                  showClass: showClass,
                  showTeacher: showTeacher,
                ),
              ),
            const SizedBox(height: AppSpacing.gap),
          ],
        ],
      ],
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.showClass,
    required this.showTeacher,
  });

  final ResolvedLesson lesson;
  final bool showClass;
  final bool showTeacher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      if (showClass) lesson.classId,
      if (showTeacher && lesson.teacher != null) lesson.teacher!.fullName,
    ];

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.card,
          vertical: AppSpacing.itemSm,
        ),
        title: Text(
          '${lesson.period.periodNumber}. ${lesson.subjectName}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson.timeLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitleParts.isNotEmpty)
              Text(
                subtitleParts.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
