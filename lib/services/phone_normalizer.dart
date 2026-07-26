/// Normalizes phone numbers for lookup/login within a school.
///
/// Canonical stored format (teacher profile + teacher login username):
/// digits-only local mobile, no spaces/hyphens/parentheses, no leading `+` or
/// country code. Examples that all store as `85406262`:
/// `85406262`, `85 406 262`, `+97685406262`, `976-8540-6262`.
abstract final class PhoneNormalizer {
  /// Canonical phone for storage and comparison.
  ///
  /// - trims whitespace
  /// - removes spaces, hyphens, parentheses, and other non-digits
  /// - strips Mongolia country code `976` / `+976` when present
  /// - returns digits-only (no leading `+`)
  static String normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    // +976XXXXXXXX / 976XXXXXXXX → local mobile
    if (digits.startsWith('976') && digits.length >= 11) {
      digits = digits.substring(3);
    }
    return digits;
  }
}
