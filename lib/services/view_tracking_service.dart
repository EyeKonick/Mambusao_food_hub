// lib/services/view_tracking_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';

/// Service for tracking business views
/// 
/// Increments viewCount atomically when users visit business details page
class ViewTrackingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Track a business view
  /// 
  /// - Increments viewCount atomically using FieldValue.increment
  /// - Creates a view record in subcollection for detailed analytics
  /// - Works for both authenticated and anonymous users
  static Future<void> trackBusinessView(String businessId) async {
    try {
      final user = _auth.currentUser;
      final userId = user?.uid ?? 'anonymous';
      
      // Reference to business document
      final businessRef = _firestore
          .collection(AppConfig.businessesCollection)
          .doc(businessId);

      // Use a batch to ensure atomic operations
      final batch = _firestore.batch();

      // Increment viewCount atomically
      batch.update(businessRef, {
        'viewCount': FieldValue.increment(1),
      });

      // Create detailed view record in subcollection
      final viewRef = businessRef.collection('views').doc();
      batch.set(viewRef, {
        'userId': userId,
        'viewedAt': FieldValue.serverTimestamp(),
      });

      // Commit batch
      await batch.commit();

      if (AppConfig.enableDebugMode) {
        print('✓ View tracked for business: $businessId (userId: $userId)');
      }
    } catch (e) {
      // If viewCount field doesn't exist, initialize it
      if (e.toString().contains('NOT_FOUND') || 
          e.toString().contains('No document to update')) {
        try {
          final user = _auth.currentUser;
          final userId = user?.uid ?? 'anonymous';
          
          await _firestore
              .collection(AppConfig.businessesCollection)
              .doc(businessId)
              .set({
            'viewCount': 1,
          }, SetOptions(merge: true));

          // Also create the view record
          await _firestore
              .collection(AppConfig.businessesCollection)
              .doc(businessId)
              .collection('views')
              .add({
            'userId': userId,
            'viewedAt': FieldValue.serverTimestamp(),
          });

          if (AppConfig.enableDebugMode) {
            print('✓ View count initialized for business: $businessId');
          }
        } catch (initError) {
          if (AppConfig.enableDebugMode) {
            print('✗ Error initializing view count: $initError');
          }
        }
      } else {
        if (AppConfig.enableDebugMode) {
          print('✗ Error tracking view: $e');
        }
      }
    }
  }

  /// Get view count for a business
  static Future<int> getViewCount(String businessId) async {
    try {
      final doc = await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(businessId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('viewCount')) {
          return (data['viewCount'] as num?)?.toInt() ?? 0;
        }
      }
      return 0;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        print('✗ Error getting view count: $e');
      }
      return 0;
    }
  }
}