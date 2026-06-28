import 'package:dio/dio.dart';
import '../../../core/config/api_config.dart';
import '../domain/app_notification.dart';

class NotificationsException implements Exception {
  const NotificationsException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Owns every call to /api/v1/notifications/. Available to any
/// authenticated user (IsAuthenticated) — notifications are always
/// scoped server-side to request.user, never cross-user.
class NotificationsRepository {
  NotificationsRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// [unreadOnly] maps to the `?unread=` query param NotificationListView
  /// checks for truthiness on (any non-empty value filters to unread —
  /// see views.py's `if unread_only:`), so passing true sends `unread=1`.
  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    try {
      final response = await _dio.get(
        ApiConfig.notifications,
        queryParameters: unreadOnly ? {'unread': '1'} : null,
      );
      return _parseList(response.data, AppNotification.fromJson);
    } on DioException catch (e) {
      throw NotificationsException(_extractErrorMessage(e));
    }
  }

  Future<AppNotification> markRead(String id) async {
    try {
      final response = await _dio.patch(ApiConfig.notificationRead(id));
      return AppNotification.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NotificationsException(_extractErrorMessage(e));
    }
  }

  /// Returns the count of notifications that were marked read, per
  /// MarkAllReadView's {"marked_read": count} response.
  Future<int> markAllRead() async {
    try {
      final response = await _dio.post(ApiConfig.notificationReadAll);
      return response.data['marked_read'] as int;
    } on DioException catch (e) {
      throw NotificationsException(_extractErrorMessage(e));
    }
  }

  /// Lightweight unread count for the bottom-nav badge — hits a
  /// dedicated endpoint (UnreadCountView) rather than fetching the full
  /// list and counting client-side, since this gets polled/refreshed
  /// far more often than the full notifications screen is opened.
  Future<int> unreadCount() async {
    try {
      final response = await _dio.get(ApiConfig.notificationUnreadCount);
      return response.data['unread_count'] as int;
    } on DioException catch (e) {
      throw NotificationsException(_extractErrorMessage(e));
    }
  }

  List<T> _parseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    final List<dynamic> items;
    if (data is Map<String, dynamic> && data.containsKey('results')) {
      items = data['results'] as List<dynamic>;
    } else if (data is List<dynamic>) {
      items = data;
    } else {
      throw const NotificationsException('Unexpected list response shape from server.');
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
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Could not reach the server. Check your connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}