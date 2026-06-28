import 'package:dio/dio.dart';
import '../../../core/config/api_config.dart';
import '../../auth/domain/user.dart';
import '../../auth/domain/user_role.dart';

class UsersException implements Exception {
  const UsersException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Owns every call to /api/v1/auth/users/ (admin-only, IsAdmin).
///
/// Both list and create are implicitly scoped to the requesting admin's
/// own school SERVER-SIDE — UserListCreateView.get_queryset() filters by
/// `school=self.request.user.school`, and perform_create() force-sets
/// `school` to the admin's own school regardless of what's sent. This
/// repository deliberately does NOT expose a `school` parameter on
/// either method — there is no way to ask this endpoint for another
/// school's users, by design (per the project's school-isolation rule:
/// the client should never even have the affordance to request data
/// that isn't theirs).
class UsersRepository {
  UsersRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Lists users in the admin's own school, optionally filtered by role.
  /// This is the backing data source for the teacher-picker (classroom
  /// creation) and student-picker (roster management) — both are
  /// thin wrappers over this one call with role='teacher' / 'student'.
  Future<List<User>> listUsers({UserRole? role}) async {
    try {
      final response = await _dio.get(
        ApiConfig.users,
        queryParameters: role != null ? {'role': role.toApi()} : null,
      );
      return _parseList(response.data, User.fromJson);
    } on DioException catch (e) {
      throw UsersException(_extractErrorMessage(e));
    }
  }

  /// Creates a teacher or student account. `school` is intentionally
  /// NOT a parameter here — the backend always assigns the admin's own
  /// school regardless of what's sent (perform_create overrides it), so
  /// sending one would be misleading dead weight on this signature.
  Future<User> createUser({
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required UserRole role,
    required String password,
    String phoneNumber = '',
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.users,
        data: {
          'username': username,
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'role': role.toApi(),
          'phone_number': phoneNumber,
          'password': password,
          'password2': password,
        },
      );
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw UsersException(_extractErrorMessage(e));
    }
  }

  List<T> _parseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    final List<dynamic> items;
    if (data is Map<String, dynamic> && data.containsKey('results')) {
      items = data['results'] as List<dynamic>;
    } else if (data is List<dynamic>) {
      items = data;
    } else {
      throw const UsersException('Unexpected list response shape from server.');
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