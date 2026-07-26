import 'app_role.dart';

/// Persisted announcement open/read event for one user account.
class AnnouncementReadReceipt {
  const AnnouncementReadReceipt({
    required this.id,
    required this.schoolId,
    required this.announcementId,
    required this.userAccountId,
    required this.role,
    this.studentId,
    required this.readAt,
  });

  final String id;
  final String schoolId;
  final String announcementId;
  final String userAccountId;
  final AppRole role;
  final String? studentId;
  final DateTime readAt;
}
