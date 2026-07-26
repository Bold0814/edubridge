import 'package:flutter/material.dart';

import '../models/teacher_assigned_class.dart';
import '../models/teacher_dashboard_snapshot.dart';
import '../services/timetable_service.dart';
import '../state/app_store.dart';
import '../theme/app_colors.dart';
import '../widgets/today_timetable_card.dart';
import 'announcement_screen.dart';
import 'attendance_screen.dart';
import 'attendance_take_screen.dart';
import 'class_journal_screen.dart';
import 'grade_create_screen.dart';
import 'grade_screen.dart';
import 'homework_create_screen.dart';
import 'homework_screen.dart';
import 'student_list_screen.dart';
import 'teacher_notes_screen.dart';
import 'timetable_viewer_screen.dart';

/// Minimal teacher dashboard (Apple Education / Notion / Classroom inspired).
class ClassDashboardScreen extends StatelessWidget {
  const ClassDashboardScreen({
    super.key,
    required this.selectedClass,
    required this.store,
    required this.onClassChanged,
  });

  final String selectedClass;
  final AppStore store;
  final Future<void> Function(String classId) onClassChanged;

  static const _page = 16.0;
  static const _cardGap = 10.0;
  static const _sectionGap = 14.0;
  static const _radius = 14.0;
  static const _actionBreakpoint = 360.0;

  Future<void> _openStudents(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            StudentListScreen(selectedClass: selectedClass, store: store),
      ),
    );
    if (!context.mounted) return;
  }

  Future<void> _openAttendanceList(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AttendanceScreen(selectedClass: selectedClass, store: store),
      ),
    );
    if (!context.mounted) return;
  }

  Future<void> _openGradeList(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            GradeScreen(selectedClass: selectedClass, store: store),
      ),
    );
    if (!context.mounted) return;
  }

  Future<void> _openAnnouncementList(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AnnouncementScreen(selectedClass: selectedClass, store: store),
      ),
    );
    if (!context.mounted) return;
  }

  Future<void> _openJournal(
    BuildContext context, {
    String? className,
    String? subjectName,
  }) async {
    final targetClass = className ?? selectedClass;
    if (subjectName != null) {
      store.setJournalSubject(targetClass, subjectName);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ClassJournalScreen(selectedClass: targetClass, store: store),
      ),
    );
    if (!context.mounted) return;
  }

  Future<void> _openAttendanceTake(
    BuildContext context, {
    String? className,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceTakeScreen(
          selectedClass: className ?? selectedClass,
          store: store,
        ),
      ),
    );
    if (!context.mounted) return;
  }

  Future<void> _openGradeCreate(
    BuildContext context, {
    String? className,
    String? subjectName,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GradeCreateScreen(
          className: className ?? selectedClass,
          store: store,
          initialSubject: subjectName,
        ),
      ),
    );
    if (!context.mounted) return;
  }

  Future<void> _openHomework(
    BuildContext context, {
    String? className,
    String? subjectName,
    int? subjectId,
  }) async {
    final targetClass = className ?? selectedClass;
    var resolvedSubjectId = subjectId ?? store.activeContext.subjectId;
    if (resolvedSubjectId == null && subjectName != null) {
      resolvedSubjectId = store.subjectByName(subjectName)?.id;
    }
    if (subjectName != null) {
      store.setJournalSubject(targetClass, subjectName);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeworkScreen(
          selectedClass: targetClass,
          store: store,
          subjectId: resolvedSubjectId,
        ),
      ),
    );
    if (!context.mounted) return;
  }

  Future<void> _openHomeworkCreate(
    BuildContext context, {
    String? className,
    String? subjectName,
  }) async {
    final targetClass = className ?? selectedClass;
    final activeId = store.activeContext.subjectId;
    final initialSubject =
        subjectName ??
        (activeId != null ? store.subjectById(activeId)?.name : null);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeworkCreateScreen(
          className: targetClass,
          store: store,
          initialSubject: initialSubject,
          lockSubject:
              initialSubject != null &&
              (activeId != null || subjectName != null),
        ),
      ),
    );
    if (!context.mounted) return;
  }

  Future<void> _openTeacherNotes(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TeacherNotesScreen(selectedClass: selectedClass, store: store),
      ),
    );
    if (!context.mounted) return;
  }

  /// Header chip uses ActiveAppContext.subjectId only (not journal fallback),
  /// so it stays aligned with homework/grade subject filters.
  String? _activeSubjectLabel() {
    final subjectId = store.activeContext.subjectId;
    if (subjectId == null) return null;
    return store.subjectById(subjectId)?.name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final dash = TeacherDashboardSnapshot.fromStore(store, selectedClass);
        final assignedClasses = store.assignedClassesForActiveTeacher();
        final todayLessons = TimetableService.todayLessonsForTeacherDashboard(
          store,
          selectedClass,
        );
        final subjectLabel = _activeSubjectLabel();

        return ListView(
          padding: const EdgeInsets.fromLTRB(_page, 12, _page, 24),
          children: [
            // --- Header: greeting + class selector, then date ---
            _DashboardHeader(
              greeting:
                  'Сайн байна уу, ${store.greetingLabelForClass(selectedClass)} аа 👋',
              dateLabel: dash.todayLabel,
              assignedClasses: assignedClasses,
              selectedClass: selectedClass,
              subjectLabel: subjectLabel,
              onClassChanged: onClassChanged,
            ),

            const SizedBox(height: _sectionGap),

            // --- Compact actions (journal / homework / advice) ---
            _CompactActionRow(
              gap: _cardGap,
              breakpoint: _actionBreakpoint,
              children: [
                _QuickActionCard(
                  icon: Icons.menu_book,
                  label: 'Хичээлийн журнал',
                  color: const Color(0xFF6A1B9A),
                  onTap: () => _openJournal(context),
                ),
                _QuickActionCard(
                  icon: Icons.assignment,
                  label: 'Даалгавар',
                  color: const Color(0xFFEF6C00),
                  onTap: () => _openHomework(context),
                ),
                _QuickActionCard(
                  icon: Icons.lightbulb_outline,
                  label: 'Зөвлөгөө',
                  color: AppColors.warning,
                  onTap: () => _openTeacherNotes(context),
                ),
              ],
            ),

            const SizedBox(height: _sectionGap),

            // --- Stats 2×2 ---
            _TwoByTwo(
              gap: _cardGap,
              children: [
                _StatCard(
                  badge: '👨‍🎓',
                  title: 'Нийт сурагч',
                  value: '${dash.studentCount}',
                  accent: const Color(0xFF3949AB),
                  onTap: () => _openStudents(context),
                ),
                _StatCard(
                  badge: '🟢',
                  title: 'Ирц',
                  value: dash.attendancePercentLabel,
                  accent: const Color(0xFF2E7D32),
                  onTap: () => _openAttendanceList(context),
                ),
                _StatCard(
                  badge: '⭐',
                  title: 'Ангийн дундаж',
                  value: dash.classAverageLabel,
                  accent: const Color(0xFFD81B60),
                  onTap: () => _openGradeList(context),
                ),
                _StatCard(
                  badge: '📢',
                  title: 'Шинэ зарлал',
                  value: '${dash.newAnnouncementCount}',
                  accent: AppColors.primary,
                  onTap: () => _openAnnouncementList(context),
                ),
              ],
            ),

            const SizedBox(height: _sectionGap),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Өнөөдрийн хичээл',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TimetableViewerScreen(
                          store: store,
                          title: 'Миний хуваарь',
                          mode: TimetableViewerMode.teacher,
                        ),
                      ),
                    );
                  },
                  child: const Text('Миний хуваарь'),
                ),
              ],
            ),
            const SizedBox(height: _cardGap),
            if (todayLessons.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Өнөөдөр хичээл байхгүй',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...todayLessons.map((lesson) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: _cardGap),
                  child: TeacherTodayLessonCard(
                    lesson: lesson,
                    onAttendance: () =>
                        _openAttendanceTake(context, className: lesson.classId),
                    onJournal: () => _openJournal(
                      context,
                      className: lesson.classId,
                      subjectName: lesson.subjectName,
                    ),
                    onHomework: () => _openHomeworkCreate(
                      context,
                      className: lesson.classId,
                      subjectName: lesson.subjectName,
                    ),
                    onGrade: () => _openGradeCreate(
                      context,
                      className: lesson.classId,
                      subjectName: lesson.subjectName,
                    ),
                  ),
                );
              }),

            const SizedBox(height: _sectionGap),

            Text('Сүүлийн үйл ажиллагаа', style: theme.textTheme.titleMedium),
            const SizedBox(height: _cardGap),
            if (dash.recentActivity.isEmpty)
              const _EmptyActivity()
            else
              _ActivityTimeline(items: dash.recentActivity),
          ],
        );
      },
    );
  }
}

/// Greeting left / class selector right; wraps selector under greeting on narrow widths.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.greeting,
    required this.dateLabel,
    required this.assignedClasses,
    required this.selectedClass,
    required this.subjectLabel,
    required this.onClassChanged,
  });

  final String greeting;
  final String dateLabel;
  final List<TeacherAssignedClass> assignedClasses;
  final String selectedClass;
  final String? subjectLabel;
  final Future<void> Function(String classId) onClassChanged;

  static const _sideBySideBreakpoint = 380.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greetingStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      height: 1.2,
    );
    final selector = _ClassDropdown(
      assignedClasses: assignedClasses,
      selectedClass: selectedClass,
      subjectLabel: subjectLabel,
      onChanged: onClassChanged,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= _sideBySideBreakpoint;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sideBySide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(greeting, style: greetingStyle)),
                  const SizedBox(width: 8),
                  selector,
                ],
              )
            else ...[
              Text(greeting, style: greetingStyle),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: selector),
            ],
            const SizedBox(height: 6),
            Text(
              dateLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ClassDropdown extends StatelessWidget {
  const _ClassDropdown({
    required this.assignedClasses,
    required this.selectedClass,
    required this.onChanged,
    this.subjectLabel,
  });

  final List<TeacherAssignedClass> assignedClasses;
  final String selectedClass;
  final String? subjectLabel;
  final Future<void> Function(String classId) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = subjectLabel?.trim();
    final label = (subject != null && subject.isNotEmpty)
        ? '$selectedClass анги · $subject'
        : '$selectedClass анги';

    return Material(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ClassDashboardScreen._radius),
        side: const BorderSide(color: AppColors.outlineSubtle),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Анги сонгох',
        initialValue: selectedClass,
        onSelected: (value) {
          onChanged(value);
        },
        itemBuilder: (context) => [
          for (final item in assignedClasses)
            PopupMenuItem(
              value: item.classId,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${item.className} анги',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.relationshipSubtitle.isNotEmpty)
                    Text(
                      item.relationshipSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TwoByTwo extends StatelessWidget {
  const _TwoByTwo({required this.children, required this.gap});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[0]),
              SizedBox(width: gap),
              Expanded(child: children[1]),
            ],
          ),
        ),
        SizedBox(height: gap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[2]),
              SizedBox(width: gap),
              Expanded(child: children[3]),
            ],
          ),
        ),
      ],
    );
  }
}

/// Responsive action row: 3 equal columns when wide, otherwise 2 + 1.
class _CompactActionRow extends StatelessWidget {
  const _CompactActionRow({
    required this.children,
    required this.gap,
    required this.breakpoint,
  });

  final List<Widget> children;
  final double gap;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    assert(children.length == 3);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= breakpoint;
        if (wide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(child: children[i]),
                ],
              ],
            ),
          );
        }
        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: children[0]),
                  SizedBox(width: gap),
                  Expanded(child: children[1]),
                ],
              ),
            ),
            SizedBox(height: gap),
            SizedBox(width: double.infinity, child: children[2]),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.badge,
    required this.title,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  final String badge;
  final String title;
  final String value;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(ClassDashboardScreen._radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ClassDashboardScreen._radius),
        splashColor: accent.withValues(alpha: 0.12),
        highlightColor: accent.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ClassDashboardScreen._radius),
            border: Border.all(color: AppColors.outlineSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(badge, style: const TextStyle(fontSize: 16)),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 16, color: accent),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(ClassDashboardScreen._radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ClassDashboardScreen._radius),
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.06),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ClassDashboardScreen._radius),
            border: Border.all(color: AppColors.outlineSubtle),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityTimeline extends StatelessWidget {
  const _ActivityTimeline({required this.items});

  final List<DashboardActivityItem> items;

  Color _color(DashboardActivityKind kind) {
    switch (kind) {
      case DashboardActivityKind.attendance:
        return const Color(0xFF2E7D32);
      case DashboardActivityKind.grade:
        return const Color(0xFF6A1B9A);
      case DashboardActivityKind.homework:
        return const Color(0xFFEF6C00);
      case DashboardActivityKind.announcement:
        return AppColors.primary;
      case DashboardActivityKind.note:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _TimelineRow(
            item: items[i],
            color: _color(items[i].kind),
            isLast: i == items.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.item,
    required this.color,
    required this.isLast,
  });

  final DashboardActivityItem item;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.outlineSubtle,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (item.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            style: theme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.timeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(ClassDashboardScreen._radius),
        border: Border.all(color: AppColors.outlineSubtle),
      ),
      child: Text(
        'Одоогоор үйл ажиллагаа байхгүй.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}
