import 'package:flutter/material.dart';

import '../../navigation/app_navigation.dart';
import '../../services/learner_timeline.dart';
import '../../services/timetable_service.dart';
import '../../state/app_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/summaries/learner_timeline_panel.dart';
import '../../widgets/today_timetable_card.dart';
import '../../widgets/session_menu_button.dart';
import '../teacher_notes_screen.dart';
import '../timetable_viewer_screen.dart';
import 'guardian_announcements_screen.dart';
import 'guardian_attendance_history_screen.dart';
import 'guardian_attendance_screen.dart';
import 'guardian_grades_screen.dart';
import 'guardian_homework_screen.dart';

/// Parent / guardian home — same timeline widgets as Student, for selected child.
class GuardianHomeScreen extends StatelessWidget {
  const GuardianHomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final students = store.guardianPortalStudents;
        final selected = store.selectedGuardianStudent;
        final schoolName = store.activeSchool?.name;

        return Scaffold(
          backgroundColor: const Color(0xFFEEF4FA),
          appBar: AppBar(
            title: const Text('Асран хамгаалагч'),
            actions: [
              SessionMenuButton(store: store),
            ],
          ),
          body: students.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.page),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Танд холбоотой сурагч олдсонгүй.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sectionSm),
                        TextButton(
                          onPressed: () =>
                              AppNavigation.logoutToLogin(context, store),
                          child: const Text('Гарах'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  children: [
                    if (schoolName != null && schoolName.isNotEmpty)
                      Text(
                        schoolName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Text('Асран хамгаалагч', style: theme.textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.sectionSm),
                    if (selected != null)
                      Text(
                        '${selected.fullName} · ${selected.className}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    if (selected != null) ...[
                      const SizedBox(height: AppSpacing.sectionSm),
                      TodayTimetableCard(
                        lessons: TimetableService.todayLessonsForClass(
                          store,
                          selected.className,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.item),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.calendar_month_outlined),
                          title: const Text('Хичээлийн хуваарь'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TimetableViewerScreen(
                                  store: store,
                                  title: 'Хичээлийн хуваарь',
                                  mode: TimetableViewerMode.guardian,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sectionSm),
                      LearnerTimelinePanel(
                        data: GuardianTimeline.fromStore(store, selected).data,
                        showAttendanceStats: true,
                        showUnreadAnnouncements: true,
                        onAttendanceTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GuardianAttendanceScreen(
                                store: store,
                                student: selected,
                              ),
                            ),
                          );
                          store.refreshCalendarBoundViews();
                        },
                        onGradesTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GuardianGradesScreen(
                                store: store,
                                student: selected,
                              ),
                            ),
                          );
                        },
                        onHomeworkTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GuardianHomeworkScreen(
                                store: store,
                                student: selected,
                              ),
                            ),
                          );
                        },
                        onAnnouncementsTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GuardianAnnouncementsScreen(
                                store: store,
                                student: selected,
                              ),
                            ),
                          );
                        },
                        onNotesTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LearnerNotesScreen(
                                store: store,
                                student: selected,
                                forGuardian: true,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.section),
                      Text('Дэлгэрэнгүй', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.gap),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width =
                              (constraints.maxWidth - AppSpacing.gap) / 2;
                          return Wrap(
                            spacing: AppSpacing.gap,
                            runSpacing: AppSpacing.gap,
                            children: [
                              _ModuleCard(
                                width: width,
                                title: 'Ирц',
                                icon: Icons.fact_check_outlined,
                                color: AppColors.present,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          GuardianAttendanceHistoryScreen(
                                            store: store,
                                            student: selected,
                                          ),
                                    ),
                                  );
                                  store.refreshCalendarBoundViews();
                                },
                              ),
                              _ModuleCard(
                                width: width,
                                title: 'Дүн',
                                icon: Icons.grade_outlined,
                                color: AppColors.grade,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          GuardianGradesScreen(
                                            store: store,
                                            student: selected,
                                          ),
                                    ),
                                  );
                                },
                              ),
                              _ModuleCard(
                                width: width,
                                title: 'Даалгавар',
                                icon: Icons.assignment_outlined,
                                color: AppColors.homework,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          GuardianHomeworkScreen(
                                            store: store,
                                            student: selected,
                                          ),
                                    ),
                                  );
                                },
                              ),
                              _ModuleCard(
                                width: width,
                                title: 'Зарлал',
                                icon: Icons.campaign_outlined,
                                color: AppColors.announcement,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          GuardianAnnouncementsScreen(
                                            store: store,
                                            student: selected,
                                          ),
                                    ),
                                  );
                                },
                              ),
                              _ModuleCard(
                                width: width,
                                title: 'Зөвлөгөө',
                                icon: Icons.lightbulb_outline,
                                color: AppColors.warning,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LearnerNotesScreen(
                                        store: store,
                                        student: selected,
                                        forGuardian: true,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.section),
                      TextButton(
                        onPressed: () =>
                            AppNavigation.logoutToLogin(context, store),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Гарах'),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.width,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final double width;
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.card,
              vertical: AppSpacing.sectionSm,
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: AppSpacing.item),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
