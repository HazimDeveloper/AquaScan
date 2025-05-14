// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
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
  
  // Utility function to convert API date formats to Timestamp objects
  Map<String, dynamic> convertApiDates(Map<String, dynamic> apiJson) {
    var result = Map<String, dynamic>.from(apiJson);
    
    // Check and convert date fields
    if (result.containsKey('createdAt') && !(result['createdAt'] is firestore.Timestamp)) {
      try {
        DateTime dateTime;
        if (result['createdAt'] is int) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(result['createdAt']);
        } else if (result['createdAt'] is String) {
          dateTime = DateTime.parse(result['createdAt']);
        } else {
          dateTime = DateTime.now();
        }
        result['createdAt'] = firestore.Timestamp.fromDate(dateTime);
      } catch (e) {
        print("Error converting createdAt: $e");
        result['createdAt'] = firestore.Timestamp.now();
      }
    }
    
    if (result.containsKey('updatedAt') && !(result['updatedAt'] is firestore.Timestamp)) {
      try {
        DateTime dateTime;
        if (result['updatedAt'] is int) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(result['updatedAt']);
        } else if (result['updatedAt'] is String) {
          dateTime = DateTime.parse(result['updatedAt']);
        } else {
          dateTime = DateTime.now();
        }
        result['updatedAt'] = firestore.Timestamp.fromDate(dateTime);
      } catch (e) {
        print("Error converting updatedAt: $e");
        result['updatedAt'] = firestore.Timestamp.now();
      }
    }
    
    return result;
  }
  
  // Apply date conversion to all objects in a list
  List<Map<String, dynamic>> convertListDates(List<dynamic> jsonList) {
    return jsonList.map((item) {
      if (item is Map<String, dynamic>) {
        return convertApiDates(item);
      }
      return <String, dynamic>{}; // Return empty map if item is not a Map
    }).toList();
  }
  
  // Process nested objects with dates
  Map<String, dynamic> processNestedObjects(Map<String, dynamic> data) {
    var result = Map<String, dynamic>.from(data);
    
    // Handle nested objects in points array
    if (result.containsKey('points') && result['points'] is List) {
      result['points'] = (result['points'] as List).map((point) {
        if (point is Map<String, dynamic>) {
          return point; // No dates in route points
        }
        return <String, dynamic>{}; // Return empty map if point is not a Map
      }).toList();
    }
    
    // Handle nested objects in segments array
    if (result.containsKey('segments') && result['segments'] is List) {
      result['segments'] = (result['segments'] as List).map((segment) {
        if (segment is Map<String, dynamic>) {
          // Recursively process 'from' and 'to' objects if they exist
          if (segment.containsKey('from') && segment['from'] is Map<String, dynamic>) {
            segment['from'] = segment['from']; // No dates in 'from'
          }
          if (segment.containsKey('to') && segment['to'] is Map<String, dynamic>) {
            segment['to'] = segment['to']; // No dates in 'to'
          }
          return segment;
        }
        return <String, dynamic>{}; // Return empty map if segment is not a Map
      }).toList();
    }
    
    return result;
  }
  
  // Helper method to convert timestamps
  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    var result = Map<String, dynamic>.from(data);
    
    // Convert createdAt and updatedAt to Timestamp objects
    if (result.containsKey('createdAt')) {
      try {
        final timestamp = result['createdAt'];
        DateTime dateTime;
        if (timestamp is int) {
          // Milliseconds timestamp
          dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else if (timestamp is String) {
          // ISO string
          dateTime = DateTime.parse(timestamp);
        } else {
          // Unknown format, use current time
          dateTime = DateTime.now();
        }
        result['createdAt'] = firestore.Timestamp.fromDate(dateTime);
      } catch (e) {
        print('Error converting createdAt: $e');
        result['createdAt'] = firestore.Timestamp.now();
      }
    } else {
      // Provide a default if missing
      result['createdAt'] = firestore.Timestamp.now();
    }
    
    if (result.containsKey('updatedAt')) {
      try {
        final timestamp = result['updatedAt'];
        DateTime dateTime;
        if (timestamp is int) {
          // Milliseconds timestamp
          dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else if (timestamp is String) {
          // ISO string
          dateTime = DateTime.parse(timestamp);
        } else {
          // Unknown format, use current time
          dateTime = DateTime.now();
        }
        result['updatedAt'] = firestore.Timestamp.fromDate(dateTime);
      } catch (e) {
        print('Error converting updatedAt: $e');
        result['updatedAt'] = firestore.Timestamp.now();
      }
    } else {
      // Provide a default if missing
      result['updatedAt'] = firestore.Timestamp.now();
    }
    
    return result;
  }
  
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
      print('Error analyzing water quality: $e');
      // Return unknown on error
      return WaterQualityState.unknown;
    }
  }
  
  // Get optimized route for a set of reports
  // In api_service.dart - update the getOptimizedRoute method
Future<Map<String, dynamic>> getOptimizedRoute(
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
    
    print('Finding closest water supplies for ${reports.length} reports');
    
    // Send request
    final response = await http.post(
      Uri.parse('$baseUrl/optimize-route'),
      headers: _headers,
      body: json.encode(requestData),
    );
    
    if (response.statusCode == 200) {
      print('Received successful response from water supply finder API');
      
      // Safely decode JSON
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body) as Map<String, dynamic>;
        return data;
      } catch (e) {
        print('Error decoding JSON response: $e');
        print('Response content: ${response.body}');
        throw Exception('Invalid JSON response from server: $e');
      }
    } else {
      print('Received error response: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to find nearest water supplies: ${response.body}');
    }
  } catch (e) {
    print('Error finding water supplies: $e');
    throw Exception('Failed to find water supplies: $e');
  }
}
  
  // Ensure required fields are present in the data
  void _ensureRequiredFields(Map<String, dynamic> data) {
    // Check and provide defaults for critical fields
    if (!data.containsKey('id') || data['id'] == null) {
      data['id'] = 'route-${DateTime.now().millisecondsSinceEpoch}';
    }
    
    if (!data.containsKey('adminId') || data['adminId'] == null) {
      data['adminId'] = '';
    }
    
    if (!data.containsKey('reportIds') || data['reportIds'] == null) {
      data['reportIds'] = [];
    }
    
    if (!data.containsKey('points') || data['points'] == null) {
      data['points'] = [];
    }
    
    if (!data.containsKey('segments') || data['segments'] == null) {
      data['segments'] = [];
    }
    
    if (!data.containsKey('totalDistance') || data['totalDistance'] == null) {
      data['totalDistance'] = 0.0;
    }
    
    // Ensure createdAt and updatedAt (handled in _convertTimestamps)
  }
}