import 'package:equatable/equatable.dart';
import 'attendance_record.dart';
import 'attendance_submit_exception.dart';

/// State of the student's attendance submission flow.
///
/// Deliberately sealed so the UI must handle every case explicitly —
/// in particular [SubmitAttendanceFailed] carries the [AttendanceFailureStep]
/// so the screen can show a distinct message for "bad code" vs "too far
/// from school" vs "face didn't match", rather than one generic error.
sealed class SubmitAttendanceState extends Equatable {
  const SubmitAttendanceState();
}

class SubmitAttendanceIdle extends SubmitAttendanceState {
  const SubmitAttendanceIdle();

  @override
  List<Object?> get props => [];
}

/// Covers the whole in-flight sequence (getting GPS location, taking the
/// photo via image_picker, then the network call) as a single loading
/// state — the UI doesn't currently need finer-grained sub-states than
/// "working" vs "done", since image_picker's camera UI is itself a
/// separate native screen the user is on during photo capture.
class SubmitAttendanceSubmitting extends SubmitAttendanceState {
  const SubmitAttendanceSubmitting();

  @override
  List<Object?> get props => [];
}

class SubmitAttendanceSuccess extends SubmitAttendanceState {
  const SubmitAttendanceSuccess(this.record);

  final AttendanceRecord record;

  @override
  List<Object?> get props => [record];
}

class SubmitAttendanceFailed extends SubmitAttendanceState {
  const SubmitAttendanceFailed({required this.step, required this.message});

  final AttendanceFailureStep step;
  final String message;

  @override
  List<Object?> get props => [step, message];
}