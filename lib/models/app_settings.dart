import 'subject.dart';

/// Legacy helpers kept for academic-year options and default subject seed names.
/// Prefer [SchoolSettings] / [Subject] for new code.
class AppSettings {
  const AppSettings({
    required this.schoolName,
    required this.schoolCode,
    required this.teacherName,
    required this.teacherPhone,
    required this.teacherEmail,
    required this.academicYear,
    required this.currentSemester,
  });

  final String schoolName;
  final String schoolCode;
  final String teacherName;
  final String teacherPhone;
  final String teacherEmail;
  final String academicYear;
  final String currentSemester;

  static const academicYearOptions = ['2025–2026', '2026–2027', '2027–2028'];

  static const semesterOptions = [
    '1-р улирал',
    '2-р улирал',
    '3-р улирал',
    '4-р улирал',
  ];

  static const defaults = AppSettings(
    schoolName: '',
    schoolCode: '',
    teacherName: '',
    teacherPhone: '',
    teacherEmail: '',
    academicYear: '2025–2026',
    currentSemester: '1-р улирал',
  );

  /// Prefer [Subject.defaultNames].
  static const defaultSubjects = Subject.defaultNames;

  AppSettings copyWith({
    String? schoolName,
    String? schoolCode,
    String? teacherName,
    String? teacherPhone,
    String? teacherEmail,
    String? academicYear,
    String? currentSemester,
  }) {
    return AppSettings(
      schoolName: schoolName ?? this.schoolName,
      schoolCode: schoolCode ?? this.schoolCode,
      teacherName: teacherName ?? this.teacherName,
      teacherPhone: teacherPhone ?? this.teacherPhone,
      teacherEmail: teacherEmail ?? this.teacherEmail,
      academicYear: academicYear ?? this.academicYear,
      currentSemester: currentSemester ?? this.currentSemester,
    );
  }
}
