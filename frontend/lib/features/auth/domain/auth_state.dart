import 'package:equatable/equatable.dart';
import 'user.dart';

/// State of the current auth session, driven by AuthController.
///
/// Deliberately a closed sealed hierarchy (not a single class with nullable
/// fields + a status enum) so the UI is forced to handle every case via
/// pattern matching (switch) rather than risking an inconsistent
/// combination, e.g. `status: authenticated` with a null `user`.
sealed class AuthState extends Equatable {
  const AuthState();
}

/// Startup only: app has just launched and AuthController hasn't
/// finished checking secure storage for an existing session yet.
///
/// Distinct from [AuthUnauthenticated] specifically so the router can
/// tell "still checking, don't redirect yet" apart from "confirmed,
/// there is no session, redirect to login now." Collapsing these into
/// one state was the actual cause of logout appearing to hang forever:
/// the router's redirect logic treated the post-logout state the same
/// as the still-restoring-on-boot state and never redirected.
class AuthUninitialized extends AuthState {
  const AuthUninitialized();

  @override
  List<Object?> get props => [];
}

/// Confirmed: no valid session. Reached either because there was never
/// a stored refresh token, the stored one turned out to be invalid, or
/// the user just logged out. The router redirects to /login immediately
/// on seeing this state — unlike AuthUninitialized, there is nothing
/// left to wait for here.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();

  @override
  List<Object?> get props => [];
}

/// A login (or silent token-restore) request is in flight.
class AuthLoading extends AuthState {
  const AuthLoading();

  @override
  List<Object?> get props => [];
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}

/// Login failed, or the session was forcibly ended (e.g. refresh token
/// expired). [message] is meant to be shown directly to the user.
class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}