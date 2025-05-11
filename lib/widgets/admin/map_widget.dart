// lib/widgets/admin/map_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:water_watch/models/report_model.dart' as route_model;
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../models/route_model.dart' as route_model;

class RouteMapWidget extends StatefulWidget {
  final route_model.RouteModel? routeModel;
  final List<ReportModel> reports;
  final List<ReportModel> selectedReports;
  final route_model.GeoPoint? currentLocation;
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
  
  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }
  
  @override
  Widget build(BuildContext context) {
    // If no current location and no reports, show placeholder
    if (widget.currentLocation == null && widget.reports.isEmpty) {
      return _buildNoLocationView();
    }
    
    // Calculate bounds for the map
    final bounds = _calculateMapBounds();
    
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
            // Base map tiles
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.aquascan.app',
            ),
            
            // Optimized route polylines (if available)
            if (widget.routeModel != null)
              _buildRoutePolylines(),
            
            // Report markers
            MarkerLayer(
              markers: _buildAllMarkers(),
            ),
            
            // Distance markers (if route is available)
            if (widget.routeModel != null)
              _buildDistanceMarkers(),
              
            // Add attribution manually instead of using AttributionWidget
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ),
            ),
          ],
        ),
        
        // Map control buttons
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom in button
              FloatingActionButton(
                heroTag: 'zoomIn',
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.textPrimaryColor,
                elevation: 4,
                onPressed: () {
                  final newZoom = _mapController.camera.zoom + 1;
                  _mapController.move(_mapController.camera.center, newZoom);
                  setState(() {
                    _currentZoom = newZoom;
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
                foregroundColor: AppTheme.textPrimaryColor,
                elevation: 4,
                onPressed: () {
                  final newZoom = _mapController.camera.zoom - 1;
                  _mapController.move(_mapController.camera.center, newZoom);
                  setState(() {
                    _currentZoom = newZoom;
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
                foregroundColor: AppTheme.textPrimaryColor,
                elevation: 4,
                onPressed: () {
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
                child: const Icon(Icons.center_focus_weak),
              ),
            ],
          ),
        ),
        
        // Info window for selected report
        if (_isInfoWindowVisible && _selectedReportForInfo != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildReportInfoWindow(_selectedReportForInfo!),
          ),
        
        // Route info overlay (if route is available)
        if (widget.routeModel != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildRouteInfoOverlay(),
          ),
        
        // Current selection counter (if applicable)
        if (widget.showSelectionStatus && widget.selectedReports.isNotEmpty)
          Positioned(
            top: widget.routeModel != null ? 100 : 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${widget.selectedReports.length} reports selected',
                style: const TextStyle(
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
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'Location not available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Please enable location services to view the map',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  LatLng _calculateMapCenter() {
    if (widget.routeModel != null && widget.routeModel!.points.isNotEmpty) {
      // Use the first point in the route
      final firstPoint = widget.routeModel!.points.first;
      return LatLng(firstPoint.location.latitude, firstPoint.location.longitude);
    } else if (widget.currentLocation != null) {
      // Use current location
      return LatLng(widget.currentLocation!.latitude, widget.currentLocation!.longitude);
    } else if (widget.reports.isNotEmpty) {
      // Use the first report location
      final firstReport = widget.reports.first;
      return LatLng(firstReport.location.latitude, firstReport.location.longitude);
    } else {
      // Default to a location (could be customized)
      return const LatLng(2.9271, 101.6523); // Default to Cyberjaya, Malaysia
    }
  }
  
  LatLngBounds? _calculateMapBounds() {
    if (widget.reports.isEmpty && widget.currentLocation == null) {
      return null;
    }
    
    List<LatLng> allPoints = [];
    
    // Add current location if available
    if (widget.currentLocation != null) {
      allPoints.add(LatLng(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
      ));
    }
    
    // Add report locations
    for (final report in widget.reports) {
      allPoints.add(LatLng(
        report.location.latitude,
        report.location.longitude,
      ));
    }
    
    // If we have route points, use those instead
    if (widget.routeModel != null) {
      allPoints = [];
      
      for (final point in widget.routeModel!.points) {
        allPoints.add(LatLng(
          point.location.latitude,
          point.location.longitude,
        ));
      }
      
      // Add all polyline points too
      for (final segment in widget.routeModel!.segments) {
        for (final point in segment.polyline) {
          allPoints.add(LatLng(
            point.latitude,
            point.longitude,
          ));
        }
      }
    }
    
    if (allPoints.isEmpty) {
      return null;
    }
    
    // Find min/max coordinates
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    for (final point in allPoints) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    
    // Add padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;
    
    return LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }
  
  PolylineLayer _buildRoutePolylines() {
    final List<Polyline> polylines = [];
    
    if (widget.routeModel != null) {
      for (final segment in widget.routeModel!.segments) {
        final List<LatLng> points = [];
        
        for (final point in segment.polyline) {
          points.add(LatLng(
            point.latitude,
            point.longitude,
          ));
        }
        
        polylines.add(
          Polyline(
            points: points,
            strokeWidth: 4.0,
            color: AppTheme.primaryColor,
          ),
        );
      }
    }
    
    return PolylineLayer(
      polylines: polylines,
    );
  }
  
  List<Marker> _buildAllMarkers() {
    final List<Marker> markers = [];
    
    // Current location marker
    if (widget.currentLocation != null) {
      markers.add(_buildCurrentLocationMarker());
    }
    
    // Report markers
    if (widget.routeModel == null) {
      // Regular markers for reports
      for (final report in widget.reports) {
        markers.add(_buildReportMarker(report));
      }
    } else {
      // Numbered markers for route points
      for (int i = 0; i < widget.routeModel!.points.length; i++) {
        final point = widget.routeModel!.points[i];
        
        // Skip current location (already added)
        if (i == 0 && point.nodeId == 'start') {
          continue;
        }
        
        markers.add(_buildRoutePointMarker(point, i));
      }
    }
    
    return markers;
  }
  
  Marker _buildCurrentLocationMarker() {
    return Marker(
      point: LatLng(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            width: 28,
            height: 28,
            child: const Icon(
              Icons.my_location,
              color: Colors.white,
              size: 16,
            ),
          ),
          // Label
          if (widget.routeModel != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Text(
                'Start',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Marker _buildReportMarker(ReportModel report) {
    final isSelected = widget.selectedReports.any((r) => r.id == report.id);
    
    return Marker(
      point: LatLng(
        report.location.latitude,
        report.location.longitude,
      ),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          if (widget.onReportTap != null) {
            widget.onReportTap!(report);
          } else {
            setState(() {
              _isInfoWindowVisible = true;
              _selectedReportForInfo = report;
            });
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          width: 24,
          height: 24,
          child: Icon(
            Icons.water_drop,
            color: Colors.white,
            size: isSelected ? 14 : 12,
          ),
        ),
      ),
    );
  }
  
  Marker _buildRoutePointMarker(route_model.RoutePoint point, int index) {
    // Find the report that corresponds to this point
    final reportId = point.nodeId;
    ReportModel? correspondingReport;
    
    for (final report in widget.reports) {
      if (report.id == reportId) {
        correspondingReport = report;
        break;
      }
    }
    
    // Is last point?
    final isLastPoint = index == widget.routeModel!.points.length - 1;
    
    return Marker(
      point: LatLng(
        point.location.latitude,
        point.location.longitude,
      ),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          if (correspondingReport != null && widget.onReportTap != null) {
            widget.onReportTap!(correspondingReport);
          } else if (correspondingReport != null) {
            setState(() {
              _isInfoWindowVisible = true;
              _selectedReportForInfo = correspondingReport;
            });
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isLastPoint ? AppTheme.successColor : AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              width: 28,
              height: 28,
              child: Center(
                child: isLastPoint
                    ? const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 16,
                      )
                    : Text(
                        index.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            // Label
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                isLastPoint ? 'End' : 'Stop ${index}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  MarkerLayer _buildDistanceMarkers() {
    final List<Marker> markers = [];
    
    if (widget.routeModel != null) {
      for (final segment in widget.routeModel!.segments) {
        // Calculate midpoint for the distance marker
        if (segment.polyline.length >= 2) {
          final midIndex = segment.polyline.length ~/ 2;
          final midPoint = segment.polyline[midIndex];
          
          markers.add(
            Marker(
              point: LatLng(
                midPoint.latitude,
                midPoint.longitude,
              ),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  '${segment.distance.toStringAsFixed(1)} km',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }
      }
    }
    
    return MarkerLayer(markers: markers);
  }
  
  Widget _buildReportInfoWindow(ReportModel report) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isInfoWindowVisible = false;
                    _selectedReportForInfo = null;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
            
            // Title and water quality indicator
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
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
                        size: 14,
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
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Description
            Text(
              report.description,
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 12),
            
            // Address
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    report.address,
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Action buttons
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
                          ? 'Deselect'
                          : 'Select',
                    ),
                  ),
                
                // Details button
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isInfoWindowVisible = false;
                      _selectedReportForInfo = null;
                    });
                    _showReportDetailsDialog(report);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('View Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRouteInfoOverlay() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Optimized Route',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.routeModel!.points.length} stops',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Total: ${widget.routeModel!.totalDistance.toStringAsFixed(2)} km',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
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
              
              // Reported by
              const Text(
                'Reported by',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(report.userName),
              
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
}

// A simplified map widget for showing a single location (e.g., a report location)
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
                userAgentPackageName: 'com.aquascan.app',
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
              
              // Add attribution manually
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ),
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
        
        // Zoom control buttons
        Positioned(
          top: 8,
          right: 8,
          child: Column(
            children: [
              FloatingActionButton(
                heroTag: 'simpleZoomIn',
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                onPressed: () {},
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 4),
              FloatingActionButton(
                heroTag: 'simpleZoomOut',
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                onPressed: () {},
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
// Widget for showing a specific route on a map
class RoutePreviewMapWidget extends StatefulWidget {
  final route_model.RouteModel routeModel;
  final double height;
  
  const RoutePreviewMapWidget({
    Key? key,
    required this.routeModel,
    this.height = 300,
  }) : super(key: key);

  @override
  State<RoutePreviewMapWidget> createState() => _RoutePreviewMapWidgetState();
}

class _RoutePreviewMapWidgetState extends State<RoutePreviewMapWidget> {
  final MapController _mapController = MapController();
  
  @override
  Widget build(BuildContext context) {
    // Extract all points for bounds calculation
    final List<LatLng> allPoints = [];
    
    // Add route points
    for (final point in widget.routeModel.points) {
      allPoints.add(LatLng(
        point.location.latitude,
        point.location.longitude,
      ));
    }
    
    // Add polyline points
    for (final segment in widget.routeModel.segments) {
      for (final point in segment.polyline) {
        allPoints.add(LatLng(
          point.latitude,
          point.longitude,
        ));
      }
    }
    
    // Calculate bounds
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    for (final point in allPoints) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    
    // Add some padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;
    
    final bounds = LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
    
    return SizedBox(
      height: widget.height,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(
            (minLat + maxLat) / 2,
            (minLng + maxLng) / 2,
          ),
          initialZoom: 10,
          onMapReady: () {
            // Using a post-frame callback to ensure the map is fully rendered
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(20),
                ),
              );
            });
          },
        ),
        children: [
          // Base map tiles
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.aquascan.app',
          ),
          
          // Route polylines
          PolylineLayer(
            polylines: _buildRoutePolylines(),
          ),
          
          // Markers for route points
          MarkerLayer(
            markers: _buildMarkers(),
          ),
          
          // Attribution layer
          const AttributionLayer(),
        ],
      ),
    );
  }
  
  List<Polyline> _buildRoutePolylines() {
    final List<Polyline> polylines = [];
    
    for (final segment in widget.routeModel.segments) {
      final List<LatLng> points = [];
      
      for (final point in segment.polyline) {
        points.add(LatLng(
          point.latitude,
          point.longitude,
        ));
      }
      
      polylines.add(
        Polyline(
          points: points,
          strokeWidth: 4.0,
          color: AppTheme.primaryColor,
        ),
      );
    }
    
    return polylines;
  }
  
  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];
    
    for (int i = 0; i < widget.routeModel.points.length; i++) {
      final point = widget.routeModel.points[i];
      
      markers.add(
        Marker(
          point: LatLng(
            point.location.latitude,
            point.location.longitude,
          ),
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: i == 0 
                  ? Colors.blue
                  : i == widget.routeModel.points.length - 1
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
            width: 24,
            height: 24,
            child: Center(
              child: i == 0
                  ? const Icon(
                      Icons.my_location,
                      color: Colors.white,
                      size: 14,
                    )
                  : i == widget.routeModel.points.length - 1
                      ? const Icon(
                          Icons.flag,
                          color: Colors.white,
                          size: 14,
                        )
                      : Text(
                          i.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
            ),
          ),
        ),
      );
    }
    
    return markers;
  }
}

// Simple attribution layer
class AttributionLayer extends StatelessWidget {
  const AttributionLayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 2,
      right: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Text(
          '© OpenStreetMap contributors',
          style: TextStyle(fontSize: 10, color: Colors.black54),
        ),
      ),
    );
  }
}