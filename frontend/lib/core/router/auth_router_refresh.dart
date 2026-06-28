import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/auth_controller.dart';

/// Bridges AuthController's Riverpod state to go_router's
/// `refreshListenable`, which expects a plain [Listenable], not a
/// Riverpod provider. Without this, go_router's `redirect` callback only
/// re-runs on navigation events (a route push/pop) — it would NOT
/// automatically re-evaluate when login/logout changes AuthState, so a
/// successful login wouldn't actually navigate anywhere until something
/// else happened to trigger a rebuild.
class AuthRouterRefresh extends ChangeNotifier {
  AuthRouterRefresh(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) {
      notifyListeners();
    });
  }
}

final authRouterRefreshProvider = Provider<AuthRouterRefresh>((ref) {
  return AuthRouterRefresh(ref);
});