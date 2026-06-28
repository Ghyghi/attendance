import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/providers.dart';
import '../data/face_recognition_repository.dart';

final faceRecognitionRepositoryProvider = Provider<FaceRecognitionRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FaceRecognitionRepository(dio: apiClient.dio);
});