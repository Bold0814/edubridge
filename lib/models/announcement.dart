class Announcement {
  const Announcement({
    required this.id,
    required this.schoolId,
    required this.className,
    required this.title,
    required this.body,
    required this.date,
    required this.isFeatured,
  });

  final String id;
  final String schoolId;
  final String className;
  final String title;
  final String body;
  final String date;
  final bool isFeatured;

  Announcement copyWith({
    String? schoolId,
    String? title,
    String? body,
    String? date,
    bool? isFeatured,
  }) {
    return Announcement(
      id: id,
      schoolId: schoolId ?? this.schoolId,
      className: className,
      title: title ?? this.title,
      body: body ?? this.body,
      date: date ?? this.date,
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }
}
