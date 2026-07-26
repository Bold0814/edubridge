/// Password rules for teacher/admin accounts (not guardian/student PIN).
abstract final class PasswordRules {
  static final RegExp _hasLetter = RegExp(r'[A-Za-zА-Яа-яЁёӨөҮү]');
  static final RegExp _hasDigit = RegExp(r'\d');

  static const helperText =
      'Хамгийн багадаа 8 тэмдэгт, дор хаяж 1 үсэг болон 1 тоо оруулна.';

  static const combinedRequirementsMessage =
      'Нууц үг хамгийн багадаа 8 тэмдэгт бөгөөд үсэг, тоо агуулсан байна.';

  static const tooShortMessage = 'Нууц үг хамгийн багадаа 8 тэмдэгт байна.';
  static const missingLetterMessage = 'Нууц үгэнд дор хаяж 1 үсэг оруулна.';
  static const missingDigitMessage = 'Нууц үгэнд дор хаяж 1 тоо оруулна.';
  static const mismatchMessage = 'Нууц үг таарахгүй байна.';

  /// Returns a Mongolian error, or null when [password] may be stored.
  ///
  /// Teacher/admin password — not the 4-digit guardian/student PIN.
  static String? validateNewPassword(String password, String confirm) {
    final compositionFailures = <String>[];

    // Spaces-only (or empty) is invalid.
    if (password.trim().isEmpty) {
      compositionFailures.addAll(const ['length', 'letter', 'digit']);
    } else {
      if (password.length < 8) compositionFailures.add('length');
      if (!_hasLetter.hasMatch(password)) compositionFailures.add('letter');
      if (!_hasDigit.hasMatch(password)) compositionFailures.add('digit');
    }

    if (compositionFailures.length > 1) {
      return combinedRequirementsMessage;
    }
    if (compositionFailures.contains('length')) return tooShortMessage;
    if (compositionFailures.contains('letter')) return missingLetterMessage;
    if (compositionFailures.contains('digit')) return missingDigitMessage;

    if (password != confirm) return mismatchMessage;
    return null;
  }
}
