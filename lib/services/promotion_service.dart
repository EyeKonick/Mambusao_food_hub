import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';
import '../models/promotion_model.dart';

class PromotionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get promotions collection reference
  CollectionReference get _promotionsCollection {
    return _firestore.collection('promotions');
  }

  // Create new promotion
  Future<bool> createPromotion({
    required String businessId,
    required String businessName,
    required String title,
    required String description,
    String? imageUrl,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      await _promotionsCollection.add({
        'businessId': businessId,
        'businessName': businessName,
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (AppConfig.enableDebugMode) {
        print('✓ Promotion created successfully');
      }
      return true;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        print('✗ Error creating promotion: $e');
      }
      return false;
    }
  }

  // Update promotion
  Future<bool> updatePromotion({
    required String promotionId,
    String? title,
    String? description,
    String? imageUrl,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) async {
    try {
      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;
      if (startDate != null) updates['startDate'] = Timestamp.fromDate(startDate);
      if (endDate != null) updates['endDate'] = Timestamp.fromDate(endDate);
      if (isActive != null) updates['isActive'] = isActive;

      await _promotionsCollection.doc(promotionId).update(updates);

      if (AppConfig.enableDebugMode) {
        print('✓ Promotion updated successfully');
      }
      return true;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        print('✗ Error updating promotion: $e');
      }
      return false;
    }
  }

  // Delete promotion
  Future<bool> deletePromotion(String promotionId) async {
    try {
      await _promotionsCollection.doc(promotionId).delete();

      if (AppConfig.enableDebugMode) {
        print('✓ Promotion deleted successfully');
      }
      return true;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        print('✗ Error deleting promotion: $e');
      }
      return false;
    }
  }

  // Toggle promotion active status
  Future<bool> togglePromotionStatus(String promotionId, bool isActive) async {
    return await updatePromotion(
      promotionId: promotionId,
      isActive: isActive,
    );
  }

  // Get all promotions for a business
  Stream<List<Promotion>> getBusinessPromotions(String businessId) {
    return _promotionsCollection
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Promotion.fromFirestore(doc))
          .toList();
    });
  }

  // Get active promotions for a business
  Stream<List<Promotion>> getActiveBusinessPromotions(String businessId) {
    final now = Timestamp.now();
    return _promotionsCollection
        .where('businessId', isEqualTo: businessId)
        .where('isActive', isEqualTo: true)
        .where('endDate', isGreaterThan: now)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Promotion.fromFirestore(doc))
          .where((promo) => promo.isValid)
          .toList();
    });
  }

  // Get all active promotions (for home page)
  Stream<List<Promotion>> getAllActivePromotions() {
    final now = Timestamp.now();
    return _promotionsCollection
        .where('isActive', isEqualTo: true)
        .where('endDate', isGreaterThan: now)
        .limit(20) // Limit to 20 most recent
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Promotion.fromFirestore(doc))
          .where((promo) => promo.isValid)
          .toList();
    });
  }

  // Get active promotion count for business
  Future<int> getActivePromotionCount(String businessId) async {
    try {
      final now = Timestamp.now();
      final snapshot = await _promotionsCollection
          .where('businessId', isEqualTo: businessId)
          .where('isActive', isEqualTo: true)
          .where('endDate', isGreaterThan: now)
          .get();

      return snapshot.docs
          .map((doc) => Promotion.fromFirestore(doc))
          .where((promo) => promo.isValid)
          .length;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        print('✗ Error getting promotion count: $e');
      }
      return 0;
    }
  }
}