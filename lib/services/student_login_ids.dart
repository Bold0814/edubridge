/// School-scoped student login code helpers.
abstract final class StudentLoginIds {
  static final RegExp _sequencePattern = RegExp(
    r'-S(\d+)$',
    caseSensitive: false,
  );

  /// Trims surrounding spaces; letters/numbers (and separators) are kept.
  static String normalizeCode(String raw) => raw.trim();

  /// Case-insensitive compare key for uniqueness checks.
  static String compareKey(String raw) => normalizeCode(raw).toLowerCase();

  /// Globally unique [UserAccount.username] for a school-scoped student code.
  static String usernameFor({required String schoolId, required String code}) {
    return '$schoolId:${compareKey(code)}';
  }

  /// Formats `{prefix}-S0001`.
  static String formatCode({required String prefix, required int sequence}) {
    final padded = sequence.toString().padLeft(4, '0');
    return '$prefix-S$padded';
  }

  /// Parses the numeric sequence from a generated code, if present.
  static int? sequenceFromCode(String code) {
    final match = _sequencePattern.firstMatch(normalizeCode(code));
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Uses [schoolCode] when it is a short stable identifier.
  static String? prefixFromSchoolCode(String? schoolCode) {
    final trimmed = schoolCode?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^[A-Za-z0-9]{2,6}$').hasMatch(trimmed)) {
      return trimmed.toUpperCase();
    }
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 2 && digits.length <= 6) return digits;
    return null;
  }

  /// Deterministic 3-digit prefix (100–999) derived from [schoolId].
  static String deriveStablePrefix(String schoolId) {
    var hash = 0;
    for (final unit in schoolId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return (100 + (hash % 900)).toString();
  }
}
