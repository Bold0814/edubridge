import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Debug-only Firestore exception logging (no secrets beyond uid/email/path).
void debugLogFirestoreException({
  required Object exception,
  required StackTrace stackTrace,
  required String documentPath,
  String? uid,
  String? email,
}) {
  if (!kDebugMode) return;

  String resolvedUid = uid ?? '(none)';
  String resolvedEmail = email ?? '(none)';
  try {
    final user = FirebaseAuth.instance.currentUser;
    resolvedUid = uid ?? user?.uid ?? '(none)';
    resolvedEmail = email ?? user?.email ?? '(none)';
  } catch (_) {
    // Firebase may be uninitialized in unit tests.
  }

  debugPrint('=== Firestore exception ===');
  debugPrint('fullException=$exception');
  debugPrint('stackTrace=$stackTrace');
  if (exception is FirebaseException) {
    debugPrint('firebaseErrorCode=${exception.code}');
    debugPrint('firebaseMessage=${exception.message}');
  } else {
    debugPrint('firebaseErrorCode=(not FirebaseException)');
    debugPrint('firebaseMessage=(not FirebaseException)');
  }
  debugPrint('currentFirebaseUid=$resolvedUid');
  debugPrint('currentEmail=$resolvedEmail');
  debugPrint('documentPath=$documentPath');
  debugPrint('=== end Firestore exception ===');
}
