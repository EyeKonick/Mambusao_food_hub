import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

class GalleryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload image to Cloudinary and return URL
  Future<String?> uploadPhoto(File imageFile) async {
    try {
      final url = Uri.parse(AppConfig.cloudinaryApiUrl);
      final request = http.MultipartRequest('POST', url);

      // Add fields
      request.fields['upload_preset'] = AppConfig.cloudinaryUploadPreset;
      request.fields['folder'] = 'business_gallery';

      // Add image file
      final imageBytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'gallery_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      request.files.add(multipartFile);

      // Send request
      final response = await request.send();
      
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);
        return jsonData['secure_url'];
      }
      
      return null;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        print('Error uploading photo: $e');
      }
      return null;
    }
  }

  /// Add photo to business gallery
  Future<bool> addPhotoToGallery({
    required String businessId,
    required String photoUrl,
    String? caption,
  }) async {
    try {
      await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(businessId)
          .collection('gallery')
          .add({
        'photoUrl': photoUrl,
        'caption': caption,
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadedBy': _auth.currentUser?.uid,
      });
      
      return true;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        print('Error adding photo to gallery: $e');
      }
      return false;
    }
  }

  /// Get all photos for a business
  Stream<List<Map<String, dynamic>>> getBusinessGallery(String businessId) {
    return _firestore
        .collection(AppConfig.businessesCollection)
        .doc(businessId)
        .collection('gallery')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Delete photo from gallery
  Future<bool> deletePhoto({
    required String businessId,
    required String photoId,
  }) async {
    try {
      await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(businessId)
          .collection('gallery')
          .doc(photoId)
          .delete();
      
      return true;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        print('Error deleting photo: $e');
      }
      return false;
    }
  }

  /// Get photo count for a business
  Future<int> getPhotoCount(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(businessId)
          .collection('gallery')
          .count()
          .get();
      
      return snapshot.count ?? 0;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        print('Error getting photo count: $e');
      }
      return 0;
    }
  }

  /// Update photo caption
  Future<bool> updateCaption({
    required String businessId,
    required String photoId,
    required String caption,
  }) async {
    try {
      await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(businessId)
          .collection('gallery')
          .doc(photoId)
          .update({
        'caption': caption,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        print('Error updating caption: $e');
      }
      return false;
    }
  }
}