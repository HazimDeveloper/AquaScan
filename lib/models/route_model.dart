import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:water_watch/models/report_model.dart';

class RouteModel {
  final String id;
  final String adminId;
  final List<String> reportIds;
  final List<RoutePoint> points;
  final List<RouteSegment> segments;
  final double totalDistance;
  final DateTime createdAt;
  final DateTime updatedAt;

  RouteModel({
    required this.id,
    required this.adminId,
    required this.reportIds,
    required this.points,
    required this.segments,
    required this.totalDistance,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] as String,
      adminId: json['adminId'] as String,
      reportIds: List<String>.from(json['reportIds'] as List),
      points: (json['points'] as List)
          .map((point) => RoutePoint.fromJson(point as Map<String, dynamic>))
          .toList(),
      segments: (json['segments'] as List)
          .map((segment) => RouteSegment.fromJson(segment as Map<String, dynamic>))
          .toList(),
      totalDistance: json['totalDistance'] as double,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'adminId': adminId,
      'reportIds': reportIds,
      'points': points.map((point) => point.toJson()).toList(),
      'segments': segments.map((segment) => segment.toJson()).toList(),
      'totalDistance': totalDistance,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  copyWith({required String id}) {}
}