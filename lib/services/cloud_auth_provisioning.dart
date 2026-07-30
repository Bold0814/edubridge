import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/firestore_school_membership.dart';
import '../models/firestore_user_profile.dart';
import 'firebase_auth_service.dart';
import 'firestore_identity_repository.dart';

/// Request to create/link a Firebase Auth user + Firestore identity docs.
class CloudAuthProvisionRequest {
  const CloudAuthProvisionRequest({
    required this.internalEmail,
    required this.password,
    required this.displayName,
    required this.role,
    required this.schoolId,
    this.status = FirestoreUserStatus.active,
    this.teacherId,
  });

  final String internalEmail;
  final String password;
  final String displayName;
  final FirestoreUserRole role;
  final String schoolId;
  final FirestoreUserStatus status;

  /// When set, also writes `teachers/{teacherId}` with authUid (secondary session).
  final String? teacherId;
}

/// Provisions Firebase Authentication + `users` / `school_memberships`.
///
/// Account creation and identity writes run on a **secondary** Firebase App so:
/// 1. The admin/teacher primary session is not replaced.
/// 2. Firestore rules (`request.auth.uid == uid`) are satisfied, because the
///    new user is signed in on the secondary app when their docs are written.
class CloudAuthProvisioning {
  CloudAuthProvisioning({
    FirebaseAuthService? auth,
    FirestoreIdentityRepository? identity,
    this.createAuthUid,
  }) : _auth = auth ?? FirebaseAuthService(),
       _identity =
           identity ??
           FirestoreIdentityRepository(
             store: _firebaseDefaultAppReady
                 ? null
                 : MemoryIdentityDocumentStore(),
           );

  static const secondaryAppName = 'edubridge-user-provision';

  final FirebaseAuthService _auth;
  final FirestoreIdentityRepository _identity;
  final Future<String> Function(CloudAuthProvisionRequest request)?
  createAuthUid;

  /// Ensures Auth + Firestore profile/membership exist; returns Auth uid.
  Future<String> provision(CloudAuthProvisionRequest request) async {
    final email = request.internalEmail.trim().toLowerCase();
    final password = request.password;
    if (email.isEmpty || !email.contains('@')) {
      throw ArgumentError.value(email, 'internalEmail', 'must be email-like');
    }
    if (password.isEmpty) {
      throw ArgumentError('password must not be empty');
    }

    if (createAuthUid != null) {
      final uid = await createAuthUid!(request);
      await _writeIdentityViaRepository(uid: uid, request: request);
      return uid;
    }

    if (!_firebaseDefaultAppReady) {
      final synthetic =
          'syn_${email.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      debugPrint(
        'CloudAuthProvisioning: Firebase unavailable; '
        'using synthetic uid=$synthetic for $email',
      );
      await _writeIdentityViaRepository(uid: synthetic, request: request);
      return synthetic;
    }

    return _provisionWithSecondaryApp(email: email, password: password, request: request);
  }

  /// Signs the primary Auth instance in with [internalEmail]/[password].
  Future<String> signInPrimary({
    required String internalEmail,
    required String password,
  }) async {
    await _auth.signIn(internalEmail: internalEmail, password: password);
    final uid = _auth.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      throw FirebaseAuthServiceException(
        FirebaseAuthService.defaultErrorMessage,
      );
    }
    return uid;
  }

  /// Updates Firebase Auth password on a secondary session (admin-safe).
  Future<void> updatePasswordPreservingSession({
    required String internalEmail,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!_firebaseDefaultAppReady) return;
    final email = internalEmail.trim().toLowerCase();
    final secondary = await _secondaryAuth();
    try {
      final cred = await secondary.signInWithEmailAndPassword(
        email: email,
        password: currentPassword,
      );
      await cred.user?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthServiceException(
        FirebaseAuthService.messageForAuthCode(e.code),
        code: e.code,
      );
    } finally {
      await secondary.signOut();
    }
  }

  Future<String> _provisionWithSecondaryApp({
    required String email,
    required String password,
    required CloudAuthProvisionRequest request,
  }) async {
    final secondary = await _secondaryAuth();
    try {
      UserCredential cred;
      try {
        cred = await secondary.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        debugPrint(
          'CloudAuthProvisioning: created Auth user email=$email '
          'uid=${cred.user?.uid}',
        );
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') {
          throw FirebaseAuthServiceException(
            FirebaseAuthService.messageForAuthCode(e.code),
            code: e.code,
          );
        }
        cred = await secondary.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        debugPrint(
          'CloudAuthProvisioning: resolved existing Auth user email=$email '
          'uid=${cred.user?.uid}',
        );
      }

      final uid = cred.user?.uid.trim();
      if (uid == null || uid.isEmpty) {
        throw FirebaseAuthServiceException(
          FirebaseAuthService.defaultErrorMessage,
        );
      }

      // Identity writes under the new user's auth context (rules require it).
      final db = FirebaseFirestore.instanceFor(app: secondary.app);
      await _writeIdentityDocs(
        db: db,
        uid: uid,
        request: request,
      );
      return uid;
    } finally {
      try {
        await secondary.signOut();
      } catch (_) {}
    }
  }

  Future<void> _writeIdentityDocs({
    required FirebaseFirestore db,
    required String uid,
    required CloudAuthProvisionRequest request,
  }) async {
    final stamp = FieldValue.serverTimestamp();
    final displayName = request.displayName.trim().isEmpty
        ? request.internalEmail
        : request.displayName.trim();
    final profile = FirestoreUserProfile(
      uid: uid,
      displayName: displayName,
      internalEmail: request.internalEmail.trim().toLowerCase(),
      role: request.role,
      status: request.status,
    );
    await db
        .doc(FirestoreIdentityRepository.userPath(uid))
        .set(profile.toCreateMap(createdAt: stamp, updatedAt: stamp), SetOptions(merge: true));

    final membership = FirestoreSchoolMembership(
      id: FirestoreSchoolMembership.membershipId(
        schoolId: request.schoolId,
        uid: uid,
      ),
      schoolId: request.schoolId.trim(),
      uid: uid,
      role: request.role.wireValue,
      status: FirestoreMembershipStatus.active,
    );
    await db
        .doc(
          FirestoreIdentityRepository.membershipPath(
            schoolId: request.schoolId,
            uid: uid,
          ),
        )
        .set(
          membership.toCreateMap(createdAt: stamp, updatedAt: stamp),
          SetOptions(merge: true),
        );

    final teacherId = request.teacherId?.trim();
    if (teacherId != null && teacherId.isNotEmpty) {
      // Rules allow self-link when authUid == request.auth.uid.
      await db.doc('teachers/$teacherId').set({
        'id': teacherId,
        'schoolId': request.schoolId.trim(),
        'fullName': request.displayName.trim(),
        'authUid': uid,
        'isActive': true,
        'createdAt': stamp,
        'updatedAt': stamp,
        'schemaVersion': 1,
      }, SetOptions(merge: true));
      debugPrint('CloudAuthProvisioning: wrote teachers/$teacherId authUid=$uid');
    }

    debugPrint(
      'CloudAuthProvisioning: wrote users/$uid and '
      'school_memberships/${request.schoolId}_$uid',
    );
  }

  Future<void> _writeIdentityViaRepository({
    required String uid,
    required CloudAuthProvisionRequest request,
  }) async {
    try {
      await _identity.createUserProfile(
        uid: uid,
        displayName: request.displayName.trim().isEmpty
            ? request.internalEmail
            : request.displayName.trim(),
        internalEmail: request.internalEmail,
        role: request.role,
        status: request.status,
      );
      await _identity.createMembership(
        schoolId: request.schoolId,
        uid: uid,
        role: request.role.wireValue,
        status: FirestoreMembershipStatus.active,
      );
    } catch (e, st) {
      debugPrint('error: Firestore identity write failed for $uid: $e');
      debugPrint('$st');
      if (!_firebaseDefaultAppReady) return;
      rethrow;
    }
  }

  Future<FirebaseAuth> _secondaryAuth() async {
    FirebaseApp app;
    try {
      app = Firebase.app(secondaryAppName);
    } catch (_) {
      app = await Firebase.initializeApp(
        name: secondaryAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    return FirebaseAuth.instanceFor(app: app);
  }

  static bool get _firebaseDefaultAppReady {
    try {
      Firebase.app();
      return true;
    } catch (_) {
      return false;
    }
  }
}
