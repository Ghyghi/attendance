/// Mirrors `Notification.Kind` (apps/notifications/models.py).
enum NotificationKind {
  sessionStarted,
  attendanceMarked,
  sessionExpired,
  addedToModule,
  statusChanged,
  faceEnrolled,
  general;

  static NotificationKind fromApi(String value) {
    switch (value) {
      case 'session_started':
        return NotificationKind.sessionStarted;
      case 'attendance_marked':
        return NotificationKind.attendanceMarked;
      case 'session_expired':
        return NotificationKind.sessionExpired;
      case 'added_to_module':
        return NotificationKind.addedToModule;
      case 'status_changed':
        return NotificationKind.statusChanged;
      case 'face_enrolled':
        return NotificationKind.faceEnrolled;
      case 'general':
        return NotificationKind.general;
      default:
        throw ArgumentError('Unknown notification kind from API: $value');
    }
  }
}