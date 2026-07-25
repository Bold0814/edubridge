import '../models/announcement.dart';
import '../models/attendance_record.dart';
import '../models/homework.dart';
import '../models/student.dart';
import '../models/teacher_note.dart';
import '../state/app_store.dart';

/// Shared read-only snapshot built from existing AppStore/SQLite data.
class LearnerTimelineData {
  const LearnerTimelineData({
    required this.student,
    required this.todaysAttendance,
    required this.averageGrade,
    required this.dueSoonHomework,
    required this.latestAnnouncement,
    required this.latestTeacherNote,
    required this.attendancePresentCount,
    required this.attendanceLateCount,
    required this.attendanceAbsentCount,
    required this.unreadAnnouncementCount,
  });

  final Student student;
  final AttendanceStatus? todaysAttendance;
  final double? averageGrade;
  final List<Homework> dueSoonHomework;
  final Announcement? latestAnnouncement;
  final TeacherNote? latestTeacherNote;
  final int attendancePresentCount;
  final int attendanceLateCount;
  final int attendanceAbsentCount;
  final int unreadAnnouncementCount;

  int get attendanceRecordedDays =>
      attendancePresentCount + attendanceLateCount + attendanceAbsentCount;
}

/// Student-facing timeline over existing attendance / grades / homework / announcements.
class StudentTimeline {
  StudentTimeline._(this.data);

  final LearnerTimelineData data;

  factory StudentTimeline.fromStore(AppStore store, Student student) {
    return StudentTimeline._(_build(store, student, forGuardian: false));
  }
}

/// Guardian-facing timeline for a selected child (same underlying tables).
class GuardianTimeline {
  GuardianTimeline._(this.data);

  final LearnerTimelineData data;

  factory GuardianTimeline.fromStore(AppStore store, Student student) {
    return GuardianTimeline._(_build(store, student, forGuardian: true));
  }
}

LearnerTimelineData _build(
  AppStore store,
  Student student, {
  required bool forGuardian,
}) {
  final attendanceRows = store.attendanceEntriesForStudent(student);
  var present = 0;
  var late = 0;
  var absent = 0;
  for (final row in attendanceRows) {
    switch (row.status) {
      case AttendanceStatus.present:
        present++;
      case AttendanceStatus.late:
        late++;
      case AttendanceStatus.absent:
        absent++;
    }
  }

  final dueSoon = store
      .homeworkForStudentClass(student)
      .where((h) => h.status == HomeworkStatus.pending)
      .take(5)
      .toList(growable: false);

  final announcements = store.announcementsForStudentClass(student);
  final latest = announcements.isEmpty ? null : announcements.first;

  final notes = forGuardian
      ? store.notesVisibleToGuardian(student)
      : store.notesVisibleToStudent(student);
  final latestNote = notes.isEmpty ? null : notes.first;

  return LearnerTimelineData(
    student: student,
    todaysAttendance: store.todaysAttendanceStatus(student),
    averageGrade: store.averageGradeForStudent(student),
    dueSoonHomework: dueSoon,
    latestAnnouncement: latest,
    latestTeacherNote: latestNote,
    attendancePresentCount: present,
    attendanceLateCount: late,
    attendanceAbsentCount: absent,
    unreadAnnouncementCount: forGuardian
        ? store.unreadGuardianAnnouncementCount(student)
        : 0,
  );
}
