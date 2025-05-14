
// lib/services/database_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:water_watch/models/route_model.dart';
import '../models/report_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // REPORTS
  
  // Create a new report
  Future<String> createReport(ReportModel report) async {
    try {
      final reportRef = _firestore.collection('reports').doc();
      final reportWithId = report.copyWith(id: reportRef.id);
      
      await reportRef.set(reportWithId.toJson());
      return reportRef.id;
    } catch (e) {
      throw Exception('Failed to create report: $e');
    }
  }
  
  // Get a specific report
  Future<ReportModel> getReport(String reportId) async {
    try {
      final doc = await _firestore.collection('reports').doc(reportId).get();
      if (doc.exists) {
        return ReportModel.fromJson(doc.data()!);
      } else {
        throw Exception('Report not found');
      }
    } catch (e) {
      throw Exception('Failed to get report: $e');
    }
  }
  
  // Get all reports
  Stream<List<ReportModel>> getReports() {
    return _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReportModel.fromJson(doc.data()))
          .toList();
    });
  }
  
  // Get reports by user
  Stream<List<ReportModel>> getUserReports(String userId) {
    return _firestore
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReportModel.fromJson(doc.data()))
          .toList();
    });
  }
  
  // Get unresolved reports
  Stream<List<ReportModel>> getUnresolvedReports() {
    return _firestore
        .collection('reports')
        .where('isResolved', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReportModel.fromJson(doc.data()))
          .toList();
    });
  }
  
  // Update a report
  Future<void> updateReport(String reportId, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = DateTime.now();
      await _firestore.collection('reports').doc(reportId).update(data);
    } catch (e) {
      throw Exception('Failed to update report: $e');
    }
  }
  
  // Mark a report as resolved
  Future<void> resolveReport(String reportId) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'isResolved': true,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to resolve report: $e');
    }
  }
  
  // Delete a report
  Future<void> deleteReport(String reportId) async {
    try {
      await _firestore.collection('reports').doc(reportId).delete();
    } catch (e) {
      throw Exception('Failed to delete report: $e');
    }
  }
  
  // ROUTES
  
  // Create a new route
  // In database_service.dart - add this method if not already present
// In your database_service.dart
Future<String> createRoute(Map<String, dynamic> routeData) async {
  try {
    final routeRef = _firestore.collection('routes').doc();
    final routeId = routeData['id'] ?? routeRef.id;
    
    // Add ID if not provided
    if (!routeData.containsKey('id') || routeData['id'] == null) {
      routeData['id'] = routeId;
    }
    
    // Convert timestamps
    if (routeData.containsKey('createdAt') && 
        !(routeData['createdAt'] is firestore.Timestamp)) {
      if (routeData['createdAt'] is DateTime) {
        routeData['createdAt'] = firestore.Timestamp.fromDate(routeData['createdAt']);
      } else if (routeData['createdAt'] is String) {
        routeData['createdAt'] = firestore.Timestamp.fromDate(
          DateTime.parse(routeData['createdAt']));
      } else {
        routeData['createdAt'] = firestore.Timestamp.now();
      }
    }
    
    if (routeData.containsKey('updatedAt') && 
        !(routeData['updatedAt'] is firestore.Timestamp)) {
      if (routeData['updatedAt'] is DateTime) {
        routeData['updatedAt'] = firestore.Timestamp.fromDate(routeData['updatedAt']);
      } else if (routeData['updatedAt'] is String) {
        routeData['updatedAt'] = firestore.Timestamp.fromDate(
          DateTime.parse(routeData['updatedAt']));
      } else {
        routeData['updatedAt'] = firestore.Timestamp.now();
      }
    }
    
    await _firestore.collection('routes').doc(routeId).set(routeData);
    return routeId;
  } catch (e) {
    throw Exception('Failed to create route: $e');
  }
}
  
  // Get a specific route
  Future<RouteModel> getRoute(String routeId) async {
    try {
      final doc = await _firestore.collection('routes').doc(routeId).get();
      if (doc.exists) {
        return RouteModel.fromJson(doc.data()!);
      } else {
        throw Exception('Route not found');
      }
    } catch (e) {
      throw Exception('Failed to get route: $e');
    }
  }
  
  // Get all routes
  Stream<List<RouteModel>> getRoutes() {
    return _firestore
        .collection('routes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RouteModel.fromJson(doc.data()))
          .toList();
    });
  }

   Future<List<ReportModel>> getUnresolvedReportsList() async {
    final snapshot = await _firestore
        .collection('reports')
        .where('isResolved', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .get();
    
    return snapshot.docs
        .map((doc) => ReportModel.fromJson(doc.data()))
        .toList();
  }
  
  Future<List<ReportModel>> getResolvedReportsList() async {
    final snapshot = await _firestore
        .collection('reports')
        .where('isResolved', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    
    return snapshot.docs
        .map((doc) => ReportModel.fromJson(doc.data()))
        .toList();
  }
  
  // Update a route
  Future<void> updateRoute(String routeId, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = DateTime.now();
      await _firestore.collection('routes').doc(routeId).update(data);
    } catch (e) {
      throw Exception('Failed to update route: $e');
    }
  }
  
  // Delete a route
  Future<void> deleteRoute(String routeId) async {
    try {
      await _firestore.collection('routes').doc(routeId).delete();
    } catch (e) {
      throw Exception('Failed to delete route: $e');
    }
  }
}