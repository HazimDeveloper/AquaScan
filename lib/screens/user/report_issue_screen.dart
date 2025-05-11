
// lib/screens/user/report_issue_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../widgets/common/custom_loader.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({Key? key}) : super(key: key);

  @override
  _ReportIssueScreenState createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  
  List<File> _images = [];
  bool _isLoading = false;
  bool _isDetecting = false;
  WaterQualityState _detectedQuality = WaterQualityState.unknown;
  
  late AuthService _authService;
  late DatabaseService _databaseService;
  late StorageService _storageService;
  late LocationService _locationService;
  late ApiService _apiService;
  
  GeoPoint? _location;
  String? _autoAddress;
  
  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _storageService = Provider.of<StorageService>(context, listen: false);
    _locationService = Provider.of<LocationService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    
    _getCurrentLocation();
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        final address = await _locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        setState(() {
          _location = _locationService.positionToGeoPoint(position);
          _autoAddress = address;
          _addressController.text = address;
          _isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get location. Please check permissions.'),
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
        ),
      );
    }
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    
    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
      });
      
      // Detect water quality
      _detectWaterQuality(File(pickedFile.path));
    }
  }
  
  Future<void> _detectWaterQuality(File image) async {
    try {
      setState(() {
        _isDetecting = true;
      });
      
      final quality = await _apiService.analyzeWaterQuality(image);
      
      setState(() {
        _detectedQuality = quality;
        _isDetecting = false;
      });
    } catch (e) {
      setState(() {
        _isDetecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error detecting water quality: $e'),
        ),
      );
    }
  }
  
  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      
      // Reset detection if all images are removed
      if (_images.isEmpty) {
        _detectedQuality = WaterQualityState.unknown;
      }
    });
  }
  
  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      if (_location == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location is required. Please try again.'),
          ),
        );
        return;
      }
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Get current user
        final user = await _authService.getUserData(_authService.currentUser!.uid);
        
        // Upload images
        List<String> imageUrls = [];
        if (_images.isNotEmpty) {
          imageUrls = await _storageService.uploadImages(_images, 'reports');
        }
        
        // Create report
        final now = DateTime.now();
        final report = ReportModel(
          id: '',  // Will be set by Firestore
          userId: user.uid,
          userName: user.name,
          title: _titleController.text,
          description: _descriptionController.text,
          location: _location!,
          address: _addressController.text,
          imageUrls: imageUrls,
          waterQuality: _detectedQuality,
          isResolved: false,
          createdAt: now,
          updatedAt: now,
        );
        
        await _databaseService.createReport(report);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        
        // Go back to previous screen
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting report: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  String _getWaterQualityText() {
    switch (_detectedQuality) {
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
  
  Color _getWaterQualityColor() {
    switch (_detectedQuality) {
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Water Issue'),
      ),
      body: _isLoading 
        ? Center(
            child: WaterFillLoader(
              message: 'Processing your report...',
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image picker section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Photos (Optional)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Adding photos helps us analyze the water quality more accurately',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Image grid
                          if (_images.isNotEmpty)
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: _images.length,
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: FileImage(_images[index]),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () => _removeImage(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          
                          const SizedBox(height: 16),
                          
                          // Add photo button
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Take Photo'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          
                          // Water quality detection result
                          if (_isDetecting)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (_detectedQuality != WaterQualityState.unknown)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _getWaterQualityColor().withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getWaterQualityColor(),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.water_drop,
                                      color: _getWaterQualityColor(),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Detected Water Quality: ${_getWaterQualityText()}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _getWaterQualityColor(),
                                            ),
                                          ),
                                          if (_detectedQuality != WaterQualityState.unknown)
                                            Text(
                                              'Our AI has analyzed your image and determined this quality level',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textSecondaryColor,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Report details section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Issue Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Title field
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              hintText: 'Brief title for the issue',
                              prefixIcon: Icon(Icons.title),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a title';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Description field
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText: 'Describe the water issue in detail',
                              prefixIcon: Icon(Icons.description),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a description';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Address field
                          TextFormField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: 'Address',
                              hintText: 'Location of the issue',
                              prefixIcon: const Icon(Icons.location_on),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: _getCurrentLocation,
                                tooltip: 'Use current location',
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an address';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitReport,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Submit Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}