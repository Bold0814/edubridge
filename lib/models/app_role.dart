/// App entry / account role.
enum AppRole {
  admin,
  teacher,
  guardian,
  student;

  String get label {
    switch (this) {
      case AppRole.admin:
        return 'Админ';
      case AppRole.teacher:
        return 'Багш';
      case AppRole.guardian:
        return 'Асран хамгаалагч';
      case AppRole.student:
        return 'Сурагч';
    }
  }

  static AppRole? tryParse(String? raw) {
    switch (raw) {
      case 'admin':
        return AppRole.admin;
      case 'teacher':
        return AppRole.teacher;
      case 'guardian':
        return AppRole.guardian;
      case 'student':
        return AppRole.student;
      default:
        return null;
    }
  }

  String get storageValue => name;
}
