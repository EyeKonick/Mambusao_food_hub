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
  Future<void> _deleteReview(String businessId, String reviewId, String businessName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: Text('Permanently delete this review from $businessName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(businessId)
          .collection(AppConfig.reviewsSubcollection)
          .doc(reviewId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Review deleted'),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reload reviews
      _loadAllReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  // ==================== BUILD REVIEW CARD ====================
  Widget _buildReviewCard(Map<String, dynamic> reviewData) {
    final businessName = reviewData['businessName'];
    final reviewerName = reviewData['reviewerName'];
    final rating = reviewData['rating'];
    final comment = reviewData['comment'];
    final timestamp = reviewData['timestamp'] as Timestamp?;
    
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

    Color ratingColor;
    if (rating >= 4.0) {
      ratingColor = AppTheme.successGreen;
    } else if (rating >= 3.0) {
      ratingColor = AppTheme.accentYellow;
    } else {
      ratingColor = AppTheme.errorRed;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Business Name Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryGreen.withOpacity(0.1),
                    AppTheme.secondaryGreen.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.store, size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 6),
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
            const SizedBox(height: 16),

            // Reviewer Info and Rating
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.accentBlue.withOpacity(0.1),
                  child: Text(
                    reviewerName[0].toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.accentBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reviewerName, style: AppTheme.titleMedium),
                      Text(
                        '$relativeTime • $formattedDate',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ratingColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, size: 18, color: ratingColor),
                      const SizedBox(width: 4),
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
            const SizedBox(height: 16),

            // Comment
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                comment,
                style: AppTheme.bodyMedium.copyWith(height: 1.6),
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _deleteReview(
                    reviewData['businessId'],
                    reviewData['reviewId'],
                    businessName,
                  ),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete Review'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: BorderSide(color: AppTheme.errorRed),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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

  // ==================== BUILD EMPTY STATE ====================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rate_review,
              size: 80,
              color: AppTheme.successGreen,
            ),
          ),
          const SizedBox(height: 24),
          Text('No Reviews Yet', style: AppTheme.headingMedium),
          const SizedBox(height: 8),
          Text(
            'Reviews will appear here once users\nstart sharing their experiences',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==================== BUILD METHOD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Review Moderation'),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.sort),
            ),
            tooltip: 'Sort Reviews',
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
                      color: _sortBy == 'recent' ? AppTheme.primaryGreen : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Most Recent',
                      style: TextStyle(
                        fontWeight: _sortBy == 'recent' ? FontWeight.bold : null,
                        color: _sortBy == 'recent' ? AppTheme.primaryGreen : null,
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
                      color: _sortBy == 'rating_low' ? AppTheme.primaryGreen : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Lowest Rating',
                      style: TextStyle(
                        fontWeight: _sortBy == 'rating_low' ? FontWeight.bold : null,
                        color: _sortBy == 'rating_low' ? AppTheme.primaryGreen : null,
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
                      color: _sortBy == 'rating_high' ? AppTheme.primaryGreen : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Highest Rating',
                      style: TextStyle(
                        fontWeight: _sortBy == 'rating_high' ? FontWeight.bold : null,
                        color: _sortBy == 'rating_high' ? AppTheme.primaryGreen : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAllReviews,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allReviews.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Stats Bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryGreen.withOpacity(0.1),
                            AppTheme.secondaryGreen.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Total Reviews',
                            _allReviews.length.toString(),
                            Icons.rate_review,
                            AppTheme.accentBlue,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppTheme.textSecondary.withOpacity(0.2),
                          ),
                          _buildStatItem(
                            'Avg Rating',
                            _calculateAverageRating().toStringAsFixed(1),
                            Icons.star,
                            AppTheme.accentYellow,
                          ),
                        ],
                      ),
                    ),

                    // Reviews List
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadAllReviews,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
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

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  double _calculateAverageRating() {
    if (_allReviews.isEmpty) return 0.0;
    double total = 0;
    for (var review in _allReviews) {
      total += review['rating'];
    }
    return total / _allReviews.length;
  }
}