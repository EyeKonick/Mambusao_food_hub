import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'user_review_form.dart';
import 'user_auth_page.dart';
import 'services/bookmark_service.dart';
import 'photo_gallery_viewer_page.dart';
import 'services/gallery_service.dart';

class EstablishmentDetailsPage extends StatefulWidget {
  final String establishmentId; // This is the business document ID

  const EstablishmentDetailsPage({
    super.key,
    required this.establishmentId,
  });

  @override
  State<EstablishmentDetailsPage> createState() =>
      _EstablishmentDetailsPageState();
}

class _EstablishmentDetailsPageState extends State<EstablishmentDetailsPage> {
  // ==================== FIREBASE INSTANCES ====================
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BookmarkService _bookmarkService = BookmarkService();
  final GalleryService _galleryService = GalleryService();

  // ==================== BOOKMARK HANDLING ====================
  /// Handle bookmark button tap
  Future<void> _handleBookmarkTap(
    String businessName,
    String businessType,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    // Check if user is authenticated (not anonymous)
    if (user == null || user.isAnonymous) {
      // Show dialog prompting user to sign in
      if (!mounted) return;
      
      final shouldSignIn = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign In Required'),
          content: const Text(
            'You need to create an account or sign in to bookmark restaurants.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign In'),
            ),
          ],
        ),
      );

      if (shouldSignIn == true && mounted) {
        // Navigate to sign in page
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserAuthPage()),
        );

        // After sign in, try bookmarking again
        if (result == true && mounted) {
          await _handleBookmarkTap(businessName, businessType);
        }
      }
      return;
    }

    // User is authenticated - toggle bookmark
    final success = await _bookmarkService.toggleBookmark(
      businessId: widget.establishmentId,
      businessName: businessName,
      businessType: businessType,
    );

    if (!mounted) return;

    // Show feedback
    if (success) {
      final isBookmarked = await _bookmarkService.isBookmarked(widget.establishmentId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBookmarked
                ? '✓ Added to bookmarks'
                : 'Removed from bookmarks',
          ),
          backgroundColor:
              isBookmarked ? AppTheme.successGreen : AppTheme.textSecondary,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update bookmark. Please try again.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  // ==================== BUILD LOGO ====================
  Widget _buildLogo(String? logoUrl) {
    const double logoSize = 100.0;

    return Container(
      height: logoSize,
      width: logoSize,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: logoUrl != null && logoUrl.isNotEmpty
          ? ClipOval(
              child: Image.network(
                logoUrl,
                height: logoSize,
                width: logoSize,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    Icons.storefront_rounded,
                    color: AppTheme.secondaryGreen,
                    size: 50,
                  ),
                ),
              ),
            )
          : Center(
              child: Icon(
                Icons.storefront_rounded,
                color: AppTheme.secondaryGreen,
                size: 50,
              ),
            ),
    );
  }

  // ==================== BUILD MENU ITEM IMAGE ====================
  Widget _buildMenuItemImage(String? imageUrl) {
    const double size = 70.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        height: size,
        width: size,
        color: AppTheme.secondaryGreen.withOpacity(0.2),
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    Icons.fastfood,
                    color: AppTheme.primaryGreen,
                    size: 30,
                  ),
                ),
              )
            : Center(
                child: Icon(
                  Icons.fastfood,
                  color: AppTheme.primaryGreen,
                  size: 30,
                ),
              ),
      ),
    );
  }

  // ==================== BUILD SECTION TITLE ====================
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 28),
        const SizedBox(width: 10),
        Text(
          title,
          style: AppTheme.headingMedium.copyWith(
            color: AppTheme.primaryGreen,
          ),
        ),
      ],
    );
  }

  // ==================== BUILD DETAILS CARD ====================
  Widget _buildDetailsCard(Map<String, dynamic> data) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildDetailRow(
              Icons.location_on_outlined,
              'Address',
              data['businessAddress'] ?? 'N/A',
            ),
            const Divider(height: 20),
            _buildDetailRow(
              Icons.phone_outlined,
              'Contact',
              data['phoneNumber'] ?? 'N/A',
            ),
            const Divider(height: 20),
            _buildDetailRow(
              Icons.category_outlined,
              'Type',
              data['businessType'] ?? 'N/A',
            ),
            const Divider(height: 20),
            _buildDetailRow(
              Icons.email_outlined,
              'Email',
              data['email'] ?? 'N/A',
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD DETAIL ROW ====================
  Widget _buildDetailRow(IconData icon, String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.secondaryGreen, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: AppTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== BUILD RATING AND REVIEW INFO ====================
  Widget _buildRatingAndReviewInfo() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(AppConfig.businessesCollection)
          .doc(widget.establishmentId)
          .collection(AppConfig.reviewsSubcollection)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        double averageRating = 0.0;
        final reviews = snapshot.data!.docs;

        if (reviews.isNotEmpty) {
          double totalRating = 0;
          for (var doc in reviews) {
            totalRating +=
                (doc.data() as Map<String, dynamic>)['rating'] as num? ?? 0.0;
          }
          averageRating = totalRating / reviews.length;
        }
        int reviewCount = reviews.length;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.star_rounded,
              color: AppTheme.accentYellow,
              size: 36,
            ),
            const SizedBox(width: 8),
            Text(
              averageRating > 0 ? averageRating.toStringAsFixed(1) : '—',
              style: AppTheme.headingLarge.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '($reviewCount ratings)',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  // ==================== BUILD MENU ITEMS LIST ====================
  Widget _buildMenuItemsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(AppConfig.businessesCollection)
          .doc(widget.establishmentId)
          .collection(AppConfig.menuItemsSubcollection)
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.menu_book,
                    size: 64,
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No menu items available yet.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final menuItems = snapshot.data!.docs;
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            var item = menuItems[index].data() as Map<String, dynamic>;
            final String? imageUrl = item['imageUrl'];
            final bool isAvailable = item['isAvailable'] ?? true;

            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 4,
              child: Opacity(
                opacity: isAvailable ? 1.0 : 0.5,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16.0,
                  ),
                  leading: _buildMenuItemImage(imageUrl),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] ?? 'No Name',
                          style: AppTheme.titleMedium.copyWith(
                            color: AppTheme.primaryGreen,
                            decoration: isAvailable
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                      if (!isAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'OUT',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.errorRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['description'] ?? 'No Description',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item['category'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            item['category'],
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: Text(
                    '₱${(item['price'] as num?)?.toStringAsFixed(2) ?? 'N/A'}',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== BUILD REVIEWS LIST ====================
  Widget _buildReviewsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(AppConfig.businessesCollection)
          .doc(widget.establishmentId)
          .collection(AppConfig.reviewsSubcollection)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review,
                    size: 64,
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No reviews yet.',
                    style: AppTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to share your experience!',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final reviews = snapshot.data!.docs;
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            var review = reviews[index].data() as Map<String, dynamic>;

            String formattedDate = '';
            Timestamp? timestamp = review['timestamp'] as Timestamp?;
            if (timestamp != null) {
              formattedDate = timestamp.toDate().toString().split(' ')[0];
            } else {
              formattedDate = 'Unknown Date';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review['reviewerName'] ?? 'Anonymous User',
                                style: AppTheme.titleMedium.copyWith(
                                  color: AppTheme.primaryGreen,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedDate,
                                style: AppTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${(review['rating'] as num?)?.toStringAsFixed(1) ?? 'N/A'}',
                              style: AppTheme.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.star_rounded,
                              color: AppTheme.accentYellow,
                              size: 24,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20, thickness: 1),
                    Text(
                      review['comment'] ?? 'No comment provided.',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== NAVIGATE TO REVIEW FORM ====================
  void _navigateToReviewForm(String businessName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserReviewForm(
          establishmentId: widget.establishmentId,
          establishmentName: businessName,
        ),
      ),
    );
  }

  // ==================== BUILD METHOD ====================
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection(AppConfig.businessesCollection)
          .doc(widget.establishmentId)
          .snapshots(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Loading Details'),
            ),
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            ),
          );
        }

        // Error or not found state
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Error'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.errorRed,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Business not found.',
                    style: AppTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        // Get business data
        var data = snapshot.data!.data() as Map<String, dynamic>;
        final String businessName = data['businessName'] ?? 'Unnamed Business';
        final String businessType = data['businessType'] ?? 'Restaurant';
        final String? logoUrl = data['logoUrl'];
        final String description = data['description'] ?? 'No description available.';

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: CustomScrollView(
            slivers: [
              // App Bar with Bookmark Button
              SliverAppBar(
                pinned: true,
                title: Text(
                  businessName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                actions: [
                  // Bookmark button in app bar
                  StreamBuilder<bool>(
                    stream: _bookmarkService.watchBookmarkStatus(widget.establishmentId),
                    builder: (context, snapshot) {
                      final isBookmarked = snapshot.data ?? false;
                      
                      return IconButton(
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        ),
                        tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
                        onPressed: () => _handleBookmarkTap(businessName, businessType),
                      );
                    },
                  ),
                ],
              ),

              // Content
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Logo + Name
                        Align(
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              _buildLogo(logoUrl),
                              const SizedBox(height: 10),
                              Text(
                                businessName,
                                style: AppTheme.headingMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                        _buildRatingAndReviewInfo(),
                        const SizedBox(height: 24),

                        // Description
                        Text(
                          description,
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Information Section
                        _buildSectionTitle('Information', Icons.info_outline),
                        const SizedBox(height: 16),
                        _buildDetailsCard(data),
                        const SizedBox(height: 32),

                        // Photos Section
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _galleryService.getBusinessGallery(widget.establishmentId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox.shrink();
                            }

                            final photos = snapshot.data ?? [];
                            
                            if (photos.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Other Photos',
                                      style: AppTheme.headingMedium,
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PhotoGalleryViewerPage(
                                              businessName: businessName,
                                              photos: photos,
                                              initialIndex: 0,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Text('View All (${photos.length})'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                SizedBox(
                                  height: 120,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: photos.length > 10 ? 10 : photos.length,
                                    itemBuilder: (context, index) {
                                      final photo = photos[index];
                                      final photoUrl = photo['photoUrl'] as String;

                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PhotoGalleryViewerPage(
                                                businessName: businessName,
                                                photos: photos,
                                                initialIndex: index,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          width: 120,
                                          margin: const EdgeInsets.only(right: 12),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                Image.network(
                                                  photoUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: Colors.grey[300],
                                                      child: const Icon(Icons.broken_image),
                                                    );
                                                  },
                                                ),
                                                
                                                if (index == 9 && photos.length > 10)
                                                  Container(
                                                    color: Colors.black.withOpacity(0.7),
                                                    child: Center(
                                                      child: Text(
                                                        '+${photos.length - 10}\nmore',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Divider(),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        ),

                        // Menu Items Section
                        _buildSectionTitle('Menu Items', Icons.menu_book),
                        const SizedBox(height: 16),
                        _buildMenuItemsList(),
                        const SizedBox(height: 32),

                        // Reviews Section
                        _buildSectionTitle(
                          'Customer Reviews',
                          Icons.rate_review,
                        ),
                        const SizedBox(height: 16),
                        _buildReviewsList(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _navigateToReviewForm(businessName),
            label: const Text(
              'Write a Review',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            icon: const Icon(Icons.edit_note, size: 28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
            elevation: 10,
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}