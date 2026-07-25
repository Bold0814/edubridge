/// Per-school settings (academic year / semester / display name).
class SchoolSettings {
  const SchoolSettings({
    required this.schoolId,
    required this.schoolName,
    required this.academicYear,
    required this.currentSemester,
  });

  final String schoolId;
  final String schoolName;
  final String academicYear;
  final String currentSemester;

  /// Jan–Jul → previous–current year; Aug–Dec → current–next year.
  ///
  /// Uses an en dash to match stored values (e.g. `2025–2026`).
  static String currentAcademicYear([DateTime? now]) {
    final date = now ?? DateTime.now();
    final year = date.year;
    if (date.month <= 7) {
      return '${year - 1}–$year';
    }
    return '$year–${year + 1}';
  }

  /// Dropdown options including the computed current year and nearby years.
  static List<String> get academicYearOptions {
    final now = DateTime.now();
    final baseStart = now.month <= 7 ? now.year - 2 : now.year - 1;
    final rolling = <String>[
      for (var i = 0; i < 5; i++) '${baseStart + i}–${baseStart + i + 1}',
    ];
    final merged = <String>{
      '2025–2026',
      '2026–2027',
      '2027–2028',
      currentAcademicYear(now),
      ...rolling,
    };
    final list = merged.toList()..sort((a, b) => a.compareTo(b));
    return list;
  }

  static const semesterOptions = [
    '1-р улирал',
    '2-р улирал',
    '3-р улирал',
    '4-р улирал',
  ];

  static const defaultSchoolId = 'sch-default';

  static const defaults = SchoolSettings(
    schoolId: defaultSchoolId,
    schoolName: '',
    academicYear: '2025–2026',
    currentSemester: '1-р улирал',
  );

  static SchoolSettings emptyFor(String schoolId) => SchoolSettings(
    schoolId: schoolId,
    schoolName: '',
    academicYear: currentAcademicYear(),
    currentSemester: semesterOptions.first,
  );

  SchoolSettings copyWith({
    String? schoolId,
    String? schoolName,
    String? academicYear,
    String? currentSemester,
  }) {
    return SchoolSettings(
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      academicYear: academicYear ?? this.academicYear,
      currentSemester: currentSemester ?? this.currentSemester,
    );
  }
}
