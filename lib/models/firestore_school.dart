import 'package:cloud_firestore/cloud_firestore.dart';

/// Cloud Firestore school document (`schools/{schoolId}`).
class FirestoreSchool {
  const FirestoreSchool({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
    required this.createdByUid,
    this.createdAt,
    this.updatedAt,
    this.schemaVersion = schemaVersionValue,
  });

  static const schemaVersionValue = 1;
  static const collection = 'schools';

  final String id;
  final String name;
  final String code;
  final FirestoreSchoolStatus status;
  final String createdByUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int schemaVersion;

  static String normalizeCode(String raw) {
    return raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  static void validate({
    required String name,
    required String code,
    required String createdByUid,
    required FirestoreSchoolStatus status,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'School name must not be empty');
    }
    if (normalizeCode(code).isEmpty) {
      throw ArgumentError.value(code, 'code', 'School code must not be empty');
    }
    if (createdByUid.trim().isEmpty) {
      throw ArgumentError.value(
        createdByUid,
        'createdByUid',
        'createdByUid must not be empty',
      );
    }
  }

  Map<String, Object?> toCreateMap({
    required Object createdAt,
    required Object updatedAt,
  }) {
    return {
      'name': name.trim(),
      'code': normalizeCode(code),
      'status': status.wireValue,
      'createdByUid': createdByUid.trim(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'schemaVersion': schemaVersionValue,
    };
  }

  Map<String, Object?> toUpdateMap({required Object updatedAt}) {
    return {
      'name': name.trim(),
      'code': normalizeCode(code),
      'status': status.wireValue,
      'createdByUid': createdByUid.trim(),
      'updatedAt': updatedAt,
      'schemaVersion': schemaVersionValue,
    };
  }

  factory FirestoreSchool.fromMap(String id, Map<String, dynamic> data) {
    return FirestoreSchool(
      id: id,
      name: (data['name'] as String? ?? '').trim(),
      code: normalizeCode(data['code'] as String? ?? ''),
      status: FirestoreSchoolStatus.parse(data['status'] as String?),
      createdByUid: (data['createdByUid'] as String? ?? '').trim(),
      createdAt: firestoreDate(data['createdAt']),
      updatedAt: firestoreDate(data['updatedAt']),
      schemaVersion:
          (data['schemaVersion'] as num?)?.toInt() ?? schemaVersionValue,
    );
  }
}

enum FirestoreSchoolStatus {
  pending('pending'),
  active('active'),
  suspended('suspended');

  const FirestoreSchoolStatus(this.wireValue);
  final String wireValue;

  static FirestoreSchoolStatus parse(String? raw) {
    final value = (raw ?? '').trim();
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    throw ArgumentError.value(raw, 'status', 'Unsupported school status');
  }
}

DateTime? firestoreDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return null;
}
