import '../models/announcement.dart';
import '../models/attendance_record.dart';
import '../models/grade.dart';
import '../models/homework.dart';
import '../models/teacher_note.dart';
import '../state/app_store.dart';

/// One-shot dashboard view-model built from already-loaded AppStore data.
class TeacherDashboardSnapshot {
  const TeacherDashboardSnapshot({
    required this.todayLabel,
    required this.studentCount,
    required this.attendancePercentLabel,
    required this.classAverageLabel,
    required this.newAnnouncementCount,
    required this.newTeacherNoteCount,
    required this.recentActivity,
  });

  final String todayLabel;
  final int studentCount;
  final String attendancePercentLabel;
  final String classAverageLabel;
  final int newAnnouncementCount;
  final int newTeacherNoteCount;
  final List<DashboardActivityItem> recentActivity;

  factory TeacherDashboardSnapshot.fromStore(
    AppStore store,
    String className, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final todayLabel = '${today.year} оны ${today.month} сарын ${today.day}';

    final attendanceRecords = store.attendanceFor(className);
    final subjectId = store.activeContext.subjectId;
    final subjectName = store.activeSubjectName;
    final grades = store.gradesForClass(className, subjectName: subjectName);
    final homework = store.homeworkFor(className, subjectId: subjectId);
    final announcements = store.announcementsFor(className);
    final students = store.studentsFor(className);
    final notes = store.teacherNotesForClass(className);
    final classAverage = store.averageScore(grades);

    return TeacherDashboardSnapshot(
      todayLabel: todayLabel,
      studentCount: students.length,
      attendancePercentLabel: _overallAttendancePercent(attendanceRecords),
      classAverageLabel: classAverage == null
          ? '—'
          : classAverage.toStringAsFixed(1),
      newAnnouncementCount: store.unreadAnnouncementCount(className),
      newTeacherNoteCount: notes.length,
      recentActivity: _recentActivity(
        attendanceRecords: attendanceRecords,
        grades: grades,
        homework: homework,
        announcements: announcements,
        notes: notes,
        now: today,
      ),
    );
  }

  static String _overallAttendancePercent(List<AttendanceRecord> records) {
    var present = 0;
    var total = 0;
    for (final record in records) {
      present += record.presentCount;
      total += record.presentCount + record.lateCount + record.absentCount;
    }
    if (total == 0) return '0%';
    return '${(present / total * 100).round()}%';
  }

  static String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static List<DashboardActivityItem> _recentActivity({
    required List<AttendanceRecord> attendanceRecords,
    required List<Grade> grades,
    required List<Homework> homework,
    required List<Announcement> announcements,
    required List<TeacherNote> notes,
    required DateTime now,
  }) {
    final items = <DashboardActivityItem>[];

    for (final record in attendanceRecords) {
      items.add(
        DashboardActivityItem(
          title: 'Ирц бүртгэлээ',
          subtitle: record.summaryText,
          sortDate: AttendanceRecord.tryParseCalendarDate(record.date),
          kind: DashboardActivityKind.attendance,
        ),
      );
    }

    for (var i = 0; i < grades.length; i++) {
      final grade = grades[i];
      items.add(
        DashboardActivityItem(
          title: '${grade.subject} дүн орууллаа',
          subtitle: '${grade.studentName} • ${grade.scoreWithLetter}',
          sortDate: null,
          kind: DashboardActivityKind.grade,
          fallbackOrder: i,
        ),
      );
    }

    for (final item in homework) {
      items.add(
        DashboardActivityItem(
          title: 'Даалгавар нэмлээ',
          subtitle: '${item.subject} • ${item.title}',
          sortDate: AttendanceRecord.tryParseCalendarDate(item.dueDate),
          kind: DashboardActivityKind.homework,
        ),
      );
    }

    for (final item in announcements) {
      items.add(
        DashboardActivityItem(
          title: 'Зарлал нийтэллээ',
          subtitle: item.title,
          sortDate: AttendanceRecord.tryParseCalendarDate(item.date),
          kind: DashboardActivityKind.announcement,
        ),
      );
    }

    for (final item in notes) {
      items.add(
        DashboardActivityItem(
          title: 'Зөвлөгөө бичлээ',
          subtitle: item.title,
          sortDate: item.createdAtDate,
          kind: DashboardActivityKind.note,
        ),
      );
    }

    items.sort((a, b) {
      final ad = a.sortDate;
      final bd = b.sortDate;
      if (ad != null && bd != null) return bd.compareTo(ad);
      if (ad != null) return -1;
      if (bd != null) return 1;
      return a.fallbackOrder.compareTo(b.fallbackOrder);
    });

    final limited = items.length <= 10 ? items : items.sublist(0, 10);

    // Stable display times for timeline (newest → later morning clock).
    final base = DateTime(now.year, now.month, now.day, 8, 30);
    return [
      for (var i = 0; i < limited.length; i++)
        limited[i].copyWith(
          timeLabel: _formatTime(base.add(Duration(minutes: i * 45))),
        ),
    ];
  }
}

enum DashboardActivityKind { attendance, grade, homework, announcement, note }

class DashboardActivityItem {
  const DashboardActivityItem({
    required this.title,
    required this.subtitle,
    required this.sortDate,
    required this.kind,
    this.fallbackOrder = 0,
    this.timeLabel = '',
  });

  final String title;
  final String subtitle;
  final DateTime? sortDate;
  final DashboardActivityKind kind;
  final int fallbackOrder;
  final String timeLabel;

  DashboardActivityItem copyWith({String? timeLabel}) {
    return DashboardActivityItem(
      title: title,
      subtitle: subtitle,
      sortDate: sortDate,
      kind: kind,
      fallbackOrder: fallbackOrder,
      timeLabel: timeLabel ?? this.timeLabel,
    );
  }
}
