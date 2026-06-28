/// Thrown when the refresh token itself is invalid/expired/blacklisted —
/// i.e. the session cannot be recovered and the user must log in again.
///
/// Distinct from a normal DioException so the UI layer can catch this
/// specifically and force a navigation to the login screen, rather than
/// just showing an inline error.
class SessionExpiredException implements Exception {
  const SessionExpiredException([this.message = 'Session expired. Please log in again.']);
  final String message;

  @override
  String toString() => message;
}