import 'package:dio/dio.dart';
import '../../../core/config/api_config.dart';
import '../../auth/domain/user.dart';
import '../domain/attendance_record.dart';
import '../domain/attendance_session.dart';
import '../domain/attendance_submit_exception.dart';
import '../domain/module_stats.dart';

class AttendanceException implements Exception {
  const AttendanceException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AttendanceRepository {
  AttendanceRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  // ── Teacher: sessions ──────────────────────────────────────────────

  Future<List<AttendanceSession>> listSessions() async {
    try {
      final response = await _dio.get(ApiConfig.sessions);
      return _parseList(response.data, AttendanceSession.fromJson);
    } on DioException catch (e) {
      throw AttendanceException(_extractErrorMessage(e));
    }
  }

  Future<AttendanceSession> createSession({required String classroomId}) async {
    try {
      final response = await _dio.post(
        ApiConfig.sessions,
        data: {'classroom': classroomId},
      );
      return AttendanceSession.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AttendanceException(_extractErrorMessage(e));
    }
  }

  Future<AttendanceSession> getSession(String id) async {
    try {
      final response = await _dio.get(ApiConfig.sessionDetail(id));
      return AttendanceSession.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AttendanceException(_extractErrorMessage(e));
    }
  }

  Future<AttendanceSession> closeSession(String id) async {
    try {
      final response = await _dio.patch(
        ApiConfig.sessionDetail(id),
        data: {'is_active': false},
      );
      return AttendanceSession.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AttendanceException(_extractErrorMessage(e));
    }
  }

  Future<List<AttendanceRecord>> getSessionRecords(String sessionId) async {
    try {
      final response = await _dio.get(ApiConfig.sessionRecords(sessionId));
      return _parseList(response.data, AttendanceRecord.fromJson);
    } on DioException catch (e) {
      throw AttendanceException(_extractErrorMessage(e));
    }
  }

  // ── Teacher: absent student management ────────────────────────────

  /// Returns students enrolled in the session's module who have NOT
  /// yet submitted any attendance record.
  Future<List<User>> getAbsentStudents(String sessionId) async {
    try {
      final response = await _dio.get(ApiConfig.sessionAbsentStudents(sessionId));
      final List<dynamic> items = response.data is List
          ? response.data as List
          : (response.data['results'] as List? ?? []);
      return items
          .map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AttendanceException(_extractErrorMessage(e));
    }
  }

  /// Creates ABSENT records for the given student IDs.
  /// Only creates records for students who don't already have one.
  Future<List<AttendanceRecord>> markAbsent({
    required String sessionId,
    required List<String> studentIds,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.sessionMarkAbsent(sessionId),
        data: {'student_ids': studentIds.map(int.parse).toList()},
      );
      final List<dynamic> items = response.data is List
          ? response.data as List
          : (response.data['results'] as List? ?? []);
      return items
          .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AttendanceException(_extractErrorMessage(e));
    }
  }

  /// Override a single record's status (e.g. absent → present).
  Future<AttendanceRecord> overrideRecordStatus({
    required String recordId,
    required String status, // 'present' | 'absent' | 'late'
  }) async {
    try {
      final response = await _dio.patch(
        ApiConfig.recordOverride(recordId),
        data: {'status': status},
      );
      return AttendanceRecord.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AttendanceException(_extractErrorMessage(e));
    }
  }

  // ── Student: submit + history + module stats ───────────────────────

  Future<AttendanceRecord> submitAttendance({
    required String code,
    required double latitude,
    required double longitude,
    required String selfieBase64,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.submitAttendance,
        data: {
          'code': code,
          'latitude': latitude,
          'longitude': longitude,
          'selfie': selfieBase64,
        },
      );
      return AttendanceRecord.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw AttendanceSubmitException.fromResponseBody(e.response?.data);
      }
      throw AttendanceException(_extractErrorMessage(e));
    }
  }

  Future<List<AttendanceRecord>> getHistory() async {
    try {
      final response = await _dio.get(ApiConfig.attendanceHistory);
      return _parseList(response.data, AttendanceRecord.fromJson);
    } on DioException catch (e) {
      throw AttendanceException(_extractErrorMessage(e));
    }
  }

  /// Returns attendance stats grouped by module for the current student.
  Future<List<ModuleStats>> getModuleStats() async {
    try {
      final response = await _dio.get(ApiConfig.moduleStats);
      final List<dynamic> items = response.data is List
          ? response.data as List
          : (response.data['results'] as List? ?? []);
      return items
          .map((e) => ModuleStats.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AttendanceException(_extractErrorMessage(e));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  List<T> _parseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    final List<dynamic> items;
    if (data is Map<String, dynamic> && data.containsKey('results')) {
      items = data['results'] as List<dynamic>;
    } else if (data is List<dynamic>) {
      items = data;
    } else {
      throw const AttendanceException('Unexpected list response shape from server.');
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
    if (e.type == DioExceptionType.receiveTimeout) {
      return 'The server is taking longer than expected. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}