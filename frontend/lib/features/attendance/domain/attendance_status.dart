/// Mirrors `AttendanceRecord.Status` (apps/attendance/models.py).
///
/// In practice the backend's verification chain (services.py) only ever
/// creates records with status=PRESENT — a failed GPS/face check returns
/// a 400 error instead of creating an absent/late record. ABSENT and LATE
/// exist on the model for potential future use (e.g. a teacher manually
/// marking a student absent) but the app should not assume they appear
/// from the submit flow today.
enum AttendanceStatus {
  present,
  absent,
  late;

  static AttendanceStatus fromApi(String value) {
    switch (value) {
      case 'present':
        return AttendanceStatus.present;
      case 'absent':
        return AttendanceStatus.absent;
      case 'late':
        return AttendanceStatus.late;
      default:
        throw ArgumentError('Unknown attendance status from API: $value');
    }
  }

  String toApi() => name;
}