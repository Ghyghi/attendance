import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationsRepository(dio: apiClient.dio);
});

/// All notifications (read + unread) for the current user. Screens that
/// only want unread ones filter client-side via `.where((n) => !n.isRead)`
/// rather than this provider taking a parameter — keeps a single cached
/// list instead of two separate in-flight requests for what's usually
/// the same underlying data.
final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final repository = ref.watch(notificationsRepositoryProvider);
  return repository.list();
});

/// Unread count for the bottom-nav badge.
///
/// Deliberately NOT autoDispose — AppShell watches this the whole time
/// the user is logged in (it's the badge on a nav tab, not something
/// shown only while a specific screen is open), so the provider needs
/// to stay alive across tab switches rather than refetching from zero
/// every time the user navigates away and back.
///
/// Refreshes on a periodic timer (every 30s) while alive, since nothing
/// else in the app currently pushes live updates — this is a deliberate
/// "good enough" middle ground between aggressive polling and a stale
/// badge. Call `ref.invalidate(unreadCountProvider)` anywhere the app
/// already knows a notification-affecting action just happened (e.g.
/// after `markAllRead`, after opening the notifications screen) to get
/// an immediate update instead of waiting for the next tick.
final unreadCountProvider = StreamProvider<int>((ref) async* {
  final repository = ref.watch(notificationsRepositoryProvider);

  Future<int> fetch() async {
    try {
      return await repository.unreadCount();
    } catch (_) {
      // Badge is a non-critical convenience — on a transient network
      // error, fall back to "no badge" rather than surfacing an error
      // state on a bottom-nav icon, which has no good way to display one.
      return 0;
    }
  }

  yield await fetch();

  final timer = Stream.periodic(const Duration(seconds: 30));
  await for (final _ in timer) {
    yield await fetch();
  }
});