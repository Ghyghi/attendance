import 'package:dio/dio.dart';
import '../../../core/config/api_config.dart';
import '../domain/face_encoding.dart';

class FaceRecognitionException implements Exception {
  const FaceRecognitionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Owns every call to /api/v1/face/. All endpoints here are admin-only
/// (IsAdmin) server-side — a non-admin token gets a 403, surfaced as a
/// FaceRecognitionException like any other failure.
///
/// Important caveat carried over from the project notes: with
/// DEBUG_SKIP_FACE=True, only the MATCHING step at submission time is
/// skipped — enrollment still calls DeepFace.represent() to build the
/// stored embedding, so enroll() needs a real, decodable photo even in
/// dev, not an arbitrary base64 string.
class FaceRecognitionRepository {
  FaceRecognitionRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<FaceEncoding> enroll({
    required String studentId,
    required String photoBase64,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.faceEnroll,
        data: {'student_id': studentId, 'photo': photoBase64},
      );
      return FaceEncoding.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw FaceRecognitionException(_extractErrorMessage(e));
    }
  }

  /// Returns null if the student has no enrolled face (backend's 404
  /// "No face enrolled for this student." is an expected, non-error
  /// outcome here — not every student is enrolled yet) rather than
  /// throwing, so callers can write `if (encoding == null) ...` instead
  /// of try/catching an exception for a routine case.
  Future<FaceEncoding?> getEncodingStatus(String studentId) async {
    try {
      final response = await _dio.get(ApiConfig.faceEncodingDetail(studentId));
      return FaceEncoding.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw FaceRecognitionException(_extractErrorMessage(e));
    }
  }

  /// Returns false (rather than throwing) if there was nothing enrolled
  /// to delete — same reasoning as getEncodingStatus's null case.
  Future<bool> deleteEncoding(String studentId) async {
    try {
      await _dio.delete(ApiConfig.faceEncodingDetail(studentId));
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return false;
      throw FaceRecognitionException(_extractErrorMessage(e));
    }
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