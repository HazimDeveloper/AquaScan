// lib/widgets/admin/map_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../models/route_model.dart' as route_model;

class RouteMapWidget extends StatefulWidget {
  final route_model.RouteModel? routeModel;
  final List<ReportModel> reports;
  final List<ReportModel> selectedReports;
  final GeoPoint? currentLocation;
  final Function(ReportModel)? onReportTap;
  final bool showSelectionStatus;

  const RouteMapWidget({
    Key? key,
    this.routeModel,
    required this.reports,
    this.selectedReports = const [],
    this.currentLocation,
    this.onReportTap,
    this.showSelectionStatus = true,
  }) : super(key: key);

  @override
  _RouteMapWidgetState createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> with SingleTickerProviderStateMixin {
  late MapController _mapController;
  double _currentZoom = 14.0;
  bool _isInfoWindowVisible = false;
  ReportModel? _selectedReportForInfo;
  
  // Add a field to track the shortest route segment
  int? _shortestRouteIndex;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Find the shortest route segment
    _findShortestRoute();
  }
  
  @override
  void didUpdateWidget(RouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Recalculate shortest route when the routeModel changes
    if (oldWidget.routeModel != widget.routeModel) {
      _findShortestRoute();
    }
  }
  
  // Calculate which route is the shortest
  void _findShortestRoute() {
    if (widget.routeModel != null && widget.routeModel!.segments.isNotEmpty) {
      double shortestDistance = double.infinity;
      int shortestIndex = -1;
      
      for (int i = 0; i < widget.routeModel!.segments.length; i++) {
        final segment = widget.routeModel!.segments[i];
        if (segment.distance < shortestDistance) {
          shortestDistance = segment.distance;
          shortestIndex = i;
        }
      }
      
      setState(() {
        _shortestRouteIndex = shortestIndex;
      });
    } else {
      setState(() {
        _shortestRouteIndex = null;
      });
    }
  }

  // Add a validation method for coordinates
  bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentLocation == null && widget.reports.isEmpty) {
      return _buildNoLocationView();
    }

    return Stack(
      children: [
        // The map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _calculateMapCenter(),
            initialZoom: _currentZoom,
            minZoom: 4,
            maxZoom: 18,
            onTap: (_, __) {
              setState(() {
                _isInfoWindowVisible = false;
                _selectedReportForInfo = null;
              });
            },
            onMapReady: () {
              // Zoom to fit all points
              final bounds = _calculateMapBounds();
              if (bounds != null) {
                _mapController.fitCamera(
                  CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(50.0),
                  ),
                );
              }
            },
          ),
          children: [
            // Base map tiles - OpenStreetMap
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.water_watch',
              // Attribution is important for OpenStreetMap
            ),
            
            // Polylines for route (if available)
            if (widget.routeModel != null)
              PolylineLayer(
                polylines: _buildRoutePolylines(),
              ),
            
            // Markers for reports and current location
            MarkerLayer(
              markers: _buildAllMarkers(),
            ),
            
            // Special marker layer for distance indicators
            if (widget.routeModel != null)
              MarkerLayer(
                markers: _buildDistanceMarkers(),
              ),
          ],
        ),
        
        // Add the legend for routes
        if (widget.routeModel != null && widget.routeModel!.segments.length > 1)
          _buildLegend(),
        
        // Map controls
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom in button
              FloatingActionButton(
                heroTag: 'zoomIn',
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 4,
                onPressed: () {
                  setState(() {
                    _currentZoom += 1;
                    _mapController.move(_mapController.camera.center, _currentZoom);
                  });
                },
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              
              // Zoom out button
              FloatingActionButton(
                heroTag: 'zoomOut',
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 4,
                onPressed: () {
                  setState(() {
                    _currentZoom -= 1;
                    _mapController.move(_mapController.camera.center, _currentZoom);
                  });
                },
                child: const Icon(Icons.remove),
              ),
              const SizedBox(height: 8),
              
              // Reset view button
              FloatingActionButton(
                heroTag: 'resetView',
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 4,
                onPressed: () {
                  // Fit map to show all points
                  final bounds = _calculateMapBounds();
                  if (bounds != null) {
                    _mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(50.0),
                      ),
                    );
                  }
                },
                child: const Icon(Icons.fit_screen),
              ),
            ],
          ),
        ),
        
        // Info window when a report marker is tapped
        if (_isInfoWindowVisible && _selectedReportForInfo != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildReportInfoWindow(_selectedReportForInfo!),
          ),
          
        // Route info panel when a route is shown
        if (widget.routeModel != null)
          Positioned(
            top: 16,
            left: 16,
            right: 96, // Make room for legend
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Water Supply Routes",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${widget.routeModel!.points.length ~/ 2} water points",
                          style: TextStyle(color: Colors.black54),
                        ),
                        Row(
                          children: [
                            Icon(Icons.route, size: 16, color: Theme.of(context).primaryColor),
                            SizedBox(width: 4),
                            Text(
                              "Total: ${widget.routeModel!.totalDistance.toStringAsFixed(2)} km",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Add info about shortest route if available
                    if (_shortestRouteIndex != null && _shortestRouteIndex! < widget.routeModel!.segments.length)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.verified, size: 16, color: Colors.blue),
                            SizedBox(width: 4),
                            Text(
                              "Shortest route: ${widget.routeModel!.segments[_shortestRouteIndex!].distance.toStringAsFixed(2)} km",
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
        // Selection counter
        if (widget.showSelectionStatus && widget.selectedReports.isNotEmpty)
          Positioned(
            top: widget.routeModel != null ? 120 : 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                "${widget.selectedReports.length} reports selected",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildNoLocationView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            "Location not available",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "Please enable location services to view the map",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  LatLng _calculateMapCenter() {
    if (widget.routeModel != null && widget.routeModel!.points.isNotEmpty) {
      final firstPoint = widget.routeModel!.points.first;
      return LatLng(firstPoint.location.latitude, firstPoint.location.longitude);
    } else if (widget.currentLocation != null) {
      return LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude);
    } else if (widget.reports.isNotEmpty) {
      final firstReport = widget.reports.first;
      return LatLng(firstReport.location.latitude, firstReport.location.longitude);
    } else {
      // Default to some location
      return LatLng(0, 0);
    }
  }
  
  LatLngBounds? _calculateMapBounds() {
    final points = <LatLng>[];
    
    // Add current location
    if (widget.currentLocation != null && 
        _isValidCoordinate(widget.currentLocation!.latitude, widget.currentLocation!.longitude)) {
      points.add(LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude));
    }
    
    // Add report locations
    for (final report in widget.reports) {
      if (_isValidCoordinate(report.location.latitude, report.location.longitude)) {
        points.add(LatLng(report.location.latitude, report.location.longitude));
      }
    }
    
    // If there's a route model, use its points and polylines
    if (widget.routeModel != null) {
      for (final point in widget.routeModel!.points) {
        if (_isValidCoordinate(point.location.latitude, point.location.longitude)) {
          points.add(LatLng(point.location.latitude, point.location.longitude));
        }
      }
      
      for (final segment in widget.routeModel!.segments) {
        for (final point in segment.polyline) {
          if (_isValidCoordinate(point.latitude, point.longitude)) {
            points.add(LatLng(point.latitude, point.longitude));
          }
        }
      }
    }
    
    if (points.isEmpty) {
      return null;
    }
    
    // If we only have one point, create a small bounding box around it
    if (points.length == 1) {
      final point = points.first;
      const delta = 0.01; // About 1km
      return LatLngBounds(
        LatLng(point.latitude - delta, point.longitude - delta),
        LatLng(point.latitude + delta, point.longitude + delta),
      );
    }
    
    // Find the bounds
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }
    
    // Add some padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;
    
    return LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }
  
  // Update the method to build polylines with different colors
  List<Polyline> _buildRoutePolylines() {
    final polylines = <Polyline>[];
    
    if (widget.routeModel != null) {
      for (int i = 0; i < widget.routeModel!.segments.length; i++) {
        final segment = widget.routeModel!.segments[i];
        
        // Skip segments with no polyline
        if (segment.polyline.isEmpty) continue;
        
        // Skip segments with invalid coordinates
        bool hasInvalidCoords = false;
        for (final point in segment.polyline) {
          if (!_isValidCoordinate(point.latitude, point.longitude)) {
            hasInvalidCoords = true;
            break;
          }
        }
        if (hasInvalidCoords) continue;
        
        // Determine if this is the shortest route
        final isShortestRoute = i == _shortestRouteIndex;
        
        // Choose color based on whether this is the shortest route
        final Color routeColor = isShortestRoute 
            ? Colors.blue 
            : Colors.red;
        
        // Create polyline with the appropriate color
        if (segment.distance == 0 && segment.polyline.length > 1 && 
            segment.polyline.first.latitude == segment.polyline.last.latitude && 
            segment.polyline.first.longitude == segment.polyline.last.longitude) {
          
          // Create a small circular path around the point
          final List<LatLng> circlePoints = [];
          final centerLat = segment.polyline.first.latitude;
          final centerLng = segment.polyline.first.longitude;
          const radius = 0.0005; // Small radius ~50m
          
          for (int j = 0; j < 20; j++) {
            final angle = j * (2 * pi / 20);
            final lat = centerLat + radius * cos(angle);
            final lng = centerLng + radius * sin(angle);
            circlePoints.add(LatLng(lat, lng));
          }
          // Close the circle
          circlePoints.add(circlePoints.first);
          
          polylines.add(
            Polyline(
              points: circlePoints,
              color: routeColor,
              strokeWidth: 4.0,
            ),
          );
        } else {
          // Regular polyline
          final List<LatLng> points = segment.polyline
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
          
          polylines.add(
            Polyline(
              points: points,
              color: routeColor,
              strokeWidth: isShortestRoute ? 5.0 : 3.0, // Make shortest route slightly thicker
            ),
          );
        }
      }
    }
    
    return polylines;
  }
  
   List<Marker> _buildAllMarkers() {
    final markers = <Marker>[];
    
    // Add current location marker
    if (widget.currentLocation != null && 
        _isValidCoordinate(widget.currentLocation!.latitude, widget.currentLocation!.longitude)) {
      markers.add(
        Marker(
          point: LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude),
          width: 100, // Reduced from 60
          height: 60, // Reduced from 60
          child: Column(
            mainAxisSize: MainAxisSize.min, // Add this to prevent overflow
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.my_location, color: Colors.white, size: 16), // Reduced size
              ),
              if (widget.routeModel != null)
                Container(
                  margin: const EdgeInsets.only(top: 1), // Reduced from 2
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Smaller padding
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2), // Reduced from 4
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 1, // Reduced from 2
                      ),
                    ],
                  ),
                  child: const Text(
                    "Start",
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold), // Reduced from 10
                  ),
                ),
            ],
          ),
        ),
      );
    }
    
    // Add route model points with different colors
    if (widget.routeModel != null) {
      for (int i = 0; i < widget.routeModel!.points.length; i++) {
        final point = widget.routeModel!.points[i];
        
        // Skip invalid coordinates
        if (!_isValidCoordinate(point.location.latitude, point.location.longitude)) {
          continue;
        }
        
        // Skip if it's the start point (already added as current location)
        if (i == 0 && point.nodeId == "start") continue;
        
        // Determine if this point is part of the shortest route
        // We need to check both from and to points in segments
        bool isPartOfShortestRoute = false;
        if (_shortestRouteIndex != null && _shortestRouteIndex! < widget.routeModel!.segments.length) {
          final shortestSegment = widget.routeModel!.segments[_shortestRouteIndex!];
          if ((point.nodeId == shortestSegment.from.nodeId) || 
              (point.nodeId == shortestSegment.to.nodeId)) {
            isPartOfShortestRoute = true;
          }
        }
        
        // Choose color based on whether this is part of the shortest route
        final Color markerColor = isPartOfShortestRoute ? Colors.blue : Colors.red;
        
        // Is it a report point or water supply point?
        final bool isReportPoint = i % 2 == 0; // Assuming reports are at even indices
        final IconData markerIcon = isReportPoint ? Icons.location_on : Icons.water_drop;
        final String labelText = isReportPoint ? "Report" : "Water";
        
        markers.add(
          Marker(
            point: LatLng(point.location.latitude, point.location.longitude),
            width: 100, // Reduced from 60
            height: 60, // Reduced from 60
            child: Column(
              mainAxisSize: MainAxisSize.min, // Add this to prevent overflow
              children: [
                Container(
                  width: 24, // Reduced from 30
                  height: 24, // Reduced from 30
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 2, // Reduced from 4
                        offset: const Offset(0, 1), // Reduced from (0, 2)
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      markerIcon,
                      color: Colors.white, 
                      size: 12, // Reduced from 16
                    ),
                  ),
                ),
                if (labelText.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 1), // Reduced from 2
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Smaller padding
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2), // Reduced from 4
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      isPartOfShortestRoute ? "$labelText (Shortest)" : labelText,
                      style: TextStyle(
                        fontSize: 7, // Reduced from 10
                        fontWeight: FontWeight.bold,
                        color: markerColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    } else {
      // Show regular report markers when not showing optimized routes
      for (final report in widget.reports) {
        // Skip invalid coordinates
        if (!_isValidCoordinate(report.location.latitude, report.location.longitude)) {
          continue;
        }
        
        final isSelected = widget.selectedReports.any((r) => r.id == report.id);
        markers.add(
          Marker(
            point: LatLng(report.location.latitude, report.location.longitude),
            width: 32, // Reduced from 40
            height: 32, // Reduced from 40
            child: GestureDetector(
              onTap: () {
                if (widget.onReportTap != null) {
                  widget.onReportTap!(report);
                } else {
                  setState(() {
                    _selectedReportForInfo = report;
                    _isInfoWindowVisible = true;
                  });
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2, // Reduced from 4
                      offset: const Offset(0, 1), // Reduced from (0, 2)
                    ),
                  ],
                ),
                child: Icon(
                  Icons.water_drop,
                  color: Colors.white,
                  size: isSelected ? 16 : 14, // Reduced sizes
                ),
              ),
            ),
          ),
        );
      }
    }
    
    return markers;
  }
  
  // Update the distance markers to match the polyline colors
  List<Marker> _buildDistanceMarkers() {
    final markers = <Marker>[];
    
    if (widget.routeModel != null) {
      for (int i = 0; i < widget.routeModel!.segments.length; i++) {
        final segment = widget.routeModel!.segments[i];
        
        // Skip showing distance for zero-length segments
        if (segment.distance == 0) continue;
        
        // Find midpoint for the distance marker
        if (segment.polyline.length >= 2) {
          final midIndex = segment.polyline.length ~/ 2;
          final midPoint = segment.polyline[midIndex];
          
          // Skip invalid coordinates
          if (!_isValidCoordinate(midPoint.latitude, midPoint.longitude)) {
            continue;
          }
          
          // Determine if this is the shortest route
          final isShortestRoute = i == _shortestRouteIndex;
          
          // Choose color based on whether this is the shortest route
          final Color routeColor = isShortestRoute 
              ? Colors.blue 
              : Colors.red;
          
          markers.add(
            Marker(
              point: LatLng(midPoint.latitude, midPoint.longitude),
              width: 80,
              height: 30,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isShortestRoute ? Icons.verified : Icons.directions,
                      size: 12,
                      color: routeColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "${segment.distance.toStringAsFixed(1)} km",
                        style: TextStyle(
                          color: routeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }
    }
    
    return markers;
  }
  
  Widget _buildReportInfoWindow(ReportModel report) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isInfoWindowVisible = false;
                      _selectedReportForInfo = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 16, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              report.description,
              style: TextStyle(color: Colors.grey.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    report.address,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getWaterQualityColor(report.waterQuality).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getWaterQualityColor(report.waterQuality),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.water_drop,
                        color: _getWaterQualityColor(report.waterQuality),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _getWaterQualityText(report.waterQuality),
                          style: TextStyle(
                            color: _getWaterQualityColor(report.waterQuality),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Selection button (if applicable)
                if (widget.onReportTap != null)
                  TextButton(
                    onPressed: () {
                      if (widget.onReportTap != null) {
                        widget.onReportTap!(report);
                        setState(() {
                          _isInfoWindowVisible = false;
                        _selectedReportForInfo = null;
                      });
                    }
                  },
                  child: Text(
                    widget.selectedReports.any((r) => r.id == report.id)
                        ? "Deselect"
                        : "Select",
                  ),
                ),
                
                SizedBox(width: 8),
                
                // View Details button
                ElevatedButton(
                  onPressed: () {
                    // Show details dialog
                    setState(() {
                      _isInfoWindowVisible = false;
                      _selectedReportForInfo = null;
                    });
                    _showReportDetailsDialog(report);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: Text("View Details"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _showReportDetailsDialog(ReportModel report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image carousel if available
              if (report.imageUrls.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    itemCount: report.imageUrls.length,
                    itemBuilder: (context, index) {
                      return Image.network(
                        report.imageUrls[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(
                                Icons.error_outline,
                                color: Colors.grey,
                                size: 50,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Water quality indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getWaterQualityColor(report.waterQuality).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getWaterQualityColor(report.waterQuality),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.water_drop,
                      color: _getWaterQualityColor(report.waterQuality),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getWaterQualityText(report.waterQuality),
                      style: TextStyle(
                        color: _getWaterQualityColor(report.waterQuality),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Description
              const Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(report.description),
              
              const SizedBox(height: 16),
              
              // Address
              const Text(
                'Location',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(report.address),
              
              const SizedBox(height: 16),
              
              // Coordinates
              const Text(
                'Coordinates',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${report.location.latitude.toStringAsFixed(6)}, ${report.location.longitude.toStringAsFixed(6)}',
                style: TextStyle(
                  fontFamily: 'monospace',
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Report date
              const Text(
                'Report Date',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(_formatDate(report.createdAt)),
            ],
          ),
        ),
        actions: [
          // Close button
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
          
          // Selection button (if applicable)
          if (widget.onReportTap != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (widget.onReportTap != null) {
                  widget.onReportTap!(report);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.selectedReports.any((r) => r.id == report.id)
                    ? Colors.grey
                    : AppTheme.primaryColor,
              ),
              child: Text(
                widget.selectedReports.any((r) => r.id == report.id)
                    ? 'Deselect'
                    : 'Select',
              ),
            ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  Color _getWaterQualityColor(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.clean:
        return Colors.blue;
      case WaterQualityState.slightlyContaminated:
        return Colors.green;
      case WaterQualityState.moderatelyContaminated:
        return Colors.orange;
      case WaterQualityState.heavilyContaminated:
        return Colors.red;
      case WaterQualityState.unknown:
      default:
        return Colors.grey;
    }
  }
  
  String _getWaterQualityText(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.clean:
        return 'Clean';
      case WaterQualityState.slightlyContaminated:
        return 'Slightly Contaminated';
      case WaterQualityState.moderatelyContaminated:
        return 'Moderately Contaminated';
      case WaterQualityState.heavilyContaminated:
        return 'Heavily Contaminated';
      case WaterQualityState.unknown:
      default:
        return 'Unknown';
    }
  }
  
  // Add a legend to the map to explain the colors
  Widget _buildLegend() {
    return Positioned(
      top: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Route Legend",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 4,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 4),
                  const Text("Shortest Route", style: TextStyle(fontSize: 10)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 4,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 4),
                  const Text("Other Routes", style: TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Add a simpler map widget for showing single locations
class SimpleLocationMapWidget extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? address;
  final double height;
  final IconData markerIcon;
  final Color markerColor;
  
  const SimpleLocationMapWidget({
    Key? key,
    required this.latitude,
    required this.longitude,
    this.address,
    this.height = 200,
    this.markerIcon = Icons.location_on,
    this.markerColor = Colors.red,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The map
        SizedBox(
          height: height,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(latitude, longitude),
              initialZoom: 14.0,
              minZoom: 4,
              maxZoom: 18,
            ),
            children: [
              // Base map tiles
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.water_watch',
              ),
              
              // Location marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(latitude, longitude),
                    alignment: Alignment.center,
                    child: Icon(
                      markerIcon,
                      color: markerColor,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Address overlay (if provided)
        if (address != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black.withOpacity(0.6),
              child: Text(
                address!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}