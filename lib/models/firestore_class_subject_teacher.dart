import 'firestore_school.dart' show firestoreDate;

/// Cloud Firestore class+subject teacher assignment
/// (`class_subject_teachers/{schoolId_classId_subjectId}`).
class FirestoreClassSubjectTeacher {
  const FirestoreClassSubjectTeacher({
    required this.id,
    required this.schoolId,
    required this.classId,
    required this.subjectId,
    required this.teacherId,
    this.createdAt,
    this.updatedAt,
    this.schemaVersion = schemaVersionValue,
  });

  static const schemaVersionValue = 1;
  static const collection = 'class_subject_teachers';

  final String id;
  final String schoolId;
  final String classId;
  final int subjectId;
  final String teacherId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int schemaVersion;

  static String documentId({
    required String schoolId,
    required String classId,
    required int subjectId,
  }) {
    return '${schoolId.trim()}_${classId.trim()}_$subjectId';
  }

  static String pathFor({
    required String schoolId,
    required String classId,
    required int subjectId,
  }) {
    return '$collection/${documentId(schoolId: schoolId, classId: classId, subjectId: subjectId)}';
  }

  Map<String, Object?> toCreateMap({
    required Object createdAt,
    required Object updatedAt,
  }) {
    return {
      'id': id,
      'schoolId': schoolId.trim(),
      'classId': classId.trim(),
      'subjectId': subjectId,
      'teacherId': teacherId.trim(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'schemaVersion': schemaVersionValue,
    };
  }

  Map<String, Object?> toUpdateMap({required Object updatedAt}) {
    return {
      'id': id,
      'schoolId': schoolId.trim(),
      'classId': classId.trim(),
      'subjectId': subjectId,
      'teacherId': teacherId.trim(),
      'updatedAt': updatedAt,
      'schemaVersion': schemaVersionValue,
    };
  }

  factory FirestoreClassSubjectTeacher.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final subjectRaw = data['subjectId'] ?? data['subject_id'];
    final subjectId = subjectRaw is int
        ? subjectRaw
        : int.tryParse(subjectRaw?.toString() ?? '') ?? 0;
    return FirestoreClassSubjectTeacher(
      id: (data['id'] as String? ?? id).trim(),
      schoolId: (data['schoolId'] as String? ?? data['school_id'] ?? '')
          .toString()
          .trim(),
      classId: (data['classId'] as String? ?? data['class_id'] ?? '')
          .toString()
          .trim(),
      subjectId: subjectId,
      teacherId: (data['teacherId'] as String? ?? data['teacher_id'] ?? '')
          .toString()
          .trim(),
      createdAt: firestoreDate(data['createdAt']),
      updatedAt: firestoreDate(data['updatedAt']),
      schemaVersion:
          (data['schemaVersion'] as num?)?.toInt() ?? schemaVersionValue,
    );
  }
}
