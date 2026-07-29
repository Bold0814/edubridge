import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../debug/firestore_debug_log.dart';
import '../models/firestore_school.dart';
import '../models/firestore_school_membership.dart';
import '../models/firestore_user_profile.dart';

/// Narrow document store so identity writes can be unit-tested without live Firebase.
@visibleForTesting
abstract class IdentityDocumentStore {
  Future<Map<String, dynamic>?> get(String path);

  Future<void> set(
    String path,
    Map<String, Object?> data, {
    bool merge = false,
  });
}

class FirestoreIdentityDocumentStore implements IdentityDocumentStore {
  FirestoreIdentityDocumentStore([FirebaseFirestore? firestore])
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<Map<String, dynamic>?> get(String path) async {
    final snap = await _db.doc(path).get();
    if (!snap.exists || snap.data() == null) return null;
    return Map<String, dynamic>.from(snap.data()!);
  }

  @override
  Future<void> set(
    String path,
    Map<String, Object?> data, {
    bool merge = false,
  }) async {
    await _db
        .doc(path)
        .set(Map<String, dynamic>.from(data), SetOptions(merge: merge));
  }
}

/// In-memory store for idempotency / serialization tests.
@visibleForTesting
class MemoryIdentityDocumentStore implements IdentityDocumentStore {
  final Map<String, Map<String, dynamic>> documents = {};
  int setCount = 0;

  @override
  Future<Map<String, dynamic>?> get(String path) async {
    final data = documents[path];
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<void> set(
    String path,
    Map<String, Object?> data, {
    bool merge = false,
  }) async {
    setCount++;
    final incoming = Map<String, dynamic>.from(data);
    // Resolve fake server timestamps for tests.
    for (final entry in incoming.entries.toList()) {
      if (entry.value is FieldValue) {
        incoming[entry.key] = DateTime.fromMillisecondsSinceEpoch(setCount);
      }
    }
    if (merge && documents.containsKey(path)) {
      documents[path] = {...documents[path]!, ...incoming};
    } else {
      documents[path] = incoming;
    }
  }
}

/// Safe Firestore identity foundation (schools / users / memberships).
///
/// Does not touch SQLite or replace local login.
class FirestoreIdentityRepository {
  FirestoreIdentityRepository({
    FirebaseFirestore? firestore,
    IdentityDocumentStore? store,
    Object Function()? serverTimestamp,
  }) : _firestore = firestore,
       _store = store ?? FirestoreIdentityDocumentStore(firestore),
       _serverTimestamp =
           serverTimestamp ?? (() => FieldValue.serverTimestamp());

  final FirebaseFirestore? _firestore;
  final IdentityDocumentStore _store;
  final Object Function() _serverTimestamp;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  static String schoolPath(String schoolId) =>
      '${FirestoreSchool.collection}/${schoolId.trim()}';

  static String userPath(String uid) =>
      '${FirestoreUserProfile.collection}/${uid.trim()}';

  static String membershipPath({
    required String schoolId,
    required String uid,
  }) {
    final id = FirestoreSchoolMembership.membershipId(
      schoolId: schoolId,
      uid: uid,
    );
    return '${FirestoreSchoolMembership.collection}/$id';
  }

  Future<void> createSchool({
    required String schoolId,
    required String name,
    required String code,
    required FirestoreSchoolStatus status,
    required String createdByUid,
  }) async {
    final id = schoolId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(schoolId, 'schoolId', 'must not be empty');
    }
    FirestoreSchool.validate(
      name: name,
      code: code,
      createdByUid: createdByUid,
      status: status,
    );

    final school = FirestoreSchool(
      id: id,
      name: name,
      code: code,
      status: status,
      createdByUid: createdByUid,
    );
    final path = schoolPath(id);
    final existing = await _store.get(path);
    final stamp = _serverTimestamp();
    if (existing == null) {
      await _store.set(
        path,
        school.toCreateMap(createdAt: stamp, updatedAt: stamp),
      );
    } else {
      await _store.set(path, school.toUpdateMap(updatedAt: stamp), merge: true);
    }
  }

  Future<void> createUserProfile({
    required String uid,
    required String displayName,
    required String internalEmail,
    required FirestoreUserRole role,
    required FirestoreUserStatus status,
  }) async {
    FirestoreUserProfile.validate(
      uid: uid,
      displayName: displayName,
      internalEmail: internalEmail,
      role: role,
      status: status,
    );

    final profile = FirestoreUserProfile(
      uid: uid,
      displayName: displayName,
      internalEmail: internalEmail,
      role: role,
      status: status,
    );
    final path = userPath(uid);
    final existing = await _store.get(path);
    final stamp = _serverTimestamp();
    if (existing == null) {
      await _store.set(
        path,
        profile.toCreateMap(createdAt: stamp, updatedAt: stamp),
      );
    } else {
      await _store.set(
        path,
        profile.toUpdateMap(updatedAt: stamp),
        merge: true,
      );
    }
  }

  Future<void> createMembership({
    required String schoolId,
    required String uid,
    required String role,
    required FirestoreMembershipStatus status,
  }) async {
    FirestoreSchoolMembership.validate(
      schoolId: schoolId,
      uid: uid,
      role: role,
      status: status,
    );
    // Reject unsupported role wire values (same vocabulary as user profiles).
    FirestoreUserRole.parse(role);

    final membership = FirestoreSchoolMembership(
      id: FirestoreSchoolMembership.membershipId(schoolId: schoolId, uid: uid),
      schoolId: schoolId,
      uid: uid,
      role: role,
      status: status,
    );
    final path = membershipPath(schoolId: schoolId, uid: uid);
    final existing = await _store.get(path);
    final stamp = _serverTimestamp();
    if (existing == null) {
      await _store.set(
        path,
        membership.toCreateMap(createdAt: stamp, updatedAt: stamp),
      );
    } else {
      await _store.set(
        path,
        membership.toUpdateMap(updatedAt: stamp),
        merge: true,
      );
    }
  }

  Future<FirestoreSchool?> getSchool(String schoolId) async {
    final data = await _store.get(schoolPath(schoolId));
    if (data == null) return null;
    return FirestoreSchool.fromMap(schoolId.trim(), data);
  }

  Future<FirestoreUserProfile?> getUserProfile(String uid) async {
    final data = await _store.get(userPath(uid));
    if (data == null) return null;
    return FirestoreUserProfile.fromMap(uid.trim(), data);
  }

  Future<FirestoreSchoolMembership?> getMembership({
    required String schoolId,
    required String uid,
  }) async {
    final id = FirestoreSchoolMembership.membershipId(
      schoolId: schoolId,
      uid: uid,
    );
    final data = await _store.get(membershipPath(schoolId: schoolId, uid: uid));
    if (data == null) return null;
    return FirestoreSchoolMembership.fromMap(id, data);
  }

  /// Active memberships for a Firebase uid (used after Auth login).
  Future<List<FirestoreSchoolMembership>> listMembershipsForUid(
    String uid,
  ) async {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) return const [];

    final store = _store;
    if (store is MemoryIdentityDocumentStore) {
      final prefix = '${FirestoreSchoolMembership.collection}/';
      return [
            for (final entry in store.documents.entries)
              if (entry.key.startsWith(prefix))
                FirestoreSchoolMembership.fromMap(
                  entry.key.substring(prefix.length),
                  entry.value,
                ),
          ]
          .where((m) {
            return m.uid == trimmed &&
                m.status == FirestoreMembershipStatus.active;
          })
          .toList(growable: false);
    }

    final snap = await _db
        .collection(FirestoreSchoolMembership.collection)
        .where('uid', isEqualTo: trimmed)
        .get();
    return [
          for (final doc in snap.docs)
            FirestoreSchoolMembership.fromMap(doc.id, doc.data()),
        ]
        .where((m) => m.status == FirestoreMembershipStatus.active)
        .toList(growable: false);
  }
}

/// Debug-only foundation probe: school + user profile + membership.
class FirestoreIdentityDebugSetup {
  FirestoreIdentityDebugSetup({
    FirestoreIdentityRepository? repository,
    bool? forceDebugMode,
  }) : _repository = repository ?? FirestoreIdentityRepository(),
       _isDebug = forceDebugMode ?? kDebugMode;

  final FirestoreIdentityRepository _repository;
  final bool _isDebug;

  static const debugSchoolId = 'TEST001';
  static const debugSchoolName = 'EduBridge Туршилтын сургууль';
  static const debugSchoolCode = 'TEST001';

  static const successMessage = 'Firestore бүтэц амжилттай үүслээ.';
  static const failureMessage = 'Firestore бүтэц үүсгэж чадсангүй.';
  static const notSignedInMessage = 'Эхлээд Firebase-д нэвтэрнэ үү.';
  static const releaseBlockedMessage = 'Зөвхөн debug горимд ашиглана.';

  static bool isDebugActionEnabled({bool? forceDebugMode}) =>
      forceDebugMode ?? kDebugMode;

  Future<FirestoreIdentityDebugResult> run({
    required String uid,
    required String displayName,
    required String internalEmail,
  }) async {
    if (!_isDebug) {
      return const FirestoreIdentityDebugResult(
        success: false,
        message: releaseBlockedMessage,
      );
    }
    if (uid.trim().isEmpty) {
      return const FirestoreIdentityDebugResult(
        success: false,
        message: notSignedInMessage,
      );
    }

    final schoolPath = FirestoreIdentityRepository.schoolPath(debugSchoolId);
    await _guarded(schoolPath, uid, internalEmail, () {
      return _repository.createSchool(
        schoolId: debugSchoolId,
        name: debugSchoolName,
        code: debugSchoolCode,
        status: FirestoreSchoolStatus.active,
        createdByUid: uid,
      );
    });

    final userDocPath = FirestoreIdentityRepository.userPath(uid);
    await _guarded(userDocPath, uid, internalEmail, () {
      return _repository.createUserProfile(
        uid: uid,
        displayName: displayName.trim().isEmpty ? 'Debug Admin' : displayName,
        internalEmail: internalEmail.trim().isEmpty
            ? '${uid.trim()}@debug.edubridge.local'
            : internalEmail,
        role: FirestoreUserRole.schoolAdmin,
        status: FirestoreUserStatus.active,
      );
    });

    final membershipDocPath = FirestoreIdentityRepository.membershipPath(
      schoolId: debugSchoolId,
      uid: uid,
    );
    await _guarded(membershipDocPath, uid, internalEmail, () {
      return _repository.createMembership(
        schoolId: debugSchoolId,
        uid: uid,
        role: FirestoreUserRole.schoolAdmin.wireValue,
        status: FirestoreMembershipStatus.active,
      );
    });

    final school = await _guarded(schoolPath, uid, internalEmail, () {
      return _repository.getSchool(debugSchoolId);
    });
    final profile = await _guarded(userDocPath, uid, internalEmail, () {
      return _repository.getUserProfile(uid);
    });
    final membership = await _guarded(
      membershipDocPath,
      uid,
      internalEmail,
      () {
        return _repository.getMembership(schoolId: debugSchoolId, uid: uid);
      },
    );

    if (school == null || profile == null || membership == null) {
      return const FirestoreIdentityDebugResult(
        success: false,
        message: failureMessage,
      );
    }

    return const FirestoreIdentityDebugResult(
      success: true,
      message: successMessage,
    );
  }

  Future<T> _guarded<T>(
    String documentPath,
    String uid,
    String email,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } catch (e, st) {
      debugLogFirestoreException(
        exception: e,
        stackTrace: st,
        documentPath: documentPath,
        uid: uid,
        email: email,
      );
      rethrow;
    }
  }
}

class FirestoreIdentityDebugResult {
  const FirestoreIdentityDebugResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}
