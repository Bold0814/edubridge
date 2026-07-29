import 'firestore_school.dart' show firestoreDate;

/// Cloud Firestore user profile (`users/{uid}`).
class FirestoreUserProfile {
  const FirestoreUserProfile({
    required this.uid,
    required this.displayName,
    required this.internalEmail,
    required this.role,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.schemaVersion = schemaVersionValue,
  });

  static const schemaVersionValue = 1;
  static const collection = 'users';

  final String uid;
  final String displayName;
  final String internalEmail;
  final FirestoreUserRole role;
  final FirestoreUserStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int schemaVersion;

  static void validate({
    required String uid,
    required String displayName,
    required String internalEmail,
    required FirestoreUserRole role,
    required FirestoreUserStatus status,
  }) {
    if (uid.trim().isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'uid must not be empty');
    }
    if (displayName.trim().isEmpty) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'displayName must not be empty',
      );
    }
    if (internalEmail.trim().isEmpty || !internalEmail.contains('@')) {
      throw ArgumentError.value(
        internalEmail,
        'internalEmail',
        'internalEmail must be a valid email-like identifier',
      );
    }
  }

  Map<String, Object?> toCreateMap({
    required Object createdAt,
    required Object updatedAt,
  }) {
    return {
      'uid': uid.trim(),
      'displayName': displayName.trim(),
      'internalEmail': internalEmail.trim().toLowerCase(),
      'role': role.wireValue,
      'status': status.wireValue,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'schemaVersion': schemaVersionValue,
    };
  }

  Map<String, Object?> toUpdateMap({required Object updatedAt}) {
    return {
      'uid': uid.trim(),
      'displayName': displayName.trim(),
      'internalEmail': internalEmail.trim().toLowerCase(),
      'role': role.wireValue,
      'status': status.wireValue,
      'updatedAt': updatedAt,
      'schemaVersion': schemaVersionValue,
    };
  }

  factory FirestoreUserProfile.fromMap(String id, Map<String, dynamic> data) {
    return FirestoreUserProfile(
      uid: (data['uid'] as String? ?? id).trim(),
      displayName: (data['displayName'] as String? ?? '').trim(),
      internalEmail: (data['internalEmail'] as String? ?? '')
          .trim()
          .toLowerCase(),
      role: FirestoreUserRole.parse(data['role'] as String?),
      status: FirestoreUserStatus.parse(data['status'] as String?),
      createdAt: firestoreDate(data['createdAt']),
      updatedAt: firestoreDate(data['updatedAt']),
      schemaVersion:
          (data['schemaVersion'] as num?)?.toInt() ?? schemaVersionValue,
    );
  }
}

enum FirestoreUserRole {
  platformAdmin('platformAdmin'),
  schoolAdmin('schoolAdmin'),
  teacher('teacher'),
  guardian('guardian'),
  student('student');

  const FirestoreUserRole(this.wireValue);
  final String wireValue;

  static FirestoreUserRole parse(String? raw) {
    final value = (raw ?? '').trim();
    for (final role in values) {
      if (role.wireValue == value) return role;
    }
    throw ArgumentError.value(raw, 'role', 'Unsupported user role');
  }
}

enum FirestoreUserStatus {
  pendingActivation('pendingActivation'),
  active('active'),
  disabled('disabled');

  const FirestoreUserStatus(this.wireValue);
  final String wireValue;

  static FirestoreUserStatus parse(String? raw) {
    final value = (raw ?? '').trim();
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    throw ArgumentError.value(raw, 'status', 'Unsupported user status');
  }
}
