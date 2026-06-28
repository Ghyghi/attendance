import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps flutter_secure_storage for the two JWTs.
///
/// Kept deliberately narrow (just access/refresh) rather than a general
/// key-value wrapper — anything else stored here is for the auth interceptor
/// to read/write, not a general app cache.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';

  /// flutter_secure_storage's native read can throw on Android in some
  /// states — most commonly right after a hot restart, where the
  /// Keystore-backed cipher the plugin holds gets out of sync with the
  /// relaunched Dart isolate. Without this guard, that exception
  /// propagates out of a fire-and-forget caller (AuthController's
  /// _restoreSession, called without await from build()) with nowhere
  /// to land — it doesn't crash, it just silently never resolves,
  /// leaving the UI stuck on whatever loading state was last set.
  /// Treating a read failure as "no token" is the safe interpretation
  /// either way: worst case the user has to log in again.
  Future<String?> readAccessToken() async {
    try {
      return await _storage.read(key: _accessKey);
    } catch (_) {
      return null;
    }
  }

  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _refreshKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  /// Called after a refresh response — backend rotates AND blacklists the
  /// old refresh token (ROTATE_REFRESH_TOKENS + BLACKLIST_AFTER_ROTATION
  /// are both True in base.py), so the new refresh token MUST be persisted
  /// here too. Reusing the old refresh token after this point will fail
  /// server-side with a 401, not just the access token.
  Future<void> updateAccessAndRefresh({
    required String access,
    required String refresh,
  }) =>
      saveTokens(access: access, refresh: refresh);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}