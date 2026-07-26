/// PIN validation for guardian/student local login.
abstract final class PinRules {
  /// Exactly 4 numeric digits.
  static final RegExp pattern = RegExp(r'^\d{4}$');

  static const Set<String> commonPins = {
    '0000',
    '1111',
    '2222',
    '3333',
    '4444',
    '5555',
    '6666',
    '7777',
    '8888',
    '9999',
    '1234',
    '4321',
  };

  static bool isValid(String pin) => pattern.hasMatch(pin);

  static bool isCommon(String pin) => commonPins.contains(pin);

  /// Returns a Mongolian validation error, or null when [pin] may be stored.
  static String? validateNewPin(String pin, String confirm) {
    if (!isValid(pin)) return 'PIN 4 оронтой байна';
    if (pin != confirm) return 'PIN таарахгүй байна';
    if (isCommon(pin)) return 'Энэ PIN-ийг ашиглах боломжгүй';
    return null;
  }
}
