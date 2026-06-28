import 'package:equatable/equatable.dart';

/// Mirrors `AttendanceSessionSerializer` (apps/attendance/serializers.py).
///
/// `code`, `expiresAt`, `teacher`, `qrImage`, timestamps are all
/// read-only server-side — a teacher only ever supplies `classroom` when
/// creating a session (see AttendanceRepository.createSession, which
/// uses AttendanceSessionCreateSerializer's single-field shape for the
/// POST body, not this full model).
class AttendanceSession extends Equatable {
  const AttendanceSession({
    required this.id,
    required this.classroom,
    required this.teacher,
    required this.code,
    required this.expiresAt,
    required this.isActive,
    required this.isExpired,
    required this.isValid,
    required this.qrImage,
    required this.presentCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String classroom;
  final String teacher;
  final String code;
  final DateTime expiresAt;
  final bool isActive;
  final bool isExpired;
  final bool isValid;
  final String? qrImage;
  final int presentCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      id: json['id'].toString(),
      classroom: json['classroom'].toString(),
      teacher: json['teacher'] as String,
      code: json['code'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      isActive: json['is_active'] as bool,
      isExpired: json['is_expired'] as bool,
      isValid: json['is_valid'] as bool,
      qrImage: json['qr_image'] as String?,
      presentCount: json['present_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    classroom,
    teacher,
    code,
    expiresAt,
    isActive,
    isExpired,
    isValid,
    qrImage,
    presentCount,
    createdAt,
    updatedAt,
  ];
}