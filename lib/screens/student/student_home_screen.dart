import 'package:flutter/material.dart';

import '../../navigation/app_navigation.dart';
import '../../services/learner_timeline.dart';
import '../../services/timetable_service.dart';
import '../../state/app_store.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/session_menu_button.dart';
import '../../widgets/summaries/learner_timeline_panel.dart';
import '../../widgets/today_timetable_card.dart';
import '../guardian/guardian_announcements_screen.dart';
import '../guardian/guardian_attendance_screen.dart';
import '../guardian/guardian_grades_screen.dart';
import '../guardian/guardian_homework_screen.dart';
import '../teacher_notes_screen.dart';
import '../timetable_viewer_screen.dart';

/// Student home — read-only timeline over shared AppStore data.
class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final user = store.authenticatedUser;
        final studentId = store.activeContext.studentId ?? user?.studentId;
        final student = studentId == null ? null : store.studentById(studentId);
        final schoolName = store.activeSchool?.name;

        return Scaffold(
          backgroundColor: const Color(0xFFEEF4FA),
          appBar: AppBar(
            title: const Text('Сурагч'),
            actions: [
              SessionMenuButton(store: store, showChangeContext: false),
            ],
          ),
          body: student == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Холбоотой сурагч олдсонгүй.'),
                      TextButton(
                        onPressed: () =>
                            AppNavigation.logoutToLogin(context, store),
                        child: const Text('Гарах'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  children: [
                    if (schoolName != null && schoolName.isNotEmpty)
                      Text(
                        schoolName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Text(
                      student.fullName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${student.className} анги',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sectionSm),
                    TodayTimetableCard(
                      lessons: TimetableService.todayLessonsForClass(
                        store,
                        student.className,
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
                                mode: TimetableViewerMode.student,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sectionSm),
                    LearnerTimelinePanel(
                      data: StudentTimeline.fromStore(store, student).data,
                      onAttendanceTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GuardianAttendanceScreen(
                              store: store,
                              student: student,
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
                              student: student,
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
                              student: student,
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
                              student: student,
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
                              student: student,
                              forGuardian: false,
                            ),
                          ),
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
                ),
        );
      },
    );
  }
}
