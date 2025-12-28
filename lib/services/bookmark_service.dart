import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../config/app_config.dart';

class BookmarkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if a business is bookmarked by current user
  Future<bool> isBookmarked(String businessId) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;

    try {
      final bookmarkQuery = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.uid)
          .collection(AppConfig.bookmarksSubcollection)
          .where('businessId', isEqualTo: businessId)
          .limit(1)
          .get();

      return bookmarkQuery.docs.isNotEmpty;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        print('Error checking bookmark: $e');
      }
      return false;
    }
  }

  // Stream to watch bookmark status for a business
  Stream<bool> watchBookmarkStatus(String businessId) {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      return Stream.value(false);
    }

    return _firestore
        .collection(AppConfig.usersCollection)
        .doc(user.uid)
        .collection(AppConfig.bookmarksSubcollection)
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  /// Get a stream of bookmark status for a specific establishment
  Stream<bool> isBookmarkedStream(String businessId) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return Stream.value(false);
    }

    return _firestore
        .collection(AppConfig.usersCollection)
        .doc(user.uid)
        .collection(AppConfig.bookmarksSubcollection)
        .doc(businessId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  // Add bookmark
  Future<bool> addBookmark({
    required String businessId,
    required String businessName,
    required String businessType,
    String? label,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      return false; // Must be authenticated
    }

    try {
      // Check if already bookmarked
      final existing = await isBookmarked(businessId);
      if (existing) {
        if (AppConfig.enableDebugMode) {
          debugPrint('Business already bookmarked');
        }
        return true;
      }

      // Use batch for atomic operations
      final batch = _firestore.batch();

      // Add bookmark to user's subcollection
      final bookmarkRef = _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.uid)
          .collection(AppConfig.bookmarksSubcollection)
          .doc(businessId);

      batch.set(bookmarkRef, {
        'businessId': businessId,
        'businessName': businessName,
        'businessType': businessType,
        'label': label,
        'bookmarkedAt': FieldValue.serverTimestamp(),
      });

      // INCREMENT bookmarkCount in business document
      final businessRef = _firestore
          .collection(AppConfig.businessesCollection)
          .doc(businessId);

      batch.update(businessRef, {
        'bookmarkCount': FieldValue.increment(1),
      });

      // Commit batch
      await batch.commit();

      if (AppConfig.enableDebugMode) {
        debugPrint('✓ Bookmark added and count incremented for business: $businessId');
      }

      return true;
    } catch (e) {
      // If bookmarkCount doesn't exist, initialize it
      if (e.toString().contains('NOT_FOUND')) {
        try {
          await _firestore
              .collection(AppConfig.businessesCollection)
              .doc(businessId)
              .set({
            'bookmarkCount': 1,
          }, SetOptions(merge: true));

          // Retry the bookmark addition
          return await addBookmark(
            businessId: businessId,
            businessName: businessName,
            businessType: businessType,
            label: label,
          );
        } catch (initError) {
          if (AppConfig.enableDebugMode) {
            debugPrint('✗ Error initializing bookmark count: $initError');
          }
          return false;
        }
      }

      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error adding bookmark: $e');
      }
      return false;
    }
  }

  // Remove bookmark
  Future<bool> removeBookmark(String businessId) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;

    try {
      // Use batch for atomic operations
      final batch = _firestore.batch();

      // Remove bookmark from user's subcollection
      final bookmarkRef = _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.uid)
          .collection(AppConfig.bookmarksSubcollection)
          .doc(businessId);

      batch.delete(bookmarkRef);

      // DECREMENT bookmarkCount in business document
      final businessRef = _firestore
          .collection(AppConfig.businessesCollection)
          .doc(businessId);

      batch.update(businessRef, {
        'bookmarkCount': FieldValue.increment(-1),
      });

      // Commit batch
      await batch.commit();

      if (AppConfig.enableDebugMode) {
        debugPrint('✓ Bookmark removed and count decremented for business: $businessId');
      }

      return true;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error removing bookmark: $e');
      }
      return false;
    }
  }

  // Toggle bookmark (add if not bookmarked, remove if bookmarked)
  Future<bool> toggleBookmark({
    required String businessId,
    required String businessName,
    required String businessType,
    String? label,
  }) async {
    final isCurrentlyBookmarked = await isBookmarked(businessId);

    if (isCurrentlyBookmarked) {
      return await removeBookmark(businessId);
    } else {
      return await addBookmark(
        businessId: businessId,
        businessName: businessName,
        businessType: businessType,
        label: label,
      );
    }
  }

  // Get all bookmarks for current user
  Stream<List<Map<String, dynamic>>> getUserBookmarks() {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConfig.usersCollection)
        .doc(user.uid)
        .collection(AppConfig.bookmarksSubcollection)
        .orderBy('bookmarkedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Get bookmark count for user
  Future<int> getBookmarkCount() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return 0;

    try {
      final snapshot = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.uid)
          .collection(AppConfig.bookmarksSubcollection)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        print('Error getting bookmark count: $e');
      }
      return 0;
    }
  }

  // Update bookmark label
  Future<bool> updateBookmarkLabel(String businessId, String? newLabel) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;

    try {
      final bookmarkQuery = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.uid)
          .collection(AppConfig.bookmarksSubcollection)
          .where('businessId', isEqualTo: businessId)
          .get();

      if (bookmarkQuery.docs.isEmpty) return false;

      // Update the label
      await bookmarkQuery.docs.first.reference.update({
        'label': newLabel,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (AppConfig.enableDebugMode) {
        print('Bookmark label updated successfully');
      }
      return true;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        print('Error updating bookmark label: $e');
      }
      return false;
    }
  }
}