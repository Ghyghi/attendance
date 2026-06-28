import 'package:equatable/equatable.dart';

/// Mirrors `SchoolSerializer` (apps/schools/serializers.py).
///
/// Creation/edit of School rows is superuser-only (IsAdminUser on
/// SchoolListCreateView/SchoolDetailView) — regular role='admin' users
/// never see create/edit UI for this model, only read it via their own
/// `school` FK. Modeled here regardless since a superuser-facing screen
/// is still in scope for the app.
class School extends Equatable {
  const School({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int radiusM;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'].toString(),
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusM: json['radius_m'] as int,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    latitude,
    longitude,
    radiusM,
    createdBy,
    createdAt,
    updatedAt,
  ];
}