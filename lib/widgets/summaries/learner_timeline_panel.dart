import 'package:flutter/material.dart';

import '../../services/learner_timeline.dart';
import '../../theme/app_spacing.dart';
import 'announcement_summary_card.dart';
import 'attendance_summary_card.dart';
import 'grade_summary_card.dart';
import 'homework_summary_card.dart';
import 'teacher_note_summary_card.dart';

/// Shared stack of timeline summary cards for Student and Guardian.
class LearnerTimelinePanel extends StatelessWidget {
  const LearnerTimelinePanel({
    super.key,
    required this.data,
    this.showAttendanceStats = false,
    this.showUnreadAnnouncements = false,
    this.onAttendanceTap,
    this.onGradesTap,
    this.onHomeworkTap,
    this.onAnnouncementsTap,
    this.onNotesTap,
  });

  final LearnerTimelineData data;
  final bool showAttendanceStats;
  final bool showUnreadAnnouncements;
  final VoidCallback? onAttendanceTap;
  final VoidCallback? onGradesTap;
  final VoidCallback? onHomeworkTap;
  final VoidCallback? onAnnouncementsTap;
  final VoidCallback? onNotesTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AttendanceSummaryCard(
          todaysStatus: data.todaysAttendance,
          presentCount: data.attendancePresentCount,
          lateCount: data.attendanceLateCount,
          absentCount: data.attendanceAbsentCount,
          showBriefStats: showAttendanceStats,
          onTap: onAttendanceTap,
        ),
        const SizedBox(height: AppSpacing.gap),
        GradeSummaryCard(averageGrade: data.averageGrade, onTap: onGradesTap),
        const SizedBox(height: AppSpacing.gap),
        HomeworkSummaryCard(
          dueSoonHomework: data.dueSoonHomework,
          onTap: onHomeworkTap,
        ),
        const SizedBox(height: AppSpacing.gap),
        AnnouncementSummaryCard(
          latestAnnouncement: data.latestAnnouncement,
          unreadCount: showUnreadAnnouncements
              ? data.unreadAnnouncementCount
              : null,
          onTap: onAnnouncementsTap,
        ),
        const SizedBox(height: AppSpacing.gap),
        TeacherNoteSummaryCard(
          latestNote: data.latestTeacherNote,
          onTap: onNotesTap,
        ),
      ],
    );
  }
}
