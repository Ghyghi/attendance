import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/user.dart';
import '../../auth/domain/user_role.dart';
import 'users_providers.dart';

/// All teachers in the admin's school. Used as the data source for the
/// teacher picker in classroom creation. Server already scopes to the
/// admin's own school (IsAdmin + get_queryset school filter).
final teachersProvider = FutureProvider.autoDispose<List<User>>((ref) async {
  return ref.watch(usersRepositoryProvider).listUsers(role: UserRole.teacher);
});

/// All students in the admin's school. Used as the data source for the
/// student picker in roster management. Server already scopes to school.
final studentsProvider = FutureProvider.autoDispose<List<User>>((ref) async {
  return ref.watch(usersRepositoryProvider).listUsers(role: UserRole.student);
});