import '../models/attendance_record.dart';

const sampleAttendanceRecords = [
  AttendanceRecord.legacy(date: 'Өнөөдөр', status: AttendanceStatus.present),
  AttendanceRecord.legacy(
    date: '2026 оны 3 сарын 16',
    status: AttendanceStatus.present,
  ),
  AttendanceRecord.legacy(
    date: '2026 оны 3 сарын 15',
    status: AttendanceStatus.late,
  ),
  AttendanceRecord.legacy(
    date: '2026 оны 3 сарын 14',
    status: AttendanceStatus.present,
  ),
  AttendanceRecord.legacy(
    date: '2026 оны 3 сарын 13',
    status: AttendanceStatus.absent,
  ),
  AttendanceRecord.legacy(
    date: '2026 оны 3 сарын 12',
    status: AttendanceStatus.present,
  ),
];
