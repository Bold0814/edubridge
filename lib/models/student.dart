enum StudentGender {
  male,
  female;

  String get label {
    switch (this) {
      case StudentGender.male:
        return 'Эрэгтэй';
      case StudentGender.female:
        return 'Эмэгтэй';
    }
  }
}

class Student {
  const Student({
    required this.id,
    required this.className,
    required this.lastName,
    required this.firstName,
    required this.gender,
    this.register,
    this.phone,
    this.guardian,
  });

  final String id;
  final String className;
  final String lastName;
  final String firstName;
  final StudentGender gender;
  final String? register;
  final String? phone;
  final String? guardian;

  String get fullName => '$lastName $firstName';

  Student copyWith({
    String? lastName,
    String? firstName,
    StudentGender? gender,
    String? register,
    String? phone,
    String? guardian,
    bool clearRegister = false,
    bool clearPhone = false,
    bool clearGuardian = false,
  }) {
    return Student(
      id: id,
      className: className,
      lastName: lastName ?? this.lastName,
      firstName: firstName ?? this.firstName,
      gender: gender ?? this.gender,
      register: clearRegister ? null : (register ?? this.register),
      phone: clearPhone ? null : (phone ?? this.phone),
      guardian: clearGuardian ? null : (guardian ?? this.guardian),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Student && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
