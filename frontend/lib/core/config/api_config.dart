/// Central place for API base URL and endpoint paths.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String apiPrefix = '/api/v1';

  // --- Auth ---
  static const String login = '$apiPrefix/auth/login/';
  static const String tokenRefresh = '$apiPrefix/auth/token/refresh/';
  static const String logout = '$apiPrefix/auth/logout/';
  static const String me = '$apiPrefix/auth/me/';
  static const String changePassword = '$apiPrefix/auth/me/password/';
  static const String users = '$apiPrefix/auth/users/';
  static String userDetail(String id) => '$apiPrefix/auth/users/$id/';
  static const String superuserUsers = '$apiPrefix/auth/superuser/users/';

  // --- Schools / Modules ---
  static const String schools = '$apiPrefix/schools/';
  static String schoolDetail(String id) => '$apiPrefix/schools/$id/';
  static const String classrooms = '$apiPrefix/schools/classrooms/';
  static String classroomDetail(String id) => '$apiPrefix/schools/classrooms/$id/';

  // --- Attendance ---
  static const String sessions = '$apiPrefix/attendance/sessions/';
  static String sessionDetail(String id) => '$apiPrefix/attendance/sessions/$id/';
  static String sessionRecords(String sessionId) =>
      '$apiPrefix/attendance/sessions/$sessionId/records/';

  // Teacher absent-student helpers
  static String sessionAbsentStudents(String sessionId) =>
      '$apiPrefix/attendance/sessions/$sessionId/absent-students/';
  static String sessionMarkAbsent(String sessionId) =>
      '$apiPrefix/attendance/sessions/$sessionId/mark-absent/';

  // Teacher record override
  static String recordOverride(String recordId) =>
      '$apiPrefix/attendance/records/$recordId/override/';

  static const String submitAttendance = '$apiPrefix/attendance/submit/';
  static const String attendanceHistory = '$apiPrefix/attendance/history/';

  // Student module stats (grouped by module with attendance %)
  static const String moduleStats = '$apiPrefix/attendance/module-stats/';

  // --- Face recognition ---
  static const String faceEnroll = '$apiPrefix/face/enroll/';
  static String faceEncodingDetail(String studentId) =>
      '$apiPrefix/face/student/$studentId/';

  // --- Notifications ---
  static const String notifications = '$apiPrefix/notifications/';
  static String notificationRead(String id) => '$apiPrefix/notifications/$id/read/';
  static const String notificationReadAll = '$apiPrefix/notifications/read-all/';
  static const String notificationUnreadCount = '$apiPrefix/notifications/unread-count/';
}