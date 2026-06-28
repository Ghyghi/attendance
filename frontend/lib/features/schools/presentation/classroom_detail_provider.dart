import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/classroom.dart';
import 'schools_providers.dart';

/// Single classroom detail, keyed by classroom ID.
/// Uses .family since the ID is dynamic (whichever classroom was tapped).
/// autoDispose so stale detail data doesn't linger in memory when
/// navigating away — the list screen's own provider handles fresh data
/// on return.
final classroomDetailProvider =
FutureProvider.autoDispose.family<Classroom, String>((ref, classroomId) async {
  final repository = ref.watch(schoolsRepositoryProvider);
  return repository.getClassroom(classroomId);
});