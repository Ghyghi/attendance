import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/attendance_submit_exception.dart';
import '../domain/submit_attendance_state.dart';
import 'submit_attendance_controller.dart';

/// Student: enter the session code, then the controller handles GPS +
/// camera capture + submission. Basic UI proving the flow end to end —
/// not final design.
class SubmitAttendanceScreen extends ConsumerStatefulWidget {
  const SubmitAttendanceScreen({super.key});

  @override
  ConsumerState<SubmitAttendanceScreen> createState() =>
      _SubmitAttendanceScreenState();
}

class _SubmitAttendanceScreenState extends ConsumerState<SubmitAttendanceScreen> {
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // build() only re-runs when submitAttendanceControllerProvider changes
    // (via ref.watch below) — a TextField's own typing doesn't trigger a
    // Riverpod rebuild on its own. Without this listener, the submit
    // button's `_codeController.text.trim().isEmpty` check in build()
    // was evaluated once and never re-evaluated as the user typed, which
    // is why the button stayed disabled regardless of input.
    _codeController.addListener(_onCodeChanged);
  }

  void _onCodeChanged() => setState(() {});

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submitAttendanceControllerProvider);
    final isSubmitting = state is SubmitAttendanceSubmitting;

    ref.listen<SubmitAttendanceState>(submitAttendanceControllerProvider,
            (previous, next) {
          if (next is SubmitAttendanceSuccess) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                content: Text('Attendance marked present.'),
                backgroundColor: Colors.green,
              ));
            _codeController.clear();
          } else if (next is SubmitAttendanceFailed) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(_describeFailure(next)),
                backgroundColor: Theme.of(context).colorScheme.error,
              ));
          }
        });

    return Scaffold(
      appBar: AppBar(title: const Text('Submit Attendance')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter the code your teacher shared, then take a quick selfie to confirm your attendance.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeController,
                  enabled: !isSubmitting,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 4),
                  decoration: const InputDecoration(
                    labelText: 'Session code',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: isSubmitting || _codeController.text.trim().isEmpty
                      ? null
                      : () => ref
                      .read(submitAttendanceControllerProvider.notifier)
                      .submit(_codeController.text.trim()),
                  icon: isSubmitting
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.camera_alt_outlined),
                  label: Text(isSubmitting ? 'Verifying...' : 'Take selfie & submit'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _describeFailure(SubmitAttendanceFailed failure) {
    final prefix = switch (failure.step) {
      AttendanceFailureStep.code => 'Code: ',
      AttendanceFailureStep.gps => 'Location: ',
      AttendanceFailureStep.face => 'Face check: ',
      AttendanceFailureStep.unknown => '',
    };
    return '$prefix${failure.message}';
  }
}