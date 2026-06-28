/// Which step of the verification chain rejected the submission.
/// Mirrors the error dict keys returned by SubmitAttendanceView /
/// process_attendance_submission (apps/attendance/services.py):
/// `{'code': ...}`, `{'gps': ...}`, or `{'face': ...}` — exactly one key
/// is ever present, since the chain short-circuits on the first failure.
enum AttendanceFailureStep { code, gps, face, unknown }

/// Thrown when POST /api/v1/attendance/submit/ returns 400.
///
/// This is intentionally NOT handled by the generic DRF error-message
/// extraction used elsewhere (e.g. AuthRepository._extractErrorMessage) —
/// the submit endpoint's error shape is a single-key dict where the KEY
/// itself is meaningful (which check failed), not just generic
/// field-validation noise. The UI uses [step] to show a different icon/
/// message for "wrong code" vs "too far from school" vs "face didn't
/// match" rather than treating all three as one flat error string.
class AttendanceSubmitException implements Exception {
  const AttendanceSubmitException({
    required this.step,
    required this.message,
  });

  final AttendanceFailureStep step;
  final String message;

  /// Parses the {"code"|"gps"|"face": "..."} shape returned by the
  /// submit endpoint. Falls back to `unknown` for anything else (e.g. a
  /// network error or an unexpected 500) so the UI always has something
  /// to show rather than crashing on a null check.
  factory AttendanceSubmitException.fromResponseBody(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['code'] is String) {
        return AttendanceSubmitException(
          step: AttendanceFailureStep.code,
          message: data['code'] as String,
        );
      }
      if (data['gps'] is String) {
        return AttendanceSubmitException(
          step: AttendanceFailureStep.gps,
          message: data['gps'] as String,
        );
      }
      if (data['face'] is String) {
        return AttendanceSubmitException(
          step: AttendanceFailureStep.face,
          message: data['face'] as String,
        );
      }
    }
    return const AttendanceSubmitException(
      step: AttendanceFailureStep.unknown,
      message: 'Something went wrong submitting your attendance. Please try again.',
    );
  }

  @override
  String toString() => message;
}