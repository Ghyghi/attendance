import 'package:dio/dio.dart';
import '../../../core/config/api_config.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';

/// Thrown for login-specific failures (bad credentials, network error,
/// unexpected response shape) — kept distinct from DioException so the
/// presentation layer doesn't need to know about Dio at all.
class LoginException implements Exception {
  const LoginException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Owns every call to the auth endpoints (login, logout, /me) and is the
/// only place in the app that talks to TokenStorage directly for writes
/// triggered by a user-initiated action. AuthInterceptor also reads/writes
/// TokenStorage, but only for the silent refresh-on-401 path.
class AuthRepository {
  AuthRepository({
    required Dio dio,
    required TokenStorage tokenStorage,
  })  : _dio = dio,
        _tokenStorage = tokenStorage;

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Logs in and persists both tokens on success.
  /// Returns the freshly-fetched [User] (via a follow-up call to /me/,
  /// since the login response itself only carries role/full_name/school_id,
  /// not the full user record — per CustomTokenObtainPairSerializer).
  Future<User> login({required String username, required String password}) async {
    try {
      final response = await _dio.post(
        ApiConfig.login,
        data: {'username': username, 'password': password},
      );

      final access = response.data['access'] as String?;
      final refresh = response.data['refresh'] as String?;
      if (access == null || refresh == null) {
        throw const LoginException('Unexpected login response from server.');
      }

      await _tokenStorage.saveTokens(access: access, refresh: refresh);

      // Login response is flat — {access, refresh, role, full_name,
      // school_id} — it does not include id/email/phone_number/etc, so
      // fetch the full profile separately rather than constructing a
      // partial User from the login payload.
      return await fetchCurrentUser();
    } on DioException catch (e) {
      throw LoginException(_extractErrorMessage(e));
    }
  }

  Future<User> fetchCurrentUser() async {
    try {
      final response = await _dio.get(ApiConfig.me);
      return User.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw LoginException(_extractErrorMessage(e));
    }
  }

  /// Calls the backend logout (blacklists the refresh token server-side)
  /// then clears local storage regardless of whether the API call
  /// succeeds — a failed logout call (e.g. no network) should never leave
  /// stale tokens sitting in secure storage.
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _dio.post(ApiConfig.logout, data: {'refresh': refreshToken});
      } on DioException {
        // Intentionally swallowed — see method doc. Local token clearing
        // below is what actually matters for the app's auth state.
      }
    }
    await _tokenStorage.clear();
  }

  /// True if a refresh token is present in secure storage. Used on app
  /// startup to decide between attempting a silent session restore vs.
  /// going straight to the login screen — does NOT validate the token
  /// against the server (that happens naturally on the first /me/ call,
  /// via AuthInterceptor's refresh-on-401 if the access token is stale).
  /// Calls POST /api/v1/auth/me/password/ with the old and new passwords.
  /// Throws [LoginException] (reusing the same exception type) on failure
  /// so callers have one error type to handle for all auth operations.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        ApiConfig.changePassword,
        data: {'old_password': oldPassword, 'new_password': newPassword},
      );
    } on DioException catch (e) {
      throw LoginException(_extractErrorMessage(e));
    }
  }

  Future<bool> hasStoredSession() async {
    final refresh = await _tokenStorage.readRefreshToken();
    return refresh != null;
  }

  /// DRF error bodies aren't uniform across this backend (some views
  /// return {"detail": "..."}, others return field-keyed validation
  /// errors). This tries the common shapes and falls back to a generic
  /// message rather than surfacing a raw exception string to the user.
  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      if (data['detail'] is String) return data['detail'] as String;
      // simplejwt's TokenObtainPairView returns {"detail": "No active
      // account found with the given credentials"} on bad login, which
      // the check above already covers. Fallback: take the first
      // field-keyed error message if present.
      for (final value in data.values) {
        if (value is String) return value;
        if (value is List && value.isNotEmpty) return value.first.toString();
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Could not reach the server. Check your connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}