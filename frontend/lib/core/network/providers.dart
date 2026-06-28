import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/token_storage.dart';
import 'api_client.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

/// Hook for "what happens when a refresh fails irrecoverably" (the
/// refresh token itself is expired/blacklisted — see AuthInterceptor).
///
/// Defaults to a no-op so core/network/ has no import dependency on
/// features/auth/ — core/ must stay the layer every feature depends ON,
/// never the reverse, or features importing core/ and core/ importing
/// features/auth/ creates a circular import.
///
/// The auth feature overrides this provider in the ProviderScope at the
/// app root (see main.dart) to point it at AuthController.handleSessionExpired,
/// so a 401-that-can't-be-refreshed actually flips AuthState to AuthError
/// instead of silently doing nothing.
final sessionExpiredHandlerProvider = Provider<Future<void> Function()>((ref) {
  return () async {};
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final onSessionExpired = ref.watch(sessionExpiredHandlerProvider);
  return ApiClient(
    tokenStorage: tokenStorage,
    onSessionExpired: onSessionExpired,
  );
});