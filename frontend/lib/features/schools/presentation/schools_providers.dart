import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../data/schools_repository.dart';

final schoolsRepositoryProvider = Provider<SchoolsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SchoolsRepository(dio: apiClient.dio);
});