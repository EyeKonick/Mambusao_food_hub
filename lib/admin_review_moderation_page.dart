// ====================================================================
// ENHANCED ADMIN REVIEW MODERATION PAGE
// UI Enhancement Phase - Modern, Clean Design with Poppins Font
// 
// ENHANCEMENTS:
// - Modern review cards with color-coded ratings
// - Enhanced stats bar with gradient background
// - Improved empty state design
// - Better AppBar with modern sort menu
// - Consistent spacing and typography
// - Enhanced loading state
// 
// BUSINESS LOGIC: 100% PRESERVED - NO CHANGES
// ====================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';

class AdminReviewModerationPage extends StatefulWidget {
  const AdminReviewModerationPage({super.key});

  @override
  State<AdminReviewModerationPage> createState() => _AdminReviewModerationPageState();
}

class _AdminReviewModerationPageState extends State<AdminReviewModerationPage> {
  // ==================== FIREBASE & STATE ====================
  // NO CHANGES - Business logic preserved
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _sortBy = 'recent'; // 'recent', 'rating_low', 'rating_high'
  bool _isLoading = true;
  List<Map<String, dynamic>> _allReviews = [];

  @override
  void initState() {
    super.initState();
    _loadAllReviews();
  }

  // ==================== LOAD ALL REVIEWS ====================
  // NO CHANGES - Business logic preserved
  Future<void> _loadAllReviews() async {
    try {
      setState(() => _isLoading = true);

      final businessesSnapshot = await _firestore
          .collection(AppConfig.businessesCollection)
          .get();

      List<Map<String, dynamic>> reviews = [];

      for (var businessDoc in businessesSnapshot.docs) {
        final reviewsSnapshot = await _firestore
            .collection(AppConfig.businessesCollection)
            .doc(businessDoc.id)
            .collection(AppConfig.reviewsSubcollection)
            .get();

        for (var reviewDoc in reviewsSnapshot.docs) {
          final reviewData = reviewDoc.data();
          reviews.add({
            'reviewId': reviewDoc.id,
            'businessId': businessDoc.id,
            'businessName': businessDoc.data()['businessName'] ?? 'Unknown',
            'reviewerName': reviewData['reviewerName'] ?? 'Anonymous',
            'rating': (reviewData['rating'] as num?)?.toDouble() ?? 0.0,
            'comment': reviewData['comment'] ?? '',
            'timestamp': reviewData['timestamp'],
            'userId': reviewData['userId'],
          });
        }
      }

      setState(() {
        _allReviews = reviews;
        _isLoading = false;
      });

      _sortReviews();
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('Error loading reviews: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  // ==================== SORT REVIEWS ====================
  // NO CHANGES - Business logic preserved
  void _sortReviews() {
    setState(() {
      switch (_sortBy) {
        case 'rating_low':
          _allReviews.sort((a, b) => a['rating'].compareTo(b['rating']));
          break;
        case 'rating_high':
          _allReviews.sort((a, b) => b['rating'].compareTo(a['rating']));
          break;
        case 'recent':
        default:
          _allReviews.sort((a, b) {
            final aTime = a['timestamp'] as Timestamp?;
            final bTime = b['timestamp'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
      }
    });
  }

  // ==================== DELETE REVIEW ====================
  // ENHANCED UI - Dialog styling improved, logic preserved
  Future<void> _deleteReview(String businessId, String reviewId, String businessName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text(
          'Delete Review',
          style: AppTheme.headlineMedium,
        ),
        content: Text(
          'Permanently delete this review from $businessName?',
          style: AppTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: Text(
              'Delete',
              style: AppTheme.labelLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // NO CHANGES - Firebase delete logic preserved
    try {
      await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(businessId)
          .collection(AppConfig.reviewsSubcollection)
          .doc(reviewId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Review deleted',
                style: AppTheme.bodyMedium.copyWith(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Reload reviews
      _loadAllReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Error: $e',
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );
    }
  }

  // ==================== BUILD REVIEW CARD (ENHANCED) ====================
  Widget _buildReviewCard(Map<String, dynamic> reviewData) {
    final businessName = reviewData['businessName'];
    final reviewerName = reviewData['reviewerName'];
    final rating = reviewData['rating'];
    final comment = reviewData['comment'];
    final timestamp = reviewData['timestamp'] as Timestamp?;
    
    // NO CHANGES - Date formatting logic preserved
    String formattedDate = 'Unknown date';
    String relativeTime = '';
    if (timestamp != null) {
      final date = timestamp.toDate();
      formattedDate = '${date.day}/${date.month}/${date.year}';
      
      final diff = DateTime.now().difference(date);
      if (diff.inDays == 0) {
        relativeTime = 'Today';
      } else if (diff.inDays == 1) {
        relativeTime = 'Yesterday';
      } else if (diff.inDays < 7) {
        relativeTime = '${diff.inDays} days ago';
      } else if (diff.inDays < 30) {
        relativeTime = '${(diff.inDays / 7).floor()} weeks ago';
      } else {
        relativeTime = '${(diff.inDays / 30).floor()} months ago';
      }
    }

    // NO CHANGES - Rating color logic preserved
    Color ratingColor;
    if (rating >= 4.0) {
      ratingColor = AppTheme.successGreen;
    } else if (rating >= 3.0) {
      ratingColor = AppTheme.accentYellow;
    } else {
      ratingColor = AppTheme.errorRed;
    }

    // ENHANCED UI - Modern card design
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Business Name Tag (Enhanced)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space12,
                vertical: AppTheme.space8,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: AppTheme.primaryGreen.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.store,
                    size: 18,
                    color: AppTheme.primaryGreen,
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Flexible(
                    child: Text(
                      businessName,
                      style: AppTheme.titleSmall.copyWith(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space16),

            // Reviewer Info and Rating (Enhanced)
            Row(
              children: [
                // User Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accentBlue.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      reviewerName[0].toUpperCase(),
                      style: AppTheme.titleLarge.copyWith(
                        color: AppTheme.accentBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                
                // Reviewer Name & Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reviewerName,
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        '$relativeTime • $formattedDate',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Rating Badge (Enhanced)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space12,
                    vertical: AppTheme.space8,
                  ),
                  decoration: BoxDecoration(
                    color: ratingColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
                    border: Border.all(
                      color: ratingColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 18, color: ratingColor),
                      const SizedBox(width: AppTheme.space4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ratingColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space16),

            // Comment (Enhanced)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: AppTheme.borderLight,
                  width: 1,
                ),
              ),
              child: Text(
                comment,
                style: AppTheme.bodyMedium.copyWith(
                  height: 1.6,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space16),

            // Actions (Enhanced)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: AppTheme.errorRed,
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _deleteReview(
                        reviewData['businessId'],
                        reviewData['reviewId'],
                        businessName,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space16,
                          vertical: AppTheme.space12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: AppTheme.errorRed,
                            ),
                            const SizedBox(width: AppTheme.space8),
                            Text(
                              'Delete Review',
                              style: AppTheme.labelLarge.copyWith(
                                color: AppTheme.errorRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD EMPTY STATE (ENHANCED) ====================
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(AppTheme.space32),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.successGreen.withOpacity(0.3),
                  width: 3,
                ),
              ),
              child: Icon(
                Icons.rate_review_outlined,
                size: 80,
                color: AppTheme.successGreen.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: AppTheme.space32),
            
            // Title
            Text(
              'No Reviews Yet',
              style: AppTheme.headlineMedium.copyWith(
                fontSize: 24,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            
            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space24),
              child: Text(
                'Reviews will appear here once users\nstart sharing their experiences',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD STAT ITEM (ENHANCED) ====================
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      child: Column(
        children: [
          // Icon + Value
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppTheme.space12),
              Text(
                value,
                style: AppTheme.displayMedium.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          
          // Label
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CALCULATE AVERAGE RATING ====================
  // NO CHANGES - Business logic preserved
  double _calculateAverageRating() {
    if (_allReviews.isEmpty) return 0.0;
    double total = 0;
    for (var review in _allReviews) {
      total += review['rating'];
    }
    return total / _allReviews.length;
  }

  // ==================== BUILD METHOD (ENHANCED) ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Review Moderation',
          style: AppTheme.titleLarge.copyWith(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        actions: [
          // Sort Button (Enhanced)
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(AppTheme.space8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: const Icon(Icons.sort, color: Colors.white),
            ),
            tooltip: 'Sort Reviews',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
              _sortReviews();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'recent',
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 20,
                      color: _sortBy == 'recent' ? AppTheme.primaryGreen : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Text(
                      'Most Recent',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: _sortBy == 'recent' ? FontWeight.bold : FontWeight.normal,
                        color: _sortBy == 'recent' ? AppTheme.primaryGreen : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'rating_low',
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_downward,
                      size: 20,
                      color: _sortBy == 'rating_low' ? AppTheme.primaryGreen : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Text(
                      'Lowest Rating',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: _sortBy == 'rating_low' ? FontWeight.bold : FontWeight.normal,
                        color: _sortBy == 'rating_low' ? AppTheme.primaryGreen : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'rating_high',
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_upward,
                      size: 20,
                      color: _sortBy == 'rating_high' ? AppTheme.primaryGreen : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Text(
                      'Highest Rating',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: _sortBy == 'rating_high' ? FontWeight.bold : FontWeight.normal,
                        color: _sortBy == 'rating_high' ? AppTheme.primaryGreen : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _loadAllReviews,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryGreen,
                      strokeWidth: 4,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space24),
                  Text(
                    'Loading reviews...',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : _allReviews.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Stats Bar (Enhanced)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space16,
                        vertical: AppTheme.space20,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryGreen.withOpacity(0.1),
                            AppTheme.secondaryGreen.withOpacity(0.05),
                          ],
                        ),
                        border: const Border(
                          bottom: BorderSide(
                            color: AppTheme.borderLight,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: _buildStatItem(
                              'Total Reviews',
                              _allReviews.length.toString(),
                              Icons.rate_review,
                              AppTheme.accentBlue,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 60,
                            color: AppTheme.borderLight,
                          ),
                          Expanded(
                            child: _buildStatItem(
                              'Avg Rating',
                              _calculateAverageRating().toStringAsFixed(1),
                              Icons.star,
                              AppTheme.accentYellow,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Reviews List
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadAllReviews,
                        color: AppTheme.primaryGreen,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.space16),
                          itemCount: _allReviews.length,
                          itemBuilder: (context, index) {
                            return _buildReviewCard(_allReviews[index]);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ====================================================================
// END OF ENHANCED ADMIN REVIEW MODERATION PAGE
// Business Logic: 100% Preserved
// UI: Fully Enhanced with Modern Design
// ====================================================================