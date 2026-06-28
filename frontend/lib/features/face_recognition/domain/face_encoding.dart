import 'package:equatable/equatable.dart';

/// Mirrors `FaceEncodingSerializer` (apps/face_recognition/serializers.py).
///
/// Note this is metadata only — `enrollment_photo` is a URL/path to the
/// stored reference image, not the actual face embedding (the 512-d
/// Facenet vector lives server-side as raw bytes on the model and is
/// never exposed via this serializer).
class FaceEncoding extends Equatable {
  const FaceEncoding({
    required this.id,
    required this.student,
    required this.enrollmentPhoto,
    required this.enrolledAt,
    required this.updatedAt,
  });

  final String id;
  final String student;
  final String? enrollmentPhoto;
  final DateTime enrolledAt;
  final DateTime updatedAt;

  factory FaceEncoding.fromJson(Map<String, dynamic> json) {
    return FaceEncoding(
      id: json['id'].toString(),
      student: json['student'] as String,
      enrollmentPhoto: json['enrollment_photo'] as String?,
      enrolledAt: DateTime.parse(json['enrolled_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, student, enrollmentPhoto, enrolledAt, updatedAt];
}