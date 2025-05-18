// lib/services/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final bool _debugMode = true; // Enable debug logging
  
  // Helper method for debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      print('🔥 StorageService: $message');
    }
  }
  
  // Upload an image to Firebase Storage
  Future<String> uploadImage(File file, String folder) async {
    try {
      _logDebug('Starting upload for file: ${file.path}');
      
      // Check if file exists and is readable
      if (!file.existsSync()) {
        _logDebug('Error: File does not exist: ${file.path}');
        throw Exception('File does not exist: ${file.path}');
      }
      
      final fileSize = await file.length();
      _logDebug('File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
      
      // Generate a unique filename
      final uuid = Uuid();
      final extension = path.extension(file.path);
      final fileName = '${uuid.v4()}$extension';
      _logDebug('Generated filename: $fileName in folder: $folder');
      
      // Create reference
      final storageRef = _storage.ref().child('$folder/$fileName');
      _logDebug('Storage reference created: ${storageRef.fullPath}');
      
      // Upload file
      try {
        _logDebug('Starting file upload to Firebase...');
        final uploadTask = storageRef.putFile(file);
        
        // Monitor upload progress
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          _logDebug('Upload progress: ${progress.toStringAsFixed(1)}%');
        }, onError: (e) {
          _logDebug('Upload snapshot error: $e');
        });
        
        final snapshot = await uploadTask.whenComplete(() {
          _logDebug('Upload completed successfully');
        });
        
        // Get download URL
        final downloadUrl = await snapshot.ref.getDownloadURL();
        _logDebug('Download URL obtained: $downloadUrl');
        return downloadUrl;
      } catch (e) {
        _logDebug('Error during Firebase upload: $e');
        throw Exception('Failed to upload to Firebase: $e');
      }
    } catch (e) {
      _logDebug('Error in uploadImage: $e');
      throw Exception('Failed to upload image: $e');
    }
  }
  
  // Upload multiple images
  Future<List<String>> uploadImages(List<File> files, String folder) async {
    _logDebug('Starting upload of ${files.length} images to folder: $folder');
    
    if (files.isEmpty) {
      _logDebug('No files to upload, returning empty list');
      return [];
    }
    
    try {
      final List<String> urls = [];
      
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        try {
          if (file.existsSync()) {
            _logDebug('Processing file ${i+1}/${files.length}: ${file.path}');
            final fileSize = await file.length();
            _logDebug('File ${i+1} size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
            
            final url = await uploadImage(file, folder);
            _logDebug('File ${i+1} uploaded successfully, URL: $url');
            urls.add(url);
          } else {
            _logDebug('Skipping non-existent file ${i+1}: ${file.path}');
          }
        } catch (e) {
          _logDebug('Error uploading file ${i+1} (${file.path}): $e');
          // Continue with next file instead of failing the entire batch
        }
      }
      
      _logDebug('Finished uploading ${urls.length}/${files.length} files');
      return urls;
    } catch (e) {
      _logDebug('Error in uploadImages: $e');
      throw Exception('Failed to upload images: $e');
    }
  }
  
  // Delete an image from Firebase Storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      _logDebug('Attempting to delete image: $imageUrl');
      
      // Extract file path from URL
      final ref = _storage.refFromURL(imageUrl);
      _logDebug('Resolved storage reference: ${ref.fullPath}');
      
      await ref.delete();
      _logDebug('Image deleted successfully');
    } catch (e) {
      _logDebug('Error deleting image: $e');
      throw Exception('Failed to delete image: $e');
    }
  }
  
  // Get Firebase Storage reference from URL
  Reference? getStorageRefFromUrl(String url) {
    try {
      return _storage.refFromURL(url);
    } catch (e) {
      _logDebug('Error getting reference from URL: $e');
      return null;
    }
  }
  
  // Check if a file exists in Firebase Storage
  Future<bool> fileExists(String filePath) async {
    try {
      _logDebug('Checking if file exists: $filePath');
      final ref = _storage.ref().child(filePath);
      await ref.getDownloadURL();
      _logDebug('File exists: $filePath');
      return true;
    } catch (e) {
      _logDebug('File does not exist or error: $filePath, $e');
      return false;
    }
  }
}