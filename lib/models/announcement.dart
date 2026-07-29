class Announcement {
  const Announcement({
    required this.id,
    required this.schoolId,
    required this.className,
    required this.title,
    required this.body,
    required this.date,
    required this.isFeatured,
    this.createdByUid,
    this.createdByTeacherId,
    this.createdAt,
    this.updatedAt,
    this.updatedByUid,
  });

  final String id;
  final String schoolId;
  final String className;
  final String title;
  final String body;
  final String date;
  final bool isFeatured;

  final String? createdByUid;
  final String? createdByTeacherId;
  final String? createdAt;
  final String? updatedAt;
  final String? updatedByUid;

  String get classId => className;

  Announcement copyWith({
    String? schoolId,
    String? title,
    String? body,
    String? date,
    bool? isFeatured,
    String? createdByUid,
    String? createdByTeacherId,
    String? createdAt,
    String? updatedAt,
    String? updatedByUid,
  }) {
    return Announcement(
      id: id,
      schoolId: schoolId ?? this.schoolId,
      className: className,
      title: title ?? this.title,
      body: body ?? this.body,
      date: date ?? this.date,
      isFeatured: isFeatured ?? this.isFeatured,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByTeacherId: createdByTeacherId ?? this.createdByTeacherId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUid: updatedByUid ?? this.updatedByUid,
    );
  }
}
