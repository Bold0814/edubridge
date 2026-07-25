/// Normalizes phone numbers for guardian lookup/reuse within a school.
abstract final class PhoneNormalizer {
  /// Trims, removes spaces/hyphens, keeps a leading `+` when present.
  static String normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final hasPlus = trimmed.startsWith('+');
    final withoutSeparators = trimmed.replaceAll(RegExp(r'[\s\-]+'), '');
    final digits = withoutSeparators.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return hasPlus ? '+$digits' : digits;
  }
}
