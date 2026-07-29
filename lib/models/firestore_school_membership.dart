import 'firestore_school.dart' show firestoreDate;

/// Cloud Firestore school membership (`school_memberships/{membershipId}`).
class FirestoreSchoolMembership {
  const FirestoreSchoolMembership({
    required this.id,
    required this.schoolId,
    required this.uid,
    required this.role,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.schemaVersion = schemaVersionValue,
  });

  static const schemaVersionValue = 1;
  static const collection = 'school_memberships';

  final String id;
  final String schoolId;
  final String uid;
  final String role;
  final FirestoreMembershipStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int schemaVersion;

  /// Deterministic document id: `{schoolId}_{uid}`.
  static String membershipId({required String schoolId, required String uid}) {
    final school = schoolId.trim();
    final user = uid.trim();
    if (school.isEmpty) {
      throw ArgumentError.value(schoolId, 'schoolId', 'must not be empty');
    }
    if (user.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'must not be empty');
    }
    return '${school}_$user';
  }

  static void validate({
    required String schoolId,
    required String uid,
    required String role,
    required FirestoreMembershipStatus status,
  }) {
    if (schoolId.trim().isEmpty) {
      throw ArgumentError.value(schoolId, 'schoolId', 'must not be empty');
    }
    if (uid.trim().isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'must not be empty');
    }
    if (role.trim().isEmpty) {
      throw ArgumentError.value(role, 'role', 'must not be empty');
    }
  }

  Map<String, Object?> toCreateMap({
    required Object createdAt,
    required Object updatedAt,
  }) {
    return {
      'schoolId': schoolId.trim(),
      'uid': uid.trim(),
      'role': role.trim(),
      'status': status.wireValue,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'schemaVersion': schemaVersionValue,
    };
  }

  Map<String, Object?> toUpdateMap({required Object updatedAt}) {
    return {
      'schoolId': schoolId.trim(),
      'uid': uid.trim(),
      'role': role.trim(),
      'status': status.wireValue,
      'updatedAt': updatedAt,
      'schemaVersion': schemaVersionValue,
    };
  }

  factory FirestoreSchoolMembership.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FirestoreSchoolMembership(
      id: id,
      schoolId: (data['schoolId'] as String? ?? '').trim(),
      uid: (data['uid'] as String? ?? '').trim(),
      role: (data['role'] as String? ?? '').trim(),
      status: FirestoreMembershipStatus.parse(data['status'] as String?),
      createdAt: firestoreDate(data['createdAt']),
      updatedAt: firestoreDate(data['updatedAt']),
      schemaVersion:
          (data['schemaVersion'] as num?)?.toInt() ?? schemaVersionValue,
    );
  }
}

enum FirestoreMembershipStatus {
  active('active'),
  disabled('disabled');

  const FirestoreMembershipStatus(this.wireValue);
  final String wireValue;

  static FirestoreMembershipStatus parse(String? raw) {
    final value = (raw ?? '').trim();
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    throw ArgumentError.value(raw, 'status', 'Unsupported membership status');
  }
}
