// lib/services/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Upload an image to Firebase Storage
  Future<String> uploadImage(File file, String folder) async {
    try {
      // Check if file exists and is readable
      if (!file.existsSync()) {
        print('Warning: File does not exist: ${file.path}');
        throw Exception('File does not exist: ${file.path}');
      }
      
      // Generate a unique filename
      final uuid = Uuid();
      final extension = path.extension(file.path);
      final fileName = '${uuid.v4()}$extension';
      
      // Create reference
      final storageRef = _storage.ref().child('$folder/$fileName');
      
      // Upload file
      try {
        final uploadTask = storageRef.putFile(file);
        final snapshot = await uploadTask.whenComplete(() => null);
        
        // Get download URL
        final downloadUrl = await snapshot.ref.getDownloadURL();
        return downloadUrl;
      } catch (e) {
        print('Error during Firebase upload: $e');
        throw Exception('Failed to upload to Firebase: $e');
      }
    } catch (e) {
      print('Error in uploadImage: $e');
      throw Exception('Failed to upload image: $e');
    }
  }
  
  // Upload multiple images
  Future<List<String>> uploadImages(List<File> files, String folder) async {
    if (files.isEmpty) {
      return [];
    }
    
    try {
      final List<String> urls = [];
      
      for (final file in files) {
        try {
          if (file.existsSync()) {
            final url = await uploadImage(file, folder);
            urls.add(url);
          } else {
            print('Skipping non-existent file: ${file.path}');
          }
        } catch (e) {
          print('Error uploading file ${file.path}: $e');
          // Continue with next file instead of failing the entire batch
        }
      }
      
      return urls;
    } catch (e) {
      print('Error in uploadImages: $e');
      throw Exception('Failed to upload images: $e');
    }
  }
  
  // Delete an image from Firebase Storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      // Extract file path from URL
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }
}