import 'package:equatable/equatable.dart';
import 'notification_kind.dart';

/// Mirrors `NotificationSerializer` (apps/notifications/serializers.py).
///
/// Named AppNotification, not Notification — Flutter's widgets library
/// already defines a `Notification` class (the widget-tree bubbling
/// event system, e.g. ScrollNotification), and shadowing it would force
/// an import alias everywhere this model is used alongside any Flutter
/// widget code.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.isRead,
    required this.session,
    required this.createdAt,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final bool isRead;
  final String? session;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      kind: NotificationKind.fromApi(json['kind'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['is_read'] as bool,
      session: json['session'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      session: session,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, kind, title, body, isRead, session, createdAt];
}