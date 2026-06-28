import 'package:equatable/equatable.dart';
import 'user_role.dart';

/// Mirrors `UserSerializer` (apps/users/serializers.py) — the shape
/// returned by GET /api/v1/auth/me/ and other user-detail endpoints.
///
/// Note: `school` here is the FK id (an int), not a nested object —
/// UserSerializer does not nest SchoolSerializer, it just exposes the
/// raw foreign key. `school` is nullable because the backend model
/// allows null for superusers/platform admins with no school attached.
class User extends Equatable {
  const User({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.school,
    required this.phoneNumber,
    required this.profilePicture,
    required this.createdAt,
    this.attendancePct,
  });

  final String id;
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final UserRole role;
  final String? school;
  final String phoneNumber;
  final String? profilePicture;
  final DateTime createdAt;

  /// Attendance percentage for this student WITHIN A SPECIFIC CLASSROOM —
  /// not a general property of the user. Only present when this User came
  /// from `ClassroomSerializer.students_detail` (apps/schools/serializers.py),
  /// which annotates each student with their attendance_pct for that one
  /// classroom. Null everywhere else (e.g. /auth/me/, /auth/users/, login),
  /// since those endpoints don't have a classroom context to compute it
  /// against. Admins and teachers both see this when viewing a module's
  /// roster; there is no separate admin-only screen for it.
  final double? attendancePct;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? username : name;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      username: json['username'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: UserRole.fromApi(json['role'] as String),
      school: json['school']?.toString(),
      phoneNumber: json['phone_number'] as String? ?? '',
      profilePicture: json['profile_picture'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      attendancePct: (json['attendance_pct'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    username,
    firstName,
    lastName,
    email,
    role,
    school,
    phoneNumber,
    profilePicture,
    createdAt,
    attendancePct,
  ];
}