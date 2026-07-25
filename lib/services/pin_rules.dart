/// PIN validation for guardian/student local login.
abstract final class PinRules {
  /// 4–6 numeric digits only.
  static final RegExp pattern = RegExp(r'^\d{4,6}$');

  static const Set<String> commonPins = {'0000', '1111', '1234', '4321'};

  static bool isValid(String pin) => pattern.hasMatch(pin);

  static bool isCommon(String pin) => commonPins.contains(pin);

  /// Returns a Mongolian validation error, or null when [pin] may be stored.
  static String? validateNewPin(String pin, String confirm) {
    if (!isValid(pin)) return 'PIN 4–6 оронтой байна';
    if (pin != confirm) return 'PIN таарахгүй байна';
    if (isCommon(pin)) return 'Энэ PIN-ийг ашиглах боломжгүй';
    return null;
  }
}
