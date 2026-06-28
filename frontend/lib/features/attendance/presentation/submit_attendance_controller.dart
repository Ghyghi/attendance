import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../data/attendance_repository.dart';
import '../domain/attendance_submit_exception.dart';
import '../domain/submit_attendance_state.dart';
import 'attendance_providers.dart';

class SubmitAttendanceController extends Notifier<SubmitAttendanceState> {
  late final AttendanceRepository _repository;
  final ImagePicker _picker = ImagePicker();

  @override
  SubmitAttendanceState build() {
    _repository = ref.watch(attendanceRepositoryProvider);
    return const SubmitAttendanceIdle();
  }

  /// Runs the full flow: location permission + fetch -> camera capture ->
  /// base64 encode -> submit. Stops and surfaces a [SubmitAttendanceFailed]
  /// at whichever step fails, using AttendanceFailureStep.gps for a
  /// location/permission problem on THIS device (distinct from the
  /// backend's gps step, which is about geofence distance — both
  /// surface as `step: gps` to the UI since the user-facing meaning,
  /// "something about your location didn't work", is the same).
  Future<void> submit(String code) async {
    state = const SubmitAttendanceSubmitting();

    final position = await _getCurrentPosition();


    if (position == null) {
      state = const SubmitAttendanceFailed(
        step: AttendanceFailureStep.gps,
        message: 'Could not get your location. Make sure location '
            'services and permissions are enabled, then try again.',
      );
      return;
    }

    final selfieBase64 = await _captureSelfieAsBase64();
    if (selfieBase64 == null) {
      // User backed out of the camera screen — not a real error, just
      // return to idle silently rather than showing a failure message
      // for something the user chose to do.
      state = const SubmitAttendanceIdle();
      return;
    }

    try {
      final record = await _repository.submitAttendance(
        code: code,
        latitude: position.latitude,
        longitude: position.longitude,
        selfieBase64: selfieBase64,
      );
      state = SubmitAttendanceSuccess(record);
    } on AttendanceSubmitException catch (e) {
      state = SubmitAttendanceFailed(step: e.step, message: e.message);
    } on AttendanceException catch (e) {
      state = SubmitAttendanceFailed(
        step: AttendanceFailureStep.unknown,
        message: e.message,
      );
    }
  }

  void reset() => state = const SubmitAttendanceIdle();

  /// Returns null if location services are off, permission is denied
  /// (including permanently), or the fetch otherwise fails — caller
  /// treats null as "could not get a GPS fix" without needing to know
  /// which specific geolocator failure mode caused it.
  ///
  /// The whole body is wrapped in try/catch, not just getCurrentPosition —
  /// checkPermission() and requestPermission() can ALSO throw (confirmed:
  /// "No location permissions are defined in the manifest" is thrown by
  /// checkPermission() itself when ACCESS_FINE_LOCATION/ACCESS_COARSE_LOCATION
  /// aren't declared in AndroidManifest.xml). The previous version only
  /// guarded the final getCurrentPosition call, so that exception was
  /// unhandled — and an unhandled exception inside a Notifier method
  /// means `state` never gets set to SubmitAttendanceFailed, leaving the
  /// UI stuck on SubmitAttendanceSubmitting (the spinner) forever. This
  /// is a real native-project setup step, not just a try/catch gap — see
  /// the thrown message below for what's still needed.
  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;


      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      debugPrint('[SubmitAttendanceController] _getCurrentPosition failed: $e');
      return null;
    }
  }

  /// Camera-only source per project decision (no gallery fallback — a
  /// live capture discourages submitting an old/static photo). Returns
  /// null if the user cancels out of the camera screen.
  Future<String?> _captureSelfieAsBase64() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      // Moderate compression — DeepFace doesn't need full sensor
      // resolution, and this keeps the base64 JSON payload reasonable
      // given the ~33% size overhead of base64 encoding noted in the
      // project's media-handling design decision.
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (photo == null) return null;

    final bytes = await File(photo.path).readAsBytes();
    return base64Encode(bytes);
  }
}

final submitAttendanceControllerProvider =
NotifierProvider<SubmitAttendanceController, SubmitAttendanceState>(
  SubmitAttendanceController.new,
);