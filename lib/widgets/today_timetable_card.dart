import 'package:flutter/material.dart';

import '../services/timetable_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Read-only list of today's lessons (Student / Guardian).
class TodayTimetableCard extends StatelessWidget {
  const TodayTimetableCard({
    super.key,
    required this.lessons,
    this.title = 'Өнөөдрийн хуваарь',
  });

  final List<ResolvedLesson> lessons;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_view_day, color: AppColors.primary),
                const SizedBox(width: AppSpacing.item),
                Text(title, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: AppSpacing.item),
            if (lessons.isEmpty)
              Text(
                ResolvedLesson.emptyClassTodayMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...lessons.map((lesson) {
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.item),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.scheduleHeading,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        lesson.subjectName,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Teacher dashboard lesson row with action buttons.
class TeacherTodayLessonCard extends StatelessWidget {
  const TeacherTodayLessonCard({
    super.key,
    required this.lesson,
    required this.onAttendance,
    required this.onJournal,
    required this.onHomework,
    required this.onGrade,
  });

  final ResolvedLesson lesson;
  final VoidCallback onAttendance;
  final VoidCallback onJournal;
  final VoidCallback onHomework;
  final VoidCallback onGrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teacherName = lesson.teacher?.fullName.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson.scheduleHeading,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${lesson.classId} · ${lesson.subjectName}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (teacherName != null && teacherName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Багш: $teacherName',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.item),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionChip(
                  label: 'Ирц',
                  icon: Icons.fact_check_outlined,
                  onTap: onAttendance,
                ),
                _ActionChip(
                  label: 'Журнал',
                  icon: Icons.menu_book_outlined,
                  onTap: onJournal,
                ),
                _ActionChip(
                  label: 'Даалгавар',
                  icon: Icons.assignment_outlined,
                  onTap: onHomework,
                ),
                _ActionChip(
                  label: 'Дүн',
                  icon: Icons.grade_outlined,
                  onTap: onGrade,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
