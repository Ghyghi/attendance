import 'package:equatable/equatable.dart';
import '../../auth/domain/user.dart';

/// Session time options — mirrors Classroom.SessionTime on the backend.
enum SessionTime {
  day,
  evening,
  night;

  static SessionTime fromApi(String value) {
    switch (value) {
      case 'day':
        return SessionTime.day;
      case 'evening':
        return SessionTime.evening;
      case 'night':
        return SessionTime.night;
      default:
        return SessionTime.day;
    }
  }

  String toApi() => name;

  String get label {
    switch (this) {
      case SessionTime.day:
        return 'Day';
      case SessionTime.evening:
        return 'Evening';
      case SessionTime.night:
        return 'Night';
    }
  }
}

/// Mirrors `ClassroomSerializer` (apps/schools/serializers.py).
/// The UI refers to this entity as a "Module" — the backend model is
/// still called Classroom to avoid a costly rename migration.
///
/// New Module fields: numSessions, minAttendancePct, beginDate, endDate,
/// sessionTime. The `subject` field has been removed per the new spec.
class Classroom extends Equatable {
  const Classroom({
    required this.id,
    required this.school,
    required this.name,
    required this.numSessions,
    required this.minAttendancePct,
    required this.beginDate,
    required this.endDate,
    required this.sessionTime,
    required this.teachers,
    required this.students,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String school;
  final String name;
  final int numSessions;
  final int minAttendancePct;
  final DateTime? beginDate;
  final DateTime? endDate;
  final SessionTime sessionTime;
  final List<User> teachers;
  final List<User> students;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Classroom.fromJson(Map<String, dynamic> json) {
    return Classroom(
      id: json['id'].toString(),
      school: json['school'].toString(),
      name: json['name'] as String,
      numSessions: (json['num_sessions'] as int?) ?? 0,
      minAttendancePct: (json['min_attendance_pct'] as int?) ?? 75,
      beginDate: json['begin_date'] != null
          ? DateTime.parse(json['begin_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      sessionTime: SessionTime.fromApi(
          (json['session_time'] as String?) ?? 'day'),
      teachers: (json['teachers_detail'] as List<dynamic>? ?? [])
          .map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList(),
      students: (json['students_detail'] as List<dynamic>? ?? [])
          .map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Body for POST/PATCH — write-only fields use raw id lists.
  static Map<String, dynamic> toMutationJson({
    required String school,
    required String name,
    required int numSessions,
    required int minAttendancePct,
    DateTime? beginDate,
    DateTime? endDate,
    required SessionTime sessionTime,
    required List<String> teacherIds,
    required List<String> studentIds,
  }) {
    return {
      'school': school,
      'name': name,
      'num_sessions': numSessions,
      'min_attendance_pct': minAttendancePct,
      if (beginDate != null)
        'begin_date':
        '${beginDate.year}-${beginDate.month.toString().padLeft(2, '0')}-${beginDate.day.toString().padLeft(2, '0')}',
      if (endDate != null)
        'end_date':
        '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
      'session_time': sessionTime.toApi(),
      'teachers': teacherIds,
      'students': studentIds,
    };
  }

  @override
  List<Object?> get props => [
    id,
    school,
    name,
    numSessions,
    minAttendancePct,
    beginDate,
    endDate,
    sessionTime,
    teachers,
    students,
    createdAt,
    updatedAt,
  ];
}