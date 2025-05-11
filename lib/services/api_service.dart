
// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:water_watch/models/route_model.dart' show RouteModel;
import '../models/report_model.dart';

class ApiService {
  // Base URL for our Python backend
  final String baseUrl;
  
  ApiService({required this.baseUrl});
  
  // Headers for API requests
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };
  
  // Water quality analysis from image
  Future<WaterQualityState> analyzeWaterQuality(File imageFile) async {
    try {
      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));
      
      // Add image file
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      
      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        fileLength,
        filename: 'water_image.jpg',
      );
      
      request.files.add(multipartFile);
      
      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        final qualityIndex = data['water_quality_index'] as int;
        
        // Convert to WaterQualityState enum
        return WaterQualityState.values[qualityIndex];
      } else {
        throw Exception('Failed to analyze image: ${responseBody}');
      }
    } catch (e) {
      // Return unknown on error
      return WaterQualityState.unknown;
    }
  }
  
  // Get optimized route for a set of reports
  Future<RouteModel> getOptimizedRoute(
    List<ReportModel> reports,
    GeoPoint startLocation,
    String adminId,
  ) async {
    try {
      // Prepare request data
      final requestData = {
        'admin_id': adminId,
        'start_location': {
          'latitude': startLocation.latitude,
          'longitude': startLocation.longitude,
        },
        'reports': reports.map((report) => {
          'id': report.id,
          'location': {
            'latitude': report.location.latitude,
            'longitude': report.location.longitude,
          },
          'address': report.address,
        }).toList(),
      };
      
      // Send request
      final response = await http.post(
        Uri.parse('$baseUrl/optimize-route'),
        headers: _headers,
        body: json.encode(requestData),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return RouteModel.fromJson(data);
      } else {
        throw Exception('Failed to optimize route: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to optimize route: $e');
    }
  }
}