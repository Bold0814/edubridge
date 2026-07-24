class Announcement {
  const Announcement({
    required this.className,
    required this.title,
    required this.body,
    required this.date,
    required this.isFeatured,
  });

  final String className;
  final String title;
  final String body;
  final String date;
  final bool isFeatured;
}
