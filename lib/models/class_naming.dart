import 'package:flutter/foundation.dart';

/// Parsed / validated grade-level + optional class section.
class ClassNameParts {
  const ClassNameParts({
    required this.gradeLevel,
    this.section,
  });

  final int gradeLevel;

  /// Normalized lowercase section (e.g. `а`), or null when absent.
  final String? section;
}

/// Builds and parses Mongolian class display names for grades 1–12.
class ClassNaming {
  ClassNaming._();

  static const minGrade = 1;
  static const maxGrade = 12;

  /// Optional section: short Cyrillic/Latin letters or digits.
  static final RegExp sectionPattern = RegExp(
    r'^[а-яёөүa-z0-9]{1,3}$',
    caseSensitive: false,
  );

  static bool isValidGradeLevel(int gradeLevel) {
    return gradeLevel >= minGrade && gradeLevel <= maxGrade;
  }

  /// Trims and lowercases; empty → null. Invalid characters → null.
  static String? normalizeSection(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (!sectionPattern.hasMatch(lower)) return null;
    return lower;
  }

  /// Validates a raw section field from the form (empty is allowed).
  static String? validateSectionInput(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (normalizeSection(trimmed) == null) {
      return 'Ангийн бүлэг буруу байна';
    }
    return null;
  }

  /// Display name rules:
  /// - 12 + а → `12а анги`
  /// - 5 + (none) → `5-р анги`
  static String displayName({
    required int gradeLevel,
    String? section,
  }) {
    if (!isValidGradeLevel(gradeLevel)) {
      throw ArgumentError.value(gradeLevel, 'gradeLevel', 'Must be 1–12');
    }
    final sec = normalizeSection(section);
    if (sec == null) return '$gradeLevel-р анги';
    return '$gradeLevel$sec анги';
  }

  static List<int> get gradeLevels => [
    for (var g = minGrade; g <= maxGrade; g++) g,
  ];

  static String gradeLevelLabel(int gradeLevel) => '$gradeLevel-р анги';

  /// Best-effort parse of existing class names. Returns null when unsafe.
  static ClassNameParts? tryParse(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) return null;

    // `5-р анги` / `12-р анги`
    final numbered = RegExp(
      r'^(\d{1,2})\s*[-–]?\s*р\s*анги$',
      caseSensitive: false,
    ).firstMatch(name);
    if (numbered != null) {
      final grade = int.tryParse(numbered.group(1)!);
      if (grade != null && isValidGradeLevel(grade)) {
        return ClassNameParts(gradeLevel: grade);
      }
      return null;
    }

    // `12а анги` / `5б анги`
    final withSuffix = RegExp(
      r'^(\d{1,2})\s*([а-яёөүa-z0-9]{1,3})\s*анги$',
      caseSensitive: false,
    ).firstMatch(name);
    if (withSuffix != null) {
      final grade = int.tryParse(withSuffix.group(1)!);
      final section = normalizeSection(withSuffix.group(2));
      if (grade != null && isValidGradeLevel(grade) && section != null) {
        return ClassNameParts(gradeLevel: grade, section: section);
      }
      return null;
    }

    // Compact legacy: `12а`, `6А`, `7Б`
    final compact = RegExp(
      r'^(\d{1,2})([а-яёөүa-zА-ЯЁӨҮA-Z]{1,3})$',
    ).firstMatch(name);
    if (compact != null) {
      final grade = int.tryParse(compact.group(1)!);
      final section = normalizeSection(compact.group(2));
      if (grade != null && isValidGradeLevel(grade) && section != null) {
        return ClassNameParts(gradeLevel: grade, section: section);
      }
      return null;
    }

    // Digits only: `5`, `12`
    final digitsOnly = RegExp(r'^(\d{1,2})$').firstMatch(name);
    if (digitsOnly != null) {
      final grade = int.tryParse(digitsOnly.group(1)!);
      if (grade != null && isValidGradeLevel(grade)) {
        return ClassNameParts(gradeLevel: grade);
      }
    }

    return null;
  }

  static void debugLogUnparsed(String name) {
    if (!kDebugMode) return;
    debugPrint('LEGACY_CLASS_UNPARSED name=$name');
  }

  static bool sameIdentity({
    required int? aGrade,
    required String? aSection,
    required int? bGrade,
    required String? bSection,
  }) {
    if (aGrade == null || bGrade == null) return false;
    return aGrade == bGrade &&
        (normalizeSection(aSection) ?? '') == (normalizeSection(bSection) ?? '');
  }
}
