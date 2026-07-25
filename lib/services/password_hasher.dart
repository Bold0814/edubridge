import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Local password hashing for the EduBridge prototype.
///
/// Uses SHA-256 with a per-password random salt.
/// Production authentication must move to a secure backend (never rely on
/// client-side hashes alone for real accounts).
class PasswordHasher {
  PasswordHasher._();

  static final _random = Random.secure();

  /// Returns `saltHex:hashHex`.
  static String hashPassword(String plainPassword) {
    final saltBytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final saltHex = _toHex(saltBytes);
    final hashHex = _hash(saltBytes, plainPassword);
    return '$saltHex:$hashHex';
  }

  static bool verifyPassword(String plainPassword, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final saltBytes = _fromHex(parts[0]);
    if (saltBytes == null) return false;
    final expected = parts[1];
    final actual = _hash(saltBytes, plainPassword);
    return _constantTimeEquals(actual, expected);
  }

  static String _hash(List<int> saltBytes, String password) {
    final bytes = <int>[...saltBytes, ...utf8.encode(password)];
    return sha256.convert(bytes).toString();
  }

  static String _toHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int>? _fromHex(String hex) {
    if (hex.length.isOdd) return null;
    try {
      return [
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ];
    } catch (_) {
      return null;
    }
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
