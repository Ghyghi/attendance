import 'package:dio/dio.dart';
import '../../../core/config/api_config.dart';
import '../domain/classroom.dart';
import '../domain/school.dart';

class SchoolsException implements Exception {
  const SchoolsException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SchoolsRepository {
  SchoolsRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  // --- Schools (superuser only) ---

  Future<List<School>> listSchools() async {
    try {
      final response = await _dio.get(ApiConfig.schools);
      return _parseList(response.data, School.fromJson);
    } on DioException catch (e) {
      throw SchoolsException(_extractErrorMessage(e));
    }
  }

  Future<School> createSchool({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required int radiusM,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.schools,
        data: {
          'name': name,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'radius_m': radiusM,
        },
      );
      return School.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SchoolsException(_extractErrorMessage(e));
    }
  }

  // --- Classrooms / Modules ---

  Future<List<Classroom>> listClassrooms() async {
    try {
      final response = await _dio.get(ApiConfig.classrooms);
      return _parseList(response.data, Classroom.fromJson);
    } on DioException catch (e) {
      throw SchoolsException(_extractErrorMessage(e));
    }
  }

  Future<Classroom> getClassroom(String id) async {
    try {
      final response = await _dio.get(ApiConfig.classroomDetail(id));
      return Classroom.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SchoolsException(_extractErrorMessage(e));
    }
  }

  Future<Classroom> createClassroom({
    required String school,
    required String name,
    int numSessions = 0,
    int minAttendancePct = 75,
    DateTime? beginDate,
    DateTime? endDate,
    SessionTime sessionTime = SessionTime.day,
    List<String> teacherIds = const [],
    List<String> studentIds = const [],
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.classrooms,
        data: Classroom.toMutationJson(
          school: school,
          name: name,
          numSessions: numSessions,
          minAttendancePct: minAttendancePct,
          beginDate: beginDate,
          endDate: endDate,
          sessionTime: sessionTime,
          teacherIds: teacherIds,
          studentIds: studentIds,
        ),
      );
      return Classroom.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SchoolsException(_extractErrorMessage(e));
    }
  }

  Future<Classroom> updateClassroom({
    required String id,
    required String school,
    required String name,
    required int numSessions,
    required int minAttendancePct,
    DateTime? beginDate,
    DateTime? endDate,
    required SessionTime sessionTime,
    required List<String> teacherIds,
    required List<String> studentIds,
  }) async {
    try {
      final response = await _dio.patch(
        ApiConfig.classroomDetail(id),
        data: Classroom.toMutationJson(
          school: school,
          name: name,
          numSessions: numSessions,
          minAttendancePct: minAttendancePct,
          beginDate: beginDate,
          endDate: endDate,
          sessionTime: sessionTime,
          teacherIds: teacherIds,
          studentIds: studentIds,
        ),
      );
      return Classroom.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SchoolsException(_extractErrorMessage(e));
    }
  }

  Future<void> deleteClassroom(String id) async {
    try {
      await _dio.delete(ApiConfig.classroomDetail(id));
    } on DioException catch (e) {
      throw SchoolsException(_extractErrorMessage(e));
    }
  }

  // ── Roster helpers (unchanged logic, updated signatures) ──────────

  Future<Classroom> addTeachersToClassroom(
      String classroomId,
      Set<String> newTeacherIds,
      ) async {
    if (newTeacherIds.isEmpty) return getClassroom(classroomId);
    final classroom = await getClassroom(classroomId);
    final currentIds = classroom.teachers.map((t) => t.id).toSet();
    final merged = {...currentIds, ...newTeacherIds};
    return _patchRoster(classroom, teacherIds: merged.toList());
  }

  Future<Classroom> removeTeacherFromClassroom(
      String classroomId,
      String teacherId,
      ) async {
    final classroom = await getClassroom(classroomId);
    final newIds = classroom.teachers
        .map((t) => t.id)
        .where((id) => id != teacherId)
        .toList();
    return _patchRoster(classroom, teacherIds: newIds);
  }

  Future<Classroom> addStudentsToClassroom(
      String classroomId,
      Set<String> newStudentIds,
      ) async {
    if (newStudentIds.isEmpty) return getClassroom(classroomId);
    final classroom = await getClassroom(classroomId);
    final currentIds = classroom.students.map((s) => s.id).toSet();
    final merged = {...currentIds, ...newStudentIds};
    return _patchRoster(classroom, studentIds: merged.toList());
  }

  Future<Classroom> removeStudentFromClassroom(
      String classroomId,
      String studentId,
      ) async {
    final classroom = await getClassroom(classroomId);
    final newIds = classroom.students
        .map((s) => s.id)
        .where((id) => id != studentId)
        .toList();
    return _patchRoster(classroom, studentIds: newIds);
  }

  /// Shared PATCH helper — preserves all module metadata, only
  /// replaces teacher/student lists as requested.
  Future<Classroom> _patchRoster(
      Classroom classroom, {
        List<String>? teacherIds,
        List<String>? studentIds,
      }) {
    return updateClassroom(
      id: classroom.id,
      school: classroom.school,
      name: classroom.name,
      numSessions: classroom.numSessions,
      minAttendancePct: classroom.minAttendancePct,
      beginDate: classroom.beginDate,
      endDate: classroom.endDate,
      sessionTime: classroom.sessionTime,
      teacherIds: teacherIds ?? classroom.teachers.map((t) => t.id).toList(),
      studentIds: studentIds ?? classroom.students.map((s) => s.id).toList(),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  List<T> _parseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    final List<dynamic> items;
    if (data is Map<String, dynamic> && data.containsKey('results')) {
      items = data['results'] as List<dynamic>;
    } else if (data is List<dynamic>) {
      items = data;
    } else {
      throw const SchoolsException('Unexpected list response shape from server.');
    }
    return items.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      if (data['detail'] is String) return data['detail'] as String;
      for (final value in data.values) {
        if (value is String) return value;
        if (value is List && value.isNotEmpty) return value.first.toString();
      }
    }
    if (e.response?.statusCode == 403) {
      return "You don't have permission to do that.";
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Could not reach the server. Check your connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}