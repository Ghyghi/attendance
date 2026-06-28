/// Mirrors `User.Role` (apps/users/models.py) — admin / teacher / student.
enum UserRole {
  admin,
  teacher,
  student;

  static UserRole fromApi(String value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'teacher':
        return UserRole.teacher;
      case 'student':
        return UserRole.student;
      default:
        throw ArgumentError('Unknown role from API: $value');
    }
  }

  String toApi() => name;
}