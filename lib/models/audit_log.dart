/// Immutable audit trail for school data changes.
enum AuditEntityType {
  attendance,
  grade,
  homework,
  announcement,
  advice;

  String get storageValue => name;

  String get labelMn {
    switch (this) {
      case AuditEntityType.attendance:
        return 'Ирц';
      case AuditEntityType.grade:
        return 'Дүн';
      case AuditEntityType.homework:
        return 'Даалгавар';
      case AuditEntityType.announcement:
        return 'Зарлал';
      case AuditEntityType.advice:
        return 'Зөвлөгөө';
    }
  }

  static AuditEntityType fromStorage(String raw) {
    return AuditEntityType.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => AuditEntityType.grade,
    );
  }
}

enum AuditAction {
  create,
  update,
  delete;

  String get storageValue => name;

  String get labelMn {
    switch (this) {
      case AuditAction.create:
        return 'нэмсэн';
      case AuditAction.update:
        return 'өөрчилсөн';
      case AuditAction.delete:
        return 'устгасан';
    }
  }

  static AuditAction fromStorage(String raw) {
    return AuditAction.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => AuditAction.update,
    );
  }
}

/// One immutable audit log row.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.schoolId,
    this.classId,
    this.subjectId,
    this.studentId,
    this.teacherId,
    this.teacherName,
    this.role,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.oldValue,
    this.newValue,
    required this.createdAt,
  });

  final String id;
  final String schoolId;
  final String? classId;
  final int? subjectId;
  final String? studentId;
  final String? teacherId;
  final String? teacherName;
  final String? role;
  final AuditAction action;
  final AuditEntityType entityType;
  final String entityId;
  final String? oldValue;
  final String? newValue;

  /// ISO-8601 timestamp.
  final String createdAt;

  DateTime? get createdAtDate => DateTime.tryParse(createdAt);

  /// e.g. `Дүн өөрчилсөн`
  String get actionTitle => '${entityType.labelMn} ${action.labelMn}';

  /// e.g. `85 → 92` or single-sided create/delete values.
  String? get valueChangeLabel {
    final oldV = oldValue?.trim();
    final newV = newValue?.trim();
    final hasOld = oldV != null && oldV.isNotEmpty;
    final hasNew = newV != null && newV.isNotEmpty;
    if (hasOld && hasNew) return '$oldV → $newV';
    if (hasNew) return newV;
    if (hasOld) return oldV;
    return null;
  }
}
