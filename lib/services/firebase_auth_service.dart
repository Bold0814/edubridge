import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Mongolian user-facing Auth error; never exposes raw Firebase messages.
class FirebaseAuthServiceException implements Exception {
  FirebaseAuthServiceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Firebase Auth foundation (does not replace local SQLite login).
class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth}) : _authOverride = auth;

  final FirebaseAuth? _authOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  static const defaultErrorMessage = 'Нэвтрэх үед алдаа гарлаа.';
  static const emailInUseMessage = 'Энэ нэвтрэх мэдээлэл бүртгэлтэй байна.';
  static const weakPasswordMessage = 'Нууц үг шаардлага хангахгүй байна.';
  static const invalidCredentialMessage = 'Нэвтрэх мэдээлэл буруу байна.';
  static const networkMessage = 'Сүлжээний алдаа гарлаа.';
  static const tooManyRequestsMessage =
      'Олон удаа оролдлоо. Түр хүлээгээд дахин оролдоно уу.';

  static const createSuccessMessage = 'Туршилтын эрх амжилттай үүслээ.';
  static const signInSuccessMessage = 'Firebase Auth нэвтрэлт амжилттай.';
  static const signOutSuccessMessage = 'Firebase Auth-аас гарлаа.';
  static const debugTestUserEmail = 'admin@test.com';
  static const deleteDebugUserSuccessMessage =
      'Туршилтын хэрэглэгч устгагдлаа.';
  static const deleteDebugUserNeedSignInMessage =
      'Эхлээд admin@test.com-р нэвтэрнэ үү.';

  /// Debug-only Auth check UI gate (never true in release).
  static bool isDebugAuthCheckEnabled({bool? forceDebugMode}) =>
      forceDebugMode ?? kDebugMode;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> createAccount({
    required String internalEmail,
    required String password,
  }) async {
    _assertAdminTeacherPassword(password);
    final email = internalEmail.trim().toLowerCase();
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e, st) {
      _debugLogAuthError('createAccount', e, st, email: email);
      throw FirebaseAuthServiceException(
        messageForAuthCode(e.code),
        code: e.code,
      );
    } catch (e, st) {
      _debugLogRaw('createAccount', e, st);
      throw FirebaseAuthServiceException(defaultErrorMessage);
    }
  }

  Future<UserCredential> signIn({
    required String internalEmail,
    required String password,
  }) async {
    final email = internalEmail.trim().toLowerCase();
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e, st) {
      _debugLogAuthError('signIn', e, st, email: email);
      throw FirebaseAuthServiceException(
        messageForAuthCode(e.code),
        code: e.code,
      );
    } catch (e, st) {
      _debugLogRaw('signIn', e, st);
      throw FirebaseAuthServiceException(defaultErrorMessage);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e, st) {
      _debugLogAuthError('signOut', e, st);
      throw FirebaseAuthServiceException(
        messageForAuthCode(e.code),
        code: e.code,
      );
    } catch (e, st) {
      _debugLogRaw('signOut', e, st);
      throw FirebaseAuthServiceException(defaultErrorMessage);
    }
  }

  /// Debug-only: deletes [debugTestUserEmail] via the signed-in client user.
  ///
  /// If not already signed in as that user and [password] is provided, signs in
  /// first then deletes so the account can be recreated.
  Future<void> deleteDebugTestUser({String? password}) async {
    if (!kDebugMode) {
      throw FirebaseAuthServiceException(defaultErrorMessage);
    }

    final target = debugTestUserEmail;
    try {
      var user = _auth.currentUser;
      final signedInAsTarget =
          user != null && (user.email ?? '').trim().toLowerCase() == target;

      if (!signedInAsTarget) {
        final pass = password ?? '';
        if (pass.isEmpty) {
          throw FirebaseAuthServiceException(deleteDebugUserNeedSignInMessage);
        }
        await _auth.signInWithEmailAndPassword(email: target, password: pass);
        user = _auth.currentUser;
      }

      if (user == null || (user.email ?? '').trim().toLowerCase() != target) {
        throw FirebaseAuthServiceException(deleteDebugUserNeedSignInMessage);
      }

      await user.delete();
      if (kDebugMode) {
        debugPrint(
          'FirebaseAuthService.deleteDebugTestUser deleted email=$target',
        );
      }
    } on FirebaseAuthServiceException {
      rethrow;
    } on FirebaseAuthException catch (e, st) {
      _debugLogAuthError('deleteDebugTestUser', e, st, email: target);
      throw FirebaseAuthServiceException(
        messageForAuthCode(e.code),
        code: e.code,
      );
    } catch (e, st) {
      _debugLogRaw('deleteDebugTestUser', e, st);
      throw FirebaseAuthServiceException(defaultErrorMessage);
    }
  }

  /// Admin / teacher Firebase password: ≥8 chars, ≥1 letter, ≥1 digit.
  /// Local guardian/student PIN policy is unchanged and not applied here.
  static bool meetsAdminTeacherPasswordPolicy(String password) {
    if (password.length < 8) return false;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    return hasLetter && hasDigit;
  }

  static void _assertAdminTeacherPassword(String password) {
    if (!meetsAdminTeacherPasswordPolicy(password)) {
      throw FirebaseAuthServiceException(
        weakPasswordMessage,
        code: 'weak-password',
      );
    }
  }

  // --- Internal identifier helpers (never shown to end users) ---

  static String normalizePhone(String raw) {
    return raw.trim().replaceAll(RegExp(r'\D'), '');
  }

  static String normalizeStudentCode(String raw) {
    var code = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    // Normalize unicode dashes to ASCII hyphen, then collapse repeats.
    code = code.replaceAll(RegExp(r'[\u2010-\u2015\u2212﹣－]'), '-');
    code = code.replaceAll(RegExp(r'-+'), '-');
    code = code.replaceAll(RegExp(r'^-+|-+$'), '');
    return code;
  }

  static String normalizeUsername(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  static String teacherInternalEmail(String usernameOrPhone) {
    final phone = normalizePhone(usernameOrPhone);
    // Require a real phone length so usernames like "teacher1" stay usernames.
    if (phone.length >= 8) return '$phone@teacher.edubridge.local';
    final user = normalizeUsername(usernameOrPhone);
    return '$user@teacher.edubridge.local';
  }

  static String guardianInternalEmail(String usernameOrPhone) {
    final phone = normalizePhone(usernameOrPhone);
    if (phone.length >= 8) return '$phone@guardian.edubridge.local';
    final user = normalizeUsername(usernameOrPhone);
    return '$user@guardian.edubridge.local';
  }

  static String studentInternalEmail(String usernameOrCode) {
    final code = normalizeStudentCode(usernameOrCode);
    if (code.isNotEmpty) return '$code@student.edubridge.local';
    final user = normalizeUsername(usernameOrCode);
    return '$user@student.edubridge.local';
  }

  static String adminInternalEmail(String normalizedUsername) {
    final username = normalizeUsername(normalizedUsername);
    return '$username@admin.edubridge.local';
  }

  /// Maps a 4-digit learner PIN to a Firebase Auth password that meets
  /// [meetsAdminTeacherPasswordPolicy] (PIN alone is too short for Firebase).
  static String firebaseSecretFromPin(String pin) {
    final digits = pin.trim();
    return 'EbPin${digits}A9!';
  }

  /// Bootstrap Firebase password for pending student/guardian accounts
  /// (before PIN activation). Deterministic from local account id.
  static String firebaseSecretFromAccountId(String accountId) {
    final bare = accountId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final token = bare.isEmpty ? 'user' : bare;
    return 'EbPend${token}A9!';
  }

  static String messageForAuthCode(String code) {
    switch (code) {
      case 'email-already-in-use':
        return emailInUseMessage;
      case 'weak-password':
        return weakPasswordMessage;
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'INVALID_LOGIN_CREDENTIALS':
        return invalidCredentialMessage;
      case 'network-request-failed':
        return networkMessage;
      case 'too-many-requests':
        return tooManyRequestsMessage;
      default:
        return defaultErrorMessage;
    }
  }

  static void _debugLogAuthError(
    String op,
    FirebaseAuthException e,
    StackTrace st, {
    String? email,
  }) {
    if (!kDebugMode) return;
    // Do not log passwords.
    debugPrint('FirebaseAuthService.$op exception.code=${e.code}');
    debugPrint('FirebaseAuthService.$op exception.message=${e.message}');
    debugPrint('FirebaseAuthService.$op email=${email ?? '(none)'}');
    debugPrint('$st');
  }

  static void _debugLogRaw(String op, Object e, StackTrace st) {
    if (!kDebugMode) return;
    debugPrint('FirebaseAuthService.$op error=$e');
    debugPrint('$st');
  }
}
