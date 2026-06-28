import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/attendance_record.dart';
import '../domain/attendance_session.dart';
import 'attendance_providers.dart';

/// Bundles the session and its records into one family provider so the
/// detail screen only needs one async watch — both arrive together.
class SessionDetail {
  const SessionDetail({required this.session, required this.records});
  final AttendanceSession session;
  final List<AttendanceRecord> records;
}

final sessionDetailProvider =
FutureProvider.autoDispose.family<SessionDetail, String>(
      (ref, sessionId) async {
    final repo = ref.watch(attendanceRepositoryProvider);
    final session = await repo.getSession(sessionId);
    final records = await repo.getSessionRecords(sessionId);
    return SessionDetail(session: session, records: records);
  },
);