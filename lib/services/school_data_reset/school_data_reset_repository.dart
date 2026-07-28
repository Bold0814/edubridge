import '../../models/school_data_reset.dart';

/// Persistence boundary for school data reset.
///
/// **SQLite (current):** [SqliteSchoolDataResetRepository] runs a single
/// transactional, school-scoped wipe on the local database.
///
/// **Firebase (future):** implement `FirebaseSchoolDataResetRepository` that
/// calls a **protected Cloud Function** (Admin SDK). Do **not** give clients
/// Security Rules permission to recursively delete an entire school tree, and
/// do **not** perform broad client-side Firestore recursive deletion.
abstract class SchoolDataResetRepository {
  Future<ResetPreview> getPreview(String schoolId);

  /// Deletes operational data for [schoolId] in one transaction.
  ///
  /// Preserves the school row and the primary admin account/membership
  /// identified by [preserveAdminUserId] (and optional [preserveTeacherId]).
  Future<ResetDeletedCounts> resetOperationalData({
    required String schoolId,
    required String preserveAdminUserId,
    String? preserveTeacherId,
    required SchoolResetScope scope,
  });

  /// Full school wipe — must be server-authorized in production.
  Future<void> deleteSchoolCompletely({
    required String schoolId,
    required String preserveAdminUserId,
  });
}

/// Optional audit sink (no credentials). Default is no-op.
abstract class ResetAuditLogger {
  Future<void> logRequested(ResetAuditEntry entry);
  Future<void> logCompleted(ResetAuditEntry entry);
}

class NoOpResetAuditLogger implements ResetAuditLogger {
  const NoOpResetAuditLogger();

  @override
  Future<void> logRequested(ResetAuditEntry entry) async {}

  @override
  Future<void> logCompleted(ResetAuditEntry entry) async {}
}

/// In-memory audit for tests / local diagnostics (never stores passwords).
class InMemoryResetAuditLogger implements ResetAuditLogger {
  final List<ResetAuditEntry> entries = [];

  @override
  Future<void> logRequested(ResetAuditEntry entry) async {
    entries.add(entry);
  }

  @override
  Future<void> logCompleted(ResetAuditEntry entry) async {
    entries.add(entry);
  }
}
