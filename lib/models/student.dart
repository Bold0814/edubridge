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
  });

  final String id;
  final String className;
  final String lastName;
  final String firstName;
  final StudentGender gender;
  final String? register;
  final String? phone;

  String get fullName => '$lastName $firstName';

  Student copyWith({
    String? lastName,
    String? firstName,
    StudentGender? gender,
    String? register,
    String? phone,
    bool clearRegister = false,
    bool clearPhone = false,
  }) {
    return Student(
      id: id,
      className: className,
      lastName: lastName ?? this.lastName,
      firstName: firstName ?? this.firstName,
      gender: gender ?? this.gender,
      register: clearRegister ? null : (register ?? this.register),
      phone: clearPhone ? null : (phone ?? this.phone),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Student && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
