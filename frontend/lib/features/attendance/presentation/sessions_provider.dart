import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/attendance_session.dart';
import 'attendance_providers.dart';

final sessionsProvider = FutureProvider.autoDispose<List<AttendanceSession>>((ref) async {
  final repository = ref.watch(attendanceRepositoryProvider);
  return repository.listSessions();
});