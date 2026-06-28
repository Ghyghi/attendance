import 'package:equatable/equatable.dart';
import 'attendance_record.dart';

/// Mirrors `StudentModuleStatsSerializer` from the backend.
/// One entry per enrolled module, carrying the full record list plus
/// computed attendance percentages.
class ModuleStats extends Equatable {
  const ModuleStats({
    required this.classroomId,
    required this.classroomName,
    required this.totalSessions,
    required this.presentCount,
    required this.absentCount,
    required this.attendancePct,
    required this.minAttendancePct,
    required this.isBelowMinimum,
    required this.records,
  });

  final String classroomId;
  final String classroomName;
  final int totalSessions;
  final int presentCount;
  final int absentCount;
  final double attendancePct;
  final int minAttendancePct;
  final bool isBelowMinimum;
  final List<AttendanceRecord> records;

  factory ModuleStats.fromJson(Map<String, dynamic> json) {
    return ModuleStats(
      classroomId: json['classroom_id'].toString(),
      classroomName: json['classroom_name'] as String,
      totalSessions: json['total_sessions'] as int,
      presentCount: json['present_count'] as int,
      absentCount: json['absent_count'] as int,
      attendancePct: (json['attendance_pct'] as num).toDouble(),
      minAttendancePct: json['min_attendance_pct'] as int,
      isBelowMinimum: json['is_below_minimum'] as bool,
      records: (json['records'] as List<dynamic>)
          .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
    classroomId,
    classroomName,
    totalSessions,
    presentCount,
    absentCount,
    attendancePct,
    minAttendancePct,
    isBelowMinimum,
    records,
  ];
}