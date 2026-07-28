import '../../models/school_data_reset.dart';
import '../../services/password_hasher.dart';
import '../../state/app_store.dart';
import 'school_data_reset_repository.dart';

/// Orchestrates permission checks, confirmation, and repository reset.
///
/// Ready to swap [SchoolDataResetRepository] for a Firebase Cloud Function
/// client without changing UI screens.
class SchoolDataResetService {
  SchoolDataResetService({
    required this.store,
    required this.repository,
    ResetAuditLogger? auditLogger,
  }) : _audit = auditLogger ?? const NoOpResetAuditLogger();

  final AppStore store;
  final SchoolDataResetRepository repository;
  final ResetAuditLogger _audit;

  bool _inProgress = false;
  bool get isInProgress => _inProgress;

  void ensureAdminPermission() {
    if (!store.hasAdminPermissionForActiveSchool) {
      throw const SchoolResetPermissionException();
    }
  }

  String get requireActiveSchoolId {
    final id = store.activeSchoolId;
    if (id == null || id.isEmpty) {
      throw const SchoolResetValidationException('Сургууль сонгогдоогүй.');
    }
    return id;
  }

  Future<ResetPreview> getPreview() async {
    ensureAdminPermission();
    return repository.getPreview(requireActiveSchoolId);
  }

  /// Verifies the signed-in admin password without logging it.
  bool verifyAdminPassword(String password) {
    ensureAdminPermission();
    final user = store.authenticatedUser;
    if (user == null) return false;
    if (password.isEmpty) return false;
    return PasswordHasher.verifyPassword(password, user.passwordHash);
  }

  bool isConfirmationPhraseValid(String input) =>
      input.trim() == kSchoolResetConfirmationPhrase;

  Future<SchoolResetResult> resetOperationalData({
    required SchoolResetScope scope,
    required String confirmationPhrase,
    required String adminPassword,
  }) async {
    ensureAdminPermission();
    if (_inProgress) {
      throw const SchoolResetValidationException(
        'Устгалт аль хэдийн явагдаж байна.',
      );
    }
    if (!scope.hasAnySelection) {
      throw const SchoolResetValidationException('Устгах хэсэг сонгоогүй.');
    }
    if (!isConfirmationPhraseValid(confirmationPhrase)) {
      throw const SchoolResetValidationException(
        'Баталгаажуулах үг буруу байна.',
      );
    }
    if (!verifyAdminPassword(adminPassword)) {
      throw const SchoolResetValidationException('Нууц үг буруу байна.');
    }

    final schoolId = requireActiveSchoolId;
    final admin = store.authenticatedUser!;
    final preserveTeacherId = admin.teacherId ?? store.activeContext.teacherId;

    final requested = ResetAuditEntry(
      actionType: 'reset_operational_data',
      schoolId: schoolId,
      adminUserId: admin.id,
      requestedAt: DateTime.now(),
      scope: scope,
    );
    await _audit.logRequested(requested);

    _inProgress = true;
    try {
      final deleted = await repository.resetOperationalData(
        schoolId: schoolId,
        preserveAdminUserId: admin.id,
        preserveTeacherId: preserveTeacherId,
        scope: scope,
      );

      await store.reloadAfterSchoolDataReset();

      final result = SchoolResetResult(
        schoolId: schoolId,
        adminUserId: admin.id,
        scope: scope,
        deleted: deleted,
        completedAt: DateTime.now(),
      );

      await _audit.logCompleted(
        ResetAuditEntry(
          actionType: 'reset_operational_data',
          schoolId: schoolId,
          adminUserId: admin.id,
          requestedAt: requested.requestedAt,
          scope: scope,
          completedAt: result.completedAt,
          deleted: deleted,
        ),
      );

      return result;
    } finally {
      _inProgress = false;
    }
  }

  Future<void> deleteSchoolCompletely() async {
    ensureAdminPermission();
    throw const SchoolDeleteUnavailableException();
  }
}
