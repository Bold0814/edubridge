import 'firestore_school.dart' show firestoreDate;

/// Cloud Firestore teacher profile (`teachers/{teacherId}`).
///
/// [authUid] is the canonical Firebase Auth uid link (never display name).
class FirestoreTeacher {
  const FirestoreTeacher({
    required this.id,
    required this.schoolId,
    required this.fullName,
    this.authUid,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.schemaVersion = schemaVersionValue,
  });

  static const schemaVersionValue = 1;
  static const collection = 'teachers';

  /// Canonical Firebase Auth field name used by app + security rules.
  static const authUidField = 'authUid';

  final String id;
  final String schoolId;
  final String fullName;
  final String? authUid;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int schemaVersion;

  static String pathFor(String teacherId) =>
      '$collection/${teacherId.trim()}';

  Map<String, Object?> toCreateMap({
    required Object createdAt,
    required Object updatedAt,
  }) {
    return {
      'id': id.trim(),
      'schoolId': schoolId.trim(),
      'fullName': fullName.trim(),
      if (authUid != null && authUid!.trim().isNotEmpty)
        authUidField: authUid!.trim(),
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'schemaVersion': schemaVersionValue,
    };
  }

  Map<String, Object?> toUpdateMap({required Object updatedAt}) {
    return {
      'id': id.trim(),
      'schoolId': schoolId.trim(),
      'fullName': fullName.trim(),
      if (authUid != null && authUid!.trim().isNotEmpty)
        authUidField: authUid!.trim(),
      'isActive': isActive,
      'updatedAt': updatedAt,
      'schemaVersion': schemaVersionValue,
    };
  }

  factory FirestoreTeacher.fromMap(String id, Map<String, dynamic> data) {
    return FirestoreTeacher(
      id: (data['id'] as String? ?? id).trim(),
      schoolId: (data['schoolId'] as String? ?? '').trim(),
      fullName: (data['fullName'] as String? ?? '').trim(),
      authUid: _optionalString(
        data[authUidField] ?? data['userId'] ?? data['uid'],
      ),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: firestoreDate(data['createdAt']),
      updatedAt: firestoreDate(data['updatedAt']),
      schemaVersion:
          (data['schemaVersion'] as num?)?.toInt() ?? schemaVersionValue,
    );
  }

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
