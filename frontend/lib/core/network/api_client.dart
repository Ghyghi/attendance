import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

/// Wraps a configured Dio instance for the whole app.
///
/// One ApiClient should be created per app session (see the Riverpod
/// provider in api_client_provider.dart) and reused — don't construct a
/// new Dio per request, that would defeat interceptor-level token caching
/// and the refresh-call coalescing in AuthInterceptor.
class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    required Future<void> Function() onSessionExpired,
  }) : dio = Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: const Duration(seconds: 15),
            // Face verification runs synchronously server-side (no task
            // queue yet, per project notes) — DeepFace inference can take
            // a few seconds, so the submit-attendance call needs a longer
            // receive timeout than everything else. Set generously here;
            // tighten per-request if other endpoints need a shorter one.
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            contentType: 'application/json',
          ),
        ) {
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        tokenStorage: tokenStorage,
        onSessionExpired: onSessionExpired,
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        // Never log the selfie/photo base64 payloads — they're large and
        // sensitive (biometric data). LogInterceptor doesn't support field
        // redaction directly, so request-body logging for this client is
        // a known tradeoff: fine for dev with image_picker test data, but
        // worth revisiting (e.g. a custom request logger that masks
        // 'selfie'/'photo' keys) before this build is shared beyond local dev.
      ),
    );
  }

  final Dio dio;
}