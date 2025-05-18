// lib/screens/admin/report_list_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:water_watch/widgets/common/custom_bottom.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/database_service.dart';
import '../../services/api_service.dart'; // Import for confidence scores
import '../../widgets/common/custom_loader.dart';
import '../../utils/water_quality_utils.dart'; // Import for water quality utilities

class ReportListScreen extends StatefulWidget {
  final bool? showResolved;
  
  const ReportListScreen({
    Key? key,
    this.showResolved,
  }) : super(key: key);

  @override
  _ReportListScreenState createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<ReportModel> _pendingReports = [];
  List<ReportModel> _resolvedReports = [];
  String _errorMessage = '';
  String _searchQuery = '';
  
  // Map to store confidence scores for each report
  Map<String, double> _confidenceScores = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.showResolved == true ? 1 : 0,
    );
    
    // Load reports after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReports();
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      // Load both report types
      final pendingReports = await databaseService.getUnresolvedReportsList();
      final resolvedReports = await databaseService.getResolvedReportsList();
      
      // Log report data for debugging
      for (var report in [...pendingReports, ...resolvedReports]) {
        print('Report ID: ${report.id}');
        print('Report title: ${report.title}');
        print('Report has ${report.imageUrls.length} images');
        if (report.imageUrls.isNotEmpty) {
          print('First image URL: ${report.imageUrls.first}');
        }
      }
      
      // Initialize confidence scores map
      Map<String, double> confidenceMap = {};
      
      // For reports with images, try to get confidence scores
      final allReports = [...pendingReports, ...resolvedReports];
      for (var report in allReports) {
        if (report.imageUrls.isNotEmpty) {
          try {
            // In a real implementation, you would fetch the actual confidence
            // This is a simulated confidence value based on the report ID
            // In a real app, you would call: 
            // final analysis = await apiService.getWaterQualityAnalysis(report.id);
            // confidenceMap[report.id] = analysis.confidence;
            
            // For demo purposes, generate a confidence between 60-95%
            final confidence = 60.0 + (report.id.hashCode % 35);
            confidenceMap[report.id] = confidence;
          } catch (e) {
            // If analysis fails, set a default confidence
            confidenceMap[report.id] = 0.0;
            print('Error getting confidence for report ${report.id}: $e');
          }
        } else {
          // No image, no confidence score - just use the state assigned during report creation
          confidenceMap[report.id] = 0.0;
        }
      }
      
      setState(() {
        _pendingReports = pendingReports;
        _resolvedReports = resolvedReports;
        _confidenceScores = confidenceMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      print('Error loading reports: $e');
    }
  }
  
  List<ReportModel> _getFilteredReports(List<ReportModel> reports) {
    if (_searchQuery.isEmpty) {
      return reports;
    }
    
    final query = _searchQuery.toLowerCase();
    return reports.where((report) {
      return report.title.toLowerCase().contains(query) ||
             report.description.toLowerCase().contains(query) ||
             report.address.toLowerCase().contains(query) ||
             report.userName.toLowerCase().contains(query);
    }).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Quality Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Resolved'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: WaterFillLoader(
                message: 'Loading reports...',
              ),
            )
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search reports',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    
                    // Tab content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Pending reports tab
                          _buildReportsList(_getFilteredReports(_pendingReports), isPending: true),
                          
                          // Resolved reports tab
                          _buildReportsList(_getFilteredReports(_resolvedReports), isPending: false),
                        ],
                      ),
                    ),
                  ],
                ),
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
            'Error Loading Reports',
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
            onPressed: _loadReports,
            icon: Icons.refresh,
            type: CustomButtonType.primary,
          ),
        ],
      ),
    );
  }
  
  Widget _buildReportsList(List<ReportModel> reports, {required bool isPending}) {
    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.check_circle : Icons.history,
              size: 80,
              color: isPending
                  ? AppTheme.successColor.withOpacity(0.7)
                  : AppTheme.primaryColor.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              isPending
                  ? 'No Pending Reports'
                  : 'No Resolved Reports',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPending
                  ? 'All reports have been resolved'
                  : 'Resolved reports will appear here',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final report = reports[index];
          return _buildReportItem(report, isPending);
        },
      ),
    );
  }
  
  Widget _buildReportItem(ReportModel report, bool isPending) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final formattedDate = dateFormat.format(report.createdAt);
    
    // Get confidence score for this report
    final confidenceScore = _confidenceScores[report.id] ?? 0.0;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _showReportDetailsDialog(report, isPending, confidenceScore);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with image thumbnail and title/status info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image thumbnail (if available)
                  if (report.imageUrls.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: Image.network(
                          report.imageUrls.first,
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
                              child: const Icon(
                                Icons.error_outline,
                                color: Colors.grey,
                                size: 30,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  // Show placerholder icon if no image
                  if (report.imageUrls.isEmpty)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 30,
                        color: Colors.grey[400],
                      ),
                    ),
                    
                  const SizedBox(width: 16),
                  
                  // Title, status, quality info section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          report.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Status and quality indicators in a row
                        Row(
                          children: [
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isPending
                                    ? AppTheme.warningColor
                                    : AppTheme.successColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isPending ? 'Pending' : 'Resolved',
                                style: TextStyle(
                                  color: isPending ? Colors.black87 : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 6),
                            
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
                                    _getWaterQualityIcon(report.waterQuality),
                                    color: _getWaterQualityColor(report.waterQuality),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getWaterQualityText(report.waterQuality),
                                    style: TextStyle(
                                      color: _getWaterQualityColor(report.waterQuality),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        // Only show confidence if it's significant (over 50%)
                        if (confidenceScore > 50)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      LinearProgressIndicator(
                                        value: confidenceScore / 100,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          _getWaterQualityColor(report.waterQuality),
                                        ),
                                        minHeight: 4,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Confidence: ${confidenceScore.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Description section
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Text(
                report.description,
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Location, user, and date info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  // Location info
                  Expanded(
                    child: Row(
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
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // User info
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        report.userName,
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Date info
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showReportDetailsDialog(ReportModel report, bool isPending, double confidence) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                              if (report.imageUrls.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: PageView.builder(
                      itemCount: report.imageUrls.length,
                      itemBuilder: (context, index) {
                        // Debug info
                        print('Loading dialog image from URL: ${report.imageUrls[index]}');
                        
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
                            // Log error for debugging
                            print('Error loading dialog image: $error');
                            return Container(
                              color: Colors.grey[200],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 50,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Image could not be loaded',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Error: ${error.toString().substring(0, min(50, error.toString().length))}...',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
              
              const SizedBox(height: 16),
              
              // Status indicators
              Row(
                children: [
                  // Resolved/Pending status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isPending
                          ? AppTheme.warningColor
                          : AppTheme.successColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isPending ? 'Pending' : 'Resolved',
                      style: TextStyle(
                        color: isPending ? Colors.black87 : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Water quality info
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
                          _getWaterQualityIcon(report.waterQuality),
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
                ],
              ),
              
              // Confidence indicator (if images exist and confidence > 0)
              if (report.imageUrls.isNotEmpty && confidence > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Analysis Confidence',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: confidence / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getWaterQualityColor(report.waterQuality),
                        ),
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${confidence.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getWaterQualityColor(report.waterQuality),
                          ),
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
                'Address',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(report.address),
              
              const SizedBox(height: 16),
              
              // Reporter info
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
              
              // Date info
              const Text(
                'Report Date',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(DateFormat('MMMM d, yyyy, h:mm a').format(report.createdAt)),
              
              // Water quality description
              const SizedBox(height: 16),
              const Text(
                'Water Quality Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getWaterQualityColor(report.waterQuality).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getWaterQualityColor(report.waterQuality).withOpacity(0.3),
                  ),
                ),
                child: Text(_getWaterQualityDescription(report.waterQuality)),
              ),
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
          
          // Resolve button (if pending)
          if (isPending)
            CustomButton(
              text: 'Mark as Resolved',
              onPressed: () {
                _markReportAsResolved(report);
              },
              type: CustomButtonType.success,
              size: CustomButtonSize.small,
            ),
        ],
      ),
    );
  }
  
  Future<void> _markReportAsResolved(ReportModel report) async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    
    try {
      await databaseService.resolveReport(report.id);
      
      if (mounted) {
        Navigator.pop(context); // Close dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report marked as resolved'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh reports
        _loadReports();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  String _getWaterQualityText(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return 'Optimum';
      case WaterQualityState.highPh:
        return 'High pH';
      case WaterQualityState.highPhTemp:
        return 'High pH & Temp';
      case WaterQualityState.lowPh:
        return 'Low pH';
      case WaterQualityState.lowTemp:
        return 'Low Temperature';
      case WaterQualityState.lowTempHighPh:
        return 'Low Temp & High pH';
      case WaterQualityState.unknown:
      default:
        return 'Unknown';
    }
  }
  
  Color _getWaterQualityColor(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return Colors.blue;
      case WaterQualityState.lowTemp:
        return Colors.green;
      case WaterQualityState.highPh:
      case WaterQualityState.lowPh:
        return Colors.orange;
      case WaterQualityState.highPhTemp:
        return Colors.red;
      case WaterQualityState.lowTempHighPh:
        return Colors.purple;
      case WaterQualityState.unknown:
      default:
        return Colors.grey;
    }
  }
  
  IconData _getWaterQualityIcon(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return Icons.check_circle;
      case WaterQualityState.lowTemp:
        return Icons.ac_unit;
      case WaterQualityState.highPh:
      case WaterQualityState.lowPh:
        return Icons.science;
      case WaterQualityState.highPhTemp:
        return Icons.whatshot;
      case WaterQualityState.lowTempHighPh:
        return Icons.warning;
      case WaterQualityState.unknown:
      default:
        return Icons.help_outline;
    }
  }
  
  String _getWaterQualityDescription(WaterQualityState quality) {
    switch (quality) {
      case WaterQualityState.optimum:
        return 'The water has optimal pH and temperature levels for general use.';
      case WaterQualityState.highPh:
        return 'The water has high pH levels and may be alkaline. May cause skin irritation or affect taste.';
      case WaterQualityState.highPhTemp:
        return 'The water has both high pH and temperature. Not recommended for direct use.';
      case WaterQualityState.lowPh:
        return 'The water has low pH levels and may be acidic. May cause corrosion or affect taste.';
      case WaterQualityState.lowTemp:
        return 'The water has lower than optimal temperature but otherwise may be suitable for use.';
      case WaterQualityState.lowTempHighPh:
        return 'The water has low temperature and high pH levels. Use with caution.';
      case WaterQualityState.unknown:
      default:
        return 'Water quality status is unknown or could not be determined.';
    }
  }
}