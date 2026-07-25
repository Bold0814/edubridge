/// Parent / guardian profile (separate from [UserAccount]).
class Guardian {
  const Guardian({
    required this.id,
    required this.fullName,
    required this.schoolId,
    this.phone = '',
    this.email = '',
    this.isActive = true,
  });

  final String id;
  final String fullName;
  final String schoolId;
  final String phone;
  final String email;
  final bool isActive;

  Guardian copyWith({
    String? fullName,
    String? schoolId,
    String? phone,
    String? email,
    bool? isActive,
  }) {
    return Guardian(
      id: id,
      fullName: fullName ?? this.fullName,
      schoolId: schoolId ?? this.schoolId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
    );
  }
}
