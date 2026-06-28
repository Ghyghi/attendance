import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';
import 'auth_router_refresh.dart';

/// Single catch-all route strategy: rather than defining a route per tab
/// (AppRoutes.classrooms, .sessions, etc.) and a separate ShellRoute,
/// every authenticated path renders the same AppShell, which owns its
/// own tab state internally (see app_shell.dart's rationale for that
/// choice). go_router still needs at least one named route to redirect
/// *to*, so AppRoutes.notifications is used as the canonical
/// "authenticated home" target — arbitrary among the per-role tabs,
/// chosen only because every role has a notifications tab.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(authRouterRefreshProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final goingToLogin = state.matchedLocation == AppRoutes.login;

      // Only AuthUninitialized — the one-time startup check — holds off
      // on redirecting, so a stored session gets a chance to resolve to
      // AuthAuthenticated before we'd otherwise bounce to /login.
      // AuthUnauthenticated is a CONFIRMED end state (no token ever
      // existed, the stored one was invalid, or the user just logged
      // out) and must fall through to the redirect logic below — it is
      // NOT another "still checking" state. Treating both the same was
      // the actual bug behind logout appearing to hang: logout sets
      // this confirmed state, but the old code held off redirecting as
      // if a check was still in progress that would never resolve.
      if (authState is AuthUninitialized || authState is AuthLoading) {
        return null;
      }

      final isAuthenticated = authState is AuthAuthenticated;

      if (!isAuthenticated && !goingToLogin) {
        return AppRoutes.login;
      }
      if (isAuthenticated && goingToLogin) {
        return AppRoutes.notifications;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      // All five "shell tab" paths render the same AppShell — the shell
      // reads the current user from AuthState itself rather than this
      // route needing to pass anything through `state.extra`.
      for (final path in [
        AppRoutes.classrooms,
        AppRoutes.sessions,
        AppRoutes.submitAttendance,
        AppRoutes.enrollFace,
        AppRoutes.notifications,
      ])
        GoRoute(
          path: path,
          builder: (context, state) => Consumer(
            builder: (context, ref, _) {
              final authState = ref.watch(authControllerProvider);
              if (authState is AuthAuthenticated) {
                return AppShell(user: authState.user);
              }
              // Mid-redirect transient frame (e.g. right after logout,
              // before `redirect` above has re-routed to /login) — a
              // brief loading frame is preferable to a null-check crash.
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            },
          ),
        ),
    ],
  );
});