import 'account_status.dart';
import 'app_role.dart';

/// Local user account (prototype auth — production will use a secure backend).
class UserAccount {
  const UserAccount({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    this.teacherId,
    this.guardianId,
    this.studentId,
    this.isActive = true,
    this.status = AccountStatus.active,
    required this.createdAt,
    this.failedPinAttempts = 0,
    this.pinLockedUntil,
    this.requirePasswordChange = false,
  });

  final String id;
  final String username;

  /// Format: `saltHex:hashHex` — empty while [status] is pendingActivation.
  /// Never display this value in UI.
  final String passwordHash;
  final AppRole role;
  final String? teacherId;
  final String? guardianId;
  final String? studentId;
  final bool isActive;
  final AccountStatus status;
  final DateTime createdAt;
  final int failedPinAttempts;
  final DateTime? pinLockedUntil;

  /// Temporary password must be replaced after first successful login.
  final bool requirePasswordChange;

  bool get isPendingActivation => status == AccountStatus.pendingActivation;

  bool get canAuthenticateWithPin =>
      isActive && status == AccountStatus.active && passwordHash.isNotEmpty;

  String? get linkedEntityId {
    switch (role) {
      case AppRole.admin:
        return teacherId;
      case AppRole.teacher:
        return teacherId;
      case AppRole.guardian:
        return guardianId;
      case AppRole.student:
        return studentId;
    }
  }

  UserAccount copyWith({
    String? username,
    String? passwordHash,
    AppRole? role,
    String? teacherId,
    String? guardianId,
    String? studentId,
    bool? isActive,
    AccountStatus? status,
    int? failedPinAttempts,
    DateTime? pinLockedUntil,
    bool? requirePasswordChange,
    bool clearTeacherId = false,
    bool clearGuardianId = false,
    bool clearStudentId = false,
    bool clearPinLockedUntil = false,
  }) {
    return UserAccount(
      id: id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      teacherId: clearTeacherId ? null : (teacherId ?? this.teacherId),
      guardianId: clearGuardianId ? null : (guardianId ?? this.guardianId),
      studentId: clearStudentId ? null : (studentId ?? this.studentId),
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      createdAt: createdAt,
      failedPinAttempts: failedPinAttempts ?? this.failedPinAttempts,
      pinLockedUntil: clearPinLockedUntil
          ? null
          : (pinLockedUntil ?? this.pinLockedUntil),
      requirePasswordChange:
          requirePasswordChange ?? this.requirePasswordChange,
    );
  }
}
