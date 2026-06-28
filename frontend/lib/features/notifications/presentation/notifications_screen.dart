import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/app_notification.dart';
import 'notifications_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all read',
            onPressed: () async {
              try {
                await ref.read(notificationsRepositoryProvider).markAllRead();
                ref.invalidate(notificationsProvider);
                // Also refresh the nav badge immediately — otherwise it
                // would keep showing the old count until the next tab
                // switch or the 30s periodic tick catches up.
                ref.invalidate(unreadCountProvider);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _NotificationTile(notification: notifications[index]),
            ),
          );
        },
      ),
    );
  }
}

/// Plain text notification row — no per-kind icon and no implied
/// hyperlink styling, per project decision. The only visual states are:
/// unread (bold title + faint highlight + small dot) vs read (plain).
/// Tapping an unread row still marks it read — that's a basic list
/// interaction, not navigation, so it's kept as-is.
class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  /// Plain absolute date + time, same format used everywhere else in the
  /// app (session_detail_screen, attendance_histroy_screen, etc.) — no
  /// relative-time ("5m ago") helper exists in this codebase, so this
  /// stays consistent with the established convention rather than
  /// introducing a new one for just this screen.
  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      tileColor: notification.isRead
          ? null
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body),
          const SizedBox(height: 2),
          Text(
            _formatTimestamp(notification.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: notification.isRead
          ? null
          : const Icon(Icons.circle, size: 10, color: Colors.blue),
      onTap: notification.isRead
          ? null
          : () async {
        try {
          await ref.read(notificationsRepositoryProvider).markRead(notification.id);
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadCountProvider);
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      },
    );
  }
}