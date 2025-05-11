// lib/screens/admin/route_optimization_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:water_watch/models/route_model.dart';
import 'package:water_watch/widgets/common/custom_bottom.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../widgets/common/custom_loader.dart';
import '../../widgets/admin/map_widget.dart';

class RouteOptimizationScreen extends StatefulWidget {
  const RouteOptimizationScreen({Key? key}) : super(key: key);

  @override
  _RouteOptimizationScreenState createState() => _RouteOptimizationScreenState();
}

class _RouteOptimizationScreenState extends State<RouteOptimizationScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isOptimizing = false;
  bool _showMap = true;
  List<ReportModel> _allReports = [];
  List<ReportModel> _selectedReports = [];
  RouteModel? _optimizedRoute;
  GeoPoint? _currentLocation;
  String _errorMessage = '';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AuthService _authService;
  late DatabaseService _databaseService;
  late LocationService _locationService;
  late ApiService _apiService;
  
  final MapController _mapController = MapController();
  
  @override
  void initState() {
    super.initState();
    
    // Initialize services
    _authService = Provider.of<AuthService>(context, listen: false);
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _locationService = Provider.of<LocationService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    
    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    // Start loading data after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Get current location
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        final currentLocation = GeoPoint(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        
        // Get unresolved reports
        final reports = await _databaseService.getUnresolvedReportsList();
        
        setState(() {
          _currentLocation = currentLocation;
          _allReports = reports;
          _isLoading = false;
        });
        
        _animationController.forward();
      } else {
        setState(() {
          _errorMessage = 'Failed to get current location. Please check location permissions.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _optimizeRoute() async {
    if (_selectedReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one report'),
        ),
      );
      return;
    }
    
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current location is required'),
        ),
      );
      return;
    }
    
    setState(() {
      _isOptimizing = true;
      _errorMessage = '';
    });
    
    try {
      final optimizedRoute = await _apiService.getOptimizedRoute(
        _selectedReports,
        _currentLocation!,
        _authService.currentUser!.uid,
      );
      
      setState(() {
        _optimizedRoute = optimizedRoute;
        _isOptimizing = false;
        _showMap = true; // Switch to map view
      });
      
      // Save route to database
      await _databaseService.createRoute(optimizedRoute);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route optimized successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error optimizing route: $e';
        _isOptimizing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $_errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _toggleReportSelection(ReportModel report) {
    setState(() {
      if (_isReportSelected(report)) {
        _selectedReports.removeWhere((r) => r.id == report.id);
      } else {
        _selectedReports.add(report);
      }
      
      // Reset optimized route when selection changes
      _optimizedRoute = null;
    });
  }
  
  bool _isReportSelected(ReportModel report) {
    return _selectedReports.any((r) => r.id == report.id);
  }
  
  void _toggleViewMode() {
    setState(() {
      _showMap = !_showMap;
    });
  }
  
  void _selectAllReports() {
    setState(() {
      if (_selectedReports.length == _allReports.length) {
        // Deselect all
        _selectedReports.clear();
      } else {
        // Select all
        _selectedReports = List.from(_allReports);
      }
      
      // Reset optimized route
      _optimizedRoute = null;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Optimization'),
        actions: [
          // Toggle view button
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            onPressed: _toggleViewMode,
            tooltip: _showMap ? 'Show List' : 'Show Map',
          ),
          
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: WaterDropLoader(
                message: 'Getting location and reports...',
              ),
            )
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _showMap
                  ? _buildMapView()
                  : _buildListView(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: AppTheme.errorColor.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          const Text(
            'Error Loading Data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Try Again',
            onPressed: _loadInitialData,
            icon: Icons.refresh,
            type: CustomButtonType.primary,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMapView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Map section
          Expanded(
            child: _optimizedRoute != null
                ? _buildOptimizedRouteMap()
                : _buildReportsMap(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOptimizedRouteMap() {
    // This would be implemented using the actual map widget in a real app
    // For this example, we'll use a placeholder
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.map,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Optimized Route Map',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total Distance: ${_optimizedRoute!.totalDistance.toStringAsFixed(2)} km',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'View Route Details',
              onPressed: () {
                // Show route details dialog
                _showRouteDetailsDialog();
              },
              icon: Icons.info,
              type: CustomButtonType.outline,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReportsMap() {
    // This would be implemented using the actual map widget in a real app
    // For this example, we'll use a placeholder
    return Container(
      color: Colors.grey[200],
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.map,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reports Map View',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select reports below to create a route',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          
          // Selection counter badge
          if (_selectedReports.isNotEmpty)
            Positioned(
              top: 16,
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
                  '${_selectedReports.length} reports selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildListView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Selection header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Reports (${_selectedReports.length}/${_allReports.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _selectAllReports,
                  child: Text(
                    _selectedReports.length == _allReports.length
                        ? 'Deselect All'
                        : 'Select All',
                  ),
                ),
              ],
            ),
          ),
          
          // Reports list
          Expanded(
            child: _allReports.isEmpty
                ? _buildEmptyReportsList()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _allReports.length,
                    itemBuilder: (context, index) {
                      final report = _allReports[index];
                      return _buildReportItem(report);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyReportsList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 80,
            color: AppTheme.successColor.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Pending Reports',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All reports have been resolved',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReportItem(ReportModel report) {
    final isSelected = _isReportSelected(report);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: AppTheme.primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _toggleReportSelection(report),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected 
                      ? AppTheme.primaryColor
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected 
                        ? AppTheme.primaryColor
                        : Colors.grey,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
              
              const SizedBox(width: 12),
              
              // Report info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.address,
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getWaterQualityColor(report.waterQuality).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getWaterQualityColor(report.waterQuality),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _getWaterQualityText(report.waterQuality),
                            style: TextStyle(
                              color: _getWaterQualityColor(report.waterQuality),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Distance (if optimized)
              if (_optimizedRoute != null)
                Text(
                  _getDistanceToReport(report),
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: _isOptimizing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Optimizing route...'),
                ],
              ),
            )
          : CustomButton(
              text: _optimizedRoute == null
                  ? 'Optimize Route (${_selectedReports.length})'
                  : 'Recalculate Route',
              onPressed: _selectedReports.isEmpty ? null : _optimizeRoute,
              icon: Icons.route,
              isFullWidth: true,
              type: CustomButtonType.primary,
            ),
    );
  }
  
  void _showRouteDetailsDialog() {
    if (_optimizedRoute == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Route Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Distance: ${_optimizedRoute!.totalDistance.toStringAsFixed(2)} km',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              const Text(
                'Route Segments:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // List route segments
              ..._optimizedRoute!.segments.asMap().entries.map((entry) {
                final i = entry.key;
                final segment = entry.value;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primaryColor,
                                ),
                                child: Center(
                                  child: Text(
                                    (i + 1).toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      segment.from.label ?? segment.from.address,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      segment.from.address,
                                      style: TextStyle(
                                        color: AppTheme.textSecondaryColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          // Distance indicator
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${segment.distance.toStringAsFixed(2)} km',
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Destination
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == _optimizedRoute!.segments.length - 1
                                      ? AppTheme.successColor
                                      : AppTheme.primaryLightColor,
                                ),
                                child: Center(
                                  child: Icon(
                                    i == _optimizedRoute!.segments.length - 1
                                        ? Icons.flag
                                        : Icons.arrow_downward,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      segment.to.label ?? segment.to.address,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      segment.to.address,
                                      style: TextStyle(
                                        color: AppTheme.textSecondaryColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
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
          
          // Navigate button (for a real app, this would launch a maps app)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Navigation feature coming soon!'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            child: const Text('Navigate'),
          ),
        ],
      ),
    );
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
  
  String _getDistanceToReport(ReportModel report) {
    // In a real app, this would calculate the distance from current location to report
    // For this example, we'll return a placeholder value
    return '2.3 km';
  }
}