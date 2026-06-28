import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/network/providers.dart';
import 'core/router/app_router.dart';
import 'features/auth/presentation/auth_controller.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        // Connects core/network's session-expired hook to the auth
        // feature without core/ ever importing features/auth/ — this is
        // the one place that's allowed to know about both layers.
        sessionExpiredHandlerProvider.overrideWith((ref) {
          return () async {
            ref.read(authControllerProvider.notifier).handleSessionExpired();
          };
        }),
      ],
      child: const TrackerApp(),
    ),
  );
}

class TrackerApp extends ConsumerWidget {
  const TrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      routerConfig: router,
    );
  }
}