// lib/models/report_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum WaterQualityState {
  clean,
  slightlyContaminated,
  moderatelyContaminated,
  heavilyContaminated,
  unknown
}

class GeoPoint {
  final double latitude;
  final double longitude;

  GeoPoint({
    required this.latitude,
    required this.longitude,
  });

  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    return GeoPoint(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class ReportModel {
  final String id;
  final String userId;
  final String userName;
  final String title;
  final String description;
  final GeoPoint location;
  final String address;
  final List<String> imageUrls;
  final WaterQualityState waterQuality;
  final bool isResolved;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReportModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.title,
    required this.description,
    required this.location,
    required this.address,
    required this.imageUrls,
    required this.waterQuality,
    required this.isResolved,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
      address: json['address'] as String,
      imageUrls: List<String>.from(json['imageUrls'] as List),
      waterQuality: WaterQualityState.values[json['waterQuality'] as int],
      isResolved: json['isResolved'] as bool,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'title': title,
      'description': description,
      'location': location.toJson(),
      'address': address,
      'imageUrls': imageUrls,
      'waterQuality': waterQuality.index,
      'isResolved': isResolved,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  ReportModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? title,
    String? description,
    GeoPoint? location,
    String? address,
    List<String>? imageUrls,
    WaterQualityState? waterQuality,
    bool? isResolved,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      address: address ?? this.address,
      imageUrls: imageUrls ?? this.imageUrls,
      waterQuality: waterQuality ?? this.waterQuality,
      isResolved: isResolved ?? this.isResolved,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RoutePoint {
  final String nodeId;
  final GeoPoint location;
  final String address;
  final String? label;

  RoutePoint({
    required this.nodeId,
    required this.location,
    required this.address,
    this.label,
  });

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      nodeId: json['nodeId'] as String,
      location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
      address: json['address'] as String,
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'location': location.toJson(),
      'address': address,
      'label': label,
    };
  }
}

class RouteSegment {
  final RoutePoint from;
  final RoutePoint to;
  final double distance; // in kilometers
  final List<GeoPoint> polyline;

  RouteSegment({
    required this.from,
    required this.to,
    required this.distance,
    required this.polyline,
  });

  factory RouteSegment.fromJson(Map<String, dynamic> json) {
    return RouteSegment(
      from: RoutePoint.fromJson(json['from'] as Map<String, dynamic>),
      to: RoutePoint.fromJson(json['to'] as Map<String, dynamic>),
      distance: json['distance'] as double,
      polyline: (json['polyline'] as List)
          .map((point) => GeoPoint.fromJson(point as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from.toJson(),
      'to': to.toJson(),
      'distance': distance,
      'polyline': polyline.map((point) => point.toJson()).toList(),
    };
  }
}
