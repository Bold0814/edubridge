import 'school_class.dart';
import 'subject.dart';

/// A class the active teacher may open (homeroom and/or subject assignment).
class TeacherAssignedClass {
  const TeacherAssignedClass({
    required this.schoolClass,
    required this.isHomeroom,
    required this.subjects,
  });

  final SchoolClass schoolClass;
  final bool isHomeroom;

  /// Active subjects this teacher teaches in [schoolClass], name-sorted.
  final List<Subject> subjects;

  String get classId => schoolClass.id;
  String get className => schoolClass.name;

  /// Compact relationship line for the class selector.
  String get relationshipSubtitle {
    final subjectPart = _formatSubjects(subjects);
    if (isHomeroom && subjectPart != null) {
      return 'Анги удирдсан · $subjectPart';
    }
    if (isHomeroom) return 'Анги удирдсан';
    return subjectPart ?? '';
  }

  static String? _formatSubjects(List<Subject> subjects) {
    if (subjects.isEmpty) return null;
    if (subjects.length == 1) return subjects.first.name;
    if (subjects.length == 2) {
      return '${subjects[0].name} · ${subjects[1].name}';
    }
    final extra = subjects.length - 2;
    return '${subjects[0].name}, ${subjects[1].name} +$extra хичээл';
  }
}
