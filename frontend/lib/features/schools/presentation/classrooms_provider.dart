import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/classroom.dart';
import 'schools_providers.dart';

/// Auto-disposes when no widget is watching it — classroom lists aren't
/// worth keeping warm in memory across the whole app session the way
/// auth state is. Screens that need a refresh call `ref.invalidate(
/// classroomsProvider)` (e.g. after creating a classroom) rather than
/// this provider exposing its own manual refetch method.
final classroomsProvider = FutureProvider.autoDispose<List<Classroom>>((ref) async {
  final repository = ref.watch(schoolsRepositoryProvider);
  return repository.listClassrooms();
});