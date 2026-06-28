/// Central place for route paths — mirrors ApiConfig's role for API
/// endpoints, so route strings aren't scattered/duplicated across screens.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';

  // Shell tabs — actual path depends on role (see AppShell), but the
  // segment names are shared constants so they're not retyped per role.
  static const String classrooms = '/classrooms';
  static const String sessions = '/sessions';
  static const String submitAttendance = '/submit-attendance';
  static const String enrollFace = '/enroll-face';
  static const String notifications = '/notifications';
}