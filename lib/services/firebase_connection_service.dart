import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Outcome of a debug-only Firestore connectivity probe.
class FirebaseConnectionCheckResult {
  const FirebaseConnectionCheckResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

/// Debug-only Firestore connectivity probe (no app data migration).
class FirebaseConnectionService {
  FirebaseConnectionService({
    FirebaseFirestore? firestore,
    bool? forceDebugMode,
    @visibleForTesting FirebaseConnectionBackend? backend,
    Duration? operationTimeout,
  }) : _isDebug = forceDebugMode ?? kDebugMode,
       _backend =
           backend ??
           FirestoreConnectionBackend(firestore ?? FirebaseFirestore.instance),
       _operationTimeout = operationTimeout ?? const Duration(seconds: 5);

  final bool _isDebug;
  final FirebaseConnectionBackend _backend;
  final Duration _operationTimeout;

  /// Exact document path used by the connection check.
  static const documentPath = 'system_checks/flutter_connection';

  static const successMessage = 'Firebase холболт амжилттай.';
  static const failureMessage = 'Firebase холболт амжилтгүй.';
  static const timeoutMessage = 'Firebase хугацаа хэтэрлээ.';
  static const permissionDeniedMessage = 'Firestore Rules зөвшөөрөхгүй байна.';
  static const networkMessage = 'Сүлжээний алдаа.';

  /// Writes, reads, then deletes [documentPath].
  ///
  /// Returns success only when all three steps complete.
  /// In release builds this refuses to touch Firestore.
  /// Always completes (each Firestore call is bounded by [_operationTimeout]).
  Future<FirebaseConnectionCheckResult> runDebugConnectionCheck() async {
    if (!_isDebug) {
      return const FirebaseConnectionCheckResult(
        success: false,
        message: failureMessage,
      );
    }

    try {
      await _awaitTimed(
        label: 'write',
        future: _backend.writeCheck({
          'platform': defaultTargetPlatform.name,
          'checkedAt': FieldValue.serverTimestamp(),
          'appName': 'EduBridge',
        }),
      );

      final exists = await _awaitTimed(
        label: 'read',
        future: _backend.readCheckExists(),
      );
      if (!exists) {
        debugPrint('Firebase connection check: document missing after write');
        return const FirebaseConnectionCheckResult(
          success: false,
          message: failureMessage,
        );
      }

      await _awaitTimed(label: 'delete', future: _backend.deleteCheck());

      return const FirebaseConnectionCheckResult(
        success: true,
        message: successMessage,
      );
    } on TimeoutException catch (e, st) {
      debugPrint('Firebase connection check timeout: $e');
      debugPrint('$st');
      return const FirebaseConnectionCheckResult(
        success: false,
        message: timeoutMessage,
      );
    } on FirebaseException catch (e, st) {
      debugPrint(
        'Firebase connection check FirebaseException '
        'code=${e.code} message=${e.message}',
      );
      debugPrint('$st');
      return FirebaseConnectionCheckResult(
        success: false,
        message: messageForFirebaseCode(e.code),
      );
    } catch (e, st) {
      debugPrint('Firebase connection check error: $e');
      debugPrint('$st');
      if (_looksLikeNetworkError(e)) {
        return const FirebaseConnectionCheckResult(
          success: false,
          message: networkMessage,
        );
      }
      return const FirebaseConnectionCheckResult(
        success: false,
        message: failureMessage,
      );
    }
  }

  Future<T> _awaitTimed<T>({
    required String label,
    required Future<T> future,
  }) async {
    try {
      return await future.timeout(_operationTimeout);
    } on TimeoutException catch (e, st) {
      debugPrint('Firebase connection check $label timed out: $e');
      debugPrint('$st');
      rethrow;
    } on FirebaseException catch (e, st) {
      debugPrint(
        'Firebase connection check $label FirebaseException '
        'code=${e.code} message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    } catch (e, st) {
      debugPrint('Firebase connection check $label error: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Maps every known Firestore / Firebase error code to a Mongolian message.
  @visibleForTesting
  static String messageForFirebaseCode(String code) {
    switch (code) {
      case 'permission-denied':
        return permissionDeniedMessage;
      case 'unavailable':
      case 'network-request-failed':
        return networkMessage;
      case 'deadline-exceeded':
        return timeoutMessage;
      case 'cancelled':
        return 'Холболт цуцлагдлаа.';
      case 'unknown':
        return 'Тодорхойгүй алдаа.';
      case 'invalid-argument':
        return 'Буруу параметр.';
      case 'not-found':
        return 'Баримт олдсонгүй.';
      case 'already-exists':
        return 'Баримт аль хэдийн байна.';
      case 'resource-exhausted':
        return 'Нөөц хэтэрсэн.';
      case 'failed-precondition':
        return 'Нөхцөл хангагдаагүй.';
      case 'aborted':
        return 'Үйлдэл тасалдлаа.';
      case 'out-of-range':
        return 'Хязгаараас хэтэрсэн.';
      case 'unimplemented':
        return 'Дэмжигдээгүй үйлдэл.';
      case 'internal':
        return 'Дотоод алдаа.';
      case 'data-loss':
        return 'Өгөгдөл алдагдсан.';
      case 'unauthenticated':
        return 'Нэвтрээгүй байна.';
      default:
        return failureMessage;
    }
  }

  static bool _looksLikeNetworkError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('network') ||
        text.contains('failed host lookup') ||
        text.contains('connection');
  }
}

/// Narrow write/read/delete surface for tests without a live Firebase.
@visibleForTesting
abstract class FirebaseConnectionBackend {
  Future<void> writeCheck(Map<String, Object?> data);

  Future<bool> readCheckExists();

  Future<void> deleteCheck();
}

class FirestoreConnectionBackend implements FirebaseConnectionBackend {
  FirestoreConnectionBackend(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.doc(FirebaseConnectionService.documentPath);

  @override
  Future<void> writeCheck(Map<String, Object?> data) async {
    try {
      await _doc.set(data);
    } catch (e, st) {
      debugPrint('Firestore writeCheck failed: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  @override
  Future<bool> readCheckExists() async {
    try {
      final snap = await _doc.get(const GetOptions(source: Source.server));
      return snap.exists;
    } catch (e, st) {
      debugPrint('Firestore readCheckExists failed: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  @override
  Future<void> deleteCheck() async {
    try {
      await _doc.delete();
    } catch (e, st) {
      debugPrint('Firestore deleteCheck failed: $e');
      debugPrint('$st');
      rethrow;
    }
  }
}
