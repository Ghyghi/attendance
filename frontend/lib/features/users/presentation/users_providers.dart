import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../data/users_repository.dart';

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UsersRepository(dio: apiClient.dio);
});