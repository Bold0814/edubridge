import 'class_naming.dart';

/// School class. [id] is the SQLite primary key (equals [name] for migrated data).
class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.name,
    required this.schoolId,
    this.homeroomTeacherId,
    this.gradeLevel,
    this.section,
  });

  final String id;
  final String name;
  final String schoolId;
  final String? homeroomTeacherId;

  /// Integer 1–12 when known; null for unparsed legacy rows.
  final int? gradeLevel;

  /// Normalized lowercase section (e.g. `а`); null when absent / unknown.
  final String? section;

  SchoolClass copyWith({
    String? name,
    String? schoolId,
    String? homeroomTeacherId,
    bool clearHomeroom = false,
    int? gradeLevel,
    String? section,
    bool clearSection = false,
    bool clearGradeLevel = false,
  }) {
    return SchoolClass(
      id: id,
      name: name ?? this.name,
      schoolId: schoolId ?? this.schoolId,
      homeroomTeacherId: clearHomeroom
          ? null
          : (homeroomTeacherId ?? this.homeroomTeacherId),
      gradeLevel: clearGradeLevel ? null : (gradeLevel ?? this.gradeLevel),
      section: clearSection ? null : (section ?? this.section),
    );
  }

  /// Best-effort enrichment from [name] when grade/section columns are empty.
  SchoolClass withParsedNaming() {
    if (gradeLevel != null) return this;
    final parsed = ClassNaming.tryParse(name);
    if (parsed == null) {
      ClassNaming.debugLogUnparsed(name);
      return this;
    }
    return copyWith(
      gradeLevel: parsed.gradeLevel,
      section: parsed.section,
      clearSection: parsed.section == null,
    );
  }
}
