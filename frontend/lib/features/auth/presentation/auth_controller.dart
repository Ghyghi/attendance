import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';
import 'auth_providers.dart';

class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    // Fire-and-forget: attempt to restore a session from a stored refresh
    // token on app startup. Intentionally not awaited inside build() —
    // build() must return synchronously, so we kick this off and let it
    // update state asynchronously once it resolves.
    debugPrint('[AuthController] build() — kicking off _restoreSession()');
    _restoreSession();
    return const AuthUninitialized();
  }

  Future<void> _restoreSession() async {
    debugPrint('[AuthController] _restoreSession: entered');
    try {
      debugPrint('[AuthController] _restoreSession: calling hasStoredSession...');
      final hasSession = await _repository.hasStoredSession();
      debugPrint('[AuthController] _restoreSession: hasStoredSession returned $hasSession');
      if (!hasSession) {
        state = const AuthUnauthenticated();
        return;
      }

      state = const AuthLoading();
      // If the stored access token is expired, this /me/ call 401s and
      // AuthInterceptor transparently refreshes it before this future
      // resolves — so success here means we have a genuinely valid
      // session, not just "a refresh token exists".
      final user = await _repository.fetchCurrentUser();
      state = AuthAuthenticated(user);
    } on LoginException {
      // Refresh token itself was invalid/expired/blacklisted — back to
      // a clean unauthenticated state, not an error banner, since the
      // user never took an action that failed here.
      state = const AuthUnauthenticated();
    } catch (_) {
      // Belt-and-suspenders: this method is called fire-and-forget from
      // build() (which must return synchronously), so there is no
      // caller able to catch an exception here. Anything unexpected —
      // not just LoginException — must resolve to a concrete state
      // rather than leave the controller (and the AuthGate spinner)
      // stuck forever on a silently-dropped exception.
      state = const AuthUnauthenticated();
    }
  }

  Future<void> login({required String username, required String password}) async {
    state = const AuthLoading();
    try {
      final user = await _repository.login(username: username, password: password);
      state = AuthAuthenticated(user);
    } on LoginException catch (e) {
      state = AuthError(e.message);
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthUnauthenticated();
  }

  /// Called by ApiClient's onSessionExpired callback when AuthInterceptor
  /// determines the refresh token is dead (see core/network/auth_interceptor.dart).
  /// This is the thing that fills the TODO stub left in
  /// core/network/providers.dart during the foundation loop.
  void handleSessionExpired() {
    state = const AuthError('Your session has expired. Please log in again.');
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);