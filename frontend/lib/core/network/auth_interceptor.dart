import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../errors/session_expired_exception.dart';
import '../storage/token_storage.dart';

/// Attaches the access token to outgoing requests and transparently
/// refreshes on a 401 response.
///
/// Concurrency note: if several requests are in flight and all hit a 401
/// at once (e.g. a screen that fires 3 API calls on load, right as the
/// access token expires), only the FIRST one triggers a refresh call.
/// The others wait on that same in-flight refresh and retry once it
/// resolves, rather than each independently calling /token/refresh/ and
/// racing each other to rotate the refresh token (which would cause the
/// losers of that race to get blacklisted-token errors).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required TokenStorage tokenStorage,
    required Future<void> Function() onSessionExpired,
  })  : _dio = dio,
        _tokenStorage = tokenStorage,
        _onSessionExpired = onSessionExpired;

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final Future<void> Function() _onSessionExpired;

  /// Null when no refresh is in flight. While non-null, other requests
  /// that hit a 401 await this same future instead of starting their own.
  Future<String?>? _refreshFuture;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Login and refresh calls must not carry a (possibly stale/expired)
    // access token — avoids any chance of this interceptor's 401 handling
    // recursing into itself on the refresh call.
    final isAuthEndpoint = options.path == ApiConfig.login ||
        options.path == ApiConfig.tokenRefresh;

    if (!isAuthEndpoint) {
      final token = await _tokenStorage.readAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final requestPath = err.requestOptions.path;

    final isUnauthorized = response?.statusCode == 401;
    final isAuthEndpoint =
        requestPath == ApiConfig.login || requestPath == ApiConfig.tokenRefresh;

    // Don't try to refresh on a 401 that already came from the refresh
    // endpoint itself — that means the refresh token is dead.
    if (!isUnauthorized || isAuthEndpoint) {
      handler.next(err);
      return;
    }

    // Avoid retrying the same request twice (e.g. if the retried request
    // also somehow comes back 401).
    if (err.requestOptions.extra['retried'] == true) {
      await _forceLogout(handler, err);
      return;
    }

    try {
      final newAccessToken = await _refreshAccessToken();
      if (newAccessToken == null) {
        await _forceLogout(handler, err);
        return;
      }

      // Retry the original request with the new token.
      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      retryOptions.extra['retried'] = true;

      final retryResponse = await _dio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } on SessionExpiredException {
      await _forceLogout(handler, err);
    }
  }

  /// Returns the new access token, or null if refresh failed for a reason
  /// other than an expired session (caller treats null like a hard failure).
  /// Coalesces concurrent callers onto a single in-flight refresh.
  Future<String?> _refreshAccessToken() {
    _refreshFuture ??= _doRefresh().whenComplete(() {
      _refreshFuture = null;
    });
    return _refreshFuture!;
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) {
      throw const SessionExpiredException('No refresh token stored.');
    }

    try {
      // Plain Dio instance (not the intercepted one) — avoids this very
      // interceptor seeing the refresh call's own response.
      final plainDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      final response = await plainDio.post(
        ApiConfig.tokenRefresh,
        data: {'refresh': refreshToken},
      );

      final newAccess = response.data['access'] as String?;
      // ROTATE_REFRESH_TOKENS=True means a new refresh token comes back
      // too, and BLACKLIST_AFTER_ROTATION=True means the old one is now
      // dead — both must be persisted or the next refresh attempt fails.
      final newRefresh = response.data['refresh'] as String?;

      if (newAccess == null || newRefresh == null) {
        throw const SessionExpiredException(
          'Refresh response missing expected tokens.',
        );
      }

      await _tokenStorage.updateAccessAndRefresh(
        access: newAccess,
        refresh: newRefresh,
      );
      return newAccess;
    } on DioException catch (e) {
      // 401 here means the refresh token itself is expired/blacklisted —
      // not recoverable, the user must log in again.
      if (e.response?.statusCode == 401) {
        throw const SessionExpiredException();
      }
      rethrow;
    }
  }

  Future<void> _forceLogout(
    ErrorInterceptorHandler handler,
    DioException originalError,
  ) async {
    await _tokenStorage.clear();
    await _onSessionExpired();
    handler.reject(
      DioException(
        requestOptions: originalError.requestOptions,
        error: const SessionExpiredException(),
        type: DioExceptionType.badResponse,
        response: originalError.response,
      ),
    );
  }
}