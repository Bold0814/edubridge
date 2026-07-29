/// Teacher profile used for homeroom and subject assignment.
class Teacher {
  const Teacher({
    required this.id,
    required this.fullName,
    required this.schoolId,
    this.phone = '',
    this.email = '',
    this.isActive = true,
    this.authUid,
  });

  final String id;
  final String fullName;
  final String schoolId;
  final String phone;
  final String email;
  final bool isActive;

  /// Firebase Auth uid linked to this teacher (canonical cloud identity).
  ///
  /// Never confuse with local [UserAccount.id]. Security rules compare
  /// `request.auth.uid` to this field only — not display name.
  final String? authUid;

  Teacher copyWith({
    String? fullName,
    String? schoolId,
    String? phone,
    String? email,
    bool? isActive,
    String? authUid,
    bool clearAuthUid = false,
  }) {
    return Teacher(
      id: id,
      fullName: fullName ?? this.fullName,
      schoolId: schoolId ?? this.schoolId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      authUid: clearAuthUid ? null : (authUid ?? this.authUid),
    );
  }
}
