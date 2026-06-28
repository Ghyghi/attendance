import 'package:equatable/equatable.dart';
import '../../auth/domain/user.dart';
import 'attendance_status.dart';

/// Mirrors `AttendanceRecordSerializer` (apps/attendance/serializers.py).
///
/// All verification fields (gps_verified, face_verified, code_verified,
/// gps_distance_m, face_distance) are read-only and set server-side by
/// the verification chain in services.py — nothing in this app ever
/// writes them directly.
///
/// `sessionCode` is a read-only SerializerMethodField added to the
/// backend serializer so the student's history screen can display
/// the human-readable session code alongside each record without a
/// separate API call.
///
/// `isTeacherEdited` is True whenever a teacher created or modified this
/// record directly (mark-absent or status override) rather than the
/// student self-submitting via the verification chain. The UI surfaces
/// this as a "Teacher-edited" tag so it's clear which records reflect a
/// student's own GPS/face submission vs a manual teacher correction.
class AttendanceRecord extends Equatable {
  const AttendanceRecord({
    required this.id,
    required this.session,
    required this.sessionCode,
    required this.student,
    required this.studentDetail,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.gpsVerified,
    required this.faceVerified,
    required this.codeVerified,
    required this.gpsDistanceM,
    required this.faceDistance,
    required this.isTeacherEdited,
    required this.markedAt,
    required this.updatedAt,
  });

  final String id;
  final String session;
  final String sessionCode;
  final String student;
  final User studentDetail;
  final AttendanceStatus status;
  final double? latitude;
  final double? longitude;
  final bool gpsVerified;
  final bool faceVerified;
  final bool codeVerified;
  final double? gpsDistanceM;
  final double? faceDistance;
  final bool isTeacherEdited;
  final DateTime markedAt;
  final DateTime updatedAt;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'].toString(),
      session: json['session'] as String,
      sessionCode: json['session_code'] as String? ?? '—',
      student: json['student'] as String,
      studentDetail: User.fromJson(json['student_detail'] as Map<String, dynamic>),
      status: AttendanceStatus.fromApi(json['status'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      gpsVerified: json['gps_verified'] as bool,
      faceVerified: json['face_verified'] as bool,
      codeVerified: json['code_verified'] as bool,
      gpsDistanceM: (json['gps_distance_m'] as num?)?.toDouble(),
      faceDistance: (json['face_distance'] as num?)?.toDouble(),
      isTeacherEdited: json['is_teacher_edited'] as bool? ?? false,
      markedAt: DateTime.parse(json['marked_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    session,
    sessionCode,
    student,
    studentDetail,
    status,
    latitude,
    longitude,
    gpsVerified,
    faceVerified,
    codeVerified,
    gpsDistanceM,
    faceDistance,
    isTeacherEdited,
    markedAt,
    updatedAt,
  ];
}