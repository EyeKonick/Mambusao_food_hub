// ====================================================================
// ENHANCED ESTABLISHMENT DETAILS PAGE - PART 1
// UI Enhancement Phase - Modern, Clean Design with Poppins Font
// 
// PART 1 INCLUDES:
// - Imports
// - Class setup and state variables
// - Initialization
// - Bookmark handling
// - Label selection dialog
// ====================================================================

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
import 'services/promotion_service.dart';
import 'services/view_tracking_service.dart';
import 'models/promotion_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'business_route_map_page.dart';

class EstablishmentDetailsPage extends StatefulWidget {
  final String establishmentId;

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
  final PromotionService _promotionService = PromotionService();

  // ==================== LOCATION/MAP STATE ====================
  Position? _userLocation;
  bool _isLoadingLocation = false;
  GoogleMapController? _miniMapController;

  // ==================== INITIALIZATION ====================
  @override
  void initState() {
    super.initState();
    // Track view when page is loaded
    ViewTrackingService.trackBusinessView(widget.establishmentId);
  }

  // ==================== BOOKMARK HANDLING (ENHANCED UI) ====================
  Future<void> _handleBookmarkTap(
    String businessName,
    String businessType,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      if (!mounted) return;
      
      final shouldSignIn = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          title: Text(
            'Sign In Required',
            style: AppTheme.headlineMedium,
          ),
          content: Text(
            'You need to create an account or sign in to bookmark restaurants.',
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
                backgroundColor: AppTheme.primaryGreen,
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
                'Sign In',
                style: AppTheme.labelLarge.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );

      if (shouldSignIn == true && mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserAuthPage()),
        );

        if (result == true && mounted) {
          await _handleBookmarkTap(businessName, businessType);
        }
      }
      return;
    }

    // Check if already bookmarked
    final isCurrentlyBookmarked = await _bookmarkService.isBookmarked(widget.establishmentId);

    if (isCurrentlyBookmarked) {
      // Already bookmarked - just remove it
      final success = await _bookmarkService.removeBookmark(widget.establishmentId);
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Removed from bookmarks',
              style: AppTheme.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: AppTheme.textSecondary,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    } else {
      // Not bookmarked - show label selection dialog
      final label = await _showLabelSelectionDialog();
      
      if (label == null && !mounted) return; // User cancelled
      
      final success = await _bookmarkService.addBookmark(
        businessId: widget.establishmentId,
        businessName: businessName,
        businessType: businessType,
        label: label?.isEmpty ?? true ? null : label,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              label != null && label.isNotEmpty
                  ? '✓ Added to "$label"'
                  : '✓ Added to bookmarks',
              style: AppTheme.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update bookmark. Please try again.',
              style: AppTheme.bodyMedium.copyWith(color: Colors.white),
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
  }

  // ==================== LABEL SELECTION DIALOG (ENHANCED UI) ====================
  Future<String?> _showLabelSelectionDialog() async {
    final labelColors = {
      'Want to Try': AppTheme.accentYellow,
      'Favorites': AppTheme.errorRed,
      'Date Night': Colors.pink,
      'Good for Groups': AppTheme.accentBlue,
    };

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text(
          'Add Label (Optional)',
          style: AppTheme.headlineMedium,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Predefined labels with enhanced design
              ...labelColors.keys.map((label) => Container(
                margin: const EdgeInsets.only(bottom: AppTheme.space8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.borderLight,
                    width: 1,
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: labelColors[label],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (labelColors[label] ?? Colors.grey).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  title: Text(
                    label,
                    style: AppTheme.titleMedium,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  onTap: () => Navigator.pop(context, label),
                ),
              )),
              
              const SizedBox(height: AppTheme.space8),
              const Divider(),
              const SizedBox(height: AppTheme.space8),
              
              // No label option
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.borderLight,
                    width: 1,
                  ),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.bookmark_border,
                    color: AppTheme.textSecondary,
                  ),
                  title: Text(
                    'No Label',
                    style: AppTheme.titleMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  onTap: () => Navigator.pop(context, ''),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: Text(
              'Cancel',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [CONTINUED IN PART 2...]
// ====================================================================
// ENHANCED ESTABLISHMENT DETAILS PAGE - PART 2
// UI Enhancement Phase - Modern, Clean Design with Poppins Font
// 
// PART 2 INCLUDES:
// - Active Promotions Section (Enhanced)
// - Section Title Widget (Enhanced)
// - Menu Items List (Enhanced)
// - Reviews List (Enhanced)
// - Review Form Navigation
// ====================================================================

  // ==================== BUILD ACTIVE PROMOTIONS SECTION (ENHANCED) ====================
  Widget _buildActivePromotionsSection() {
    return StreamBuilder<List<Promotion>>(
      stream: _promotionService.getActiveBusinessPromotions(widget.establishmentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final promotions = snapshot.data ?? [];
        
        if (promotions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(top: AppTheme.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header - Enhanced
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentYellow.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: const Icon(
                        Icons.local_offer_rounded,
                        color: AppTheme.accentYellow,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Text(
                      'Active Promotions',
                      style: AppTheme.headlineMedium.copyWith(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space12,
                        vertical: AppTheme.space4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentYellow,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
                      ),
                      child: Text(
                        '${promotions.length}',
                        style: AppTheme.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppTheme.space16),
              
              // Promotions List - Enhanced Cards
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
                  itemCount: promotions.length,
                  itemBuilder: (context, index) {
                    final promo = promotions[index];
                    return Container(
                      width: 320,
                      margin: EdgeInsets.only(
                        right: index < promotions.length - 1 ? AppTheme.space16 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        boxShadow: AppTheme.shadowCard,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Promo Image
                            if (promo.imageUrl != null && promo.imageUrl!.isNotEmpty)
                              Stack(
                                children: [
                                  Image.network(
                                    promo.imageUrl!,
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 120,
                                        color: AppTheme.lightGreen,
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          color: AppTheme.textHint,
                                          size: 48,
                                        ),
                                      );
                                    },
                                  ),
                                  // Offer Badge
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentYellow,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.local_offer,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'OFFER',
                                            style: AppTheme.labelSmall.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            
                            // Promo Details
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(AppTheme.space12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      promo.title,
                                      style: AppTheme.titleMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: AppTheme.space4),
                                    Text(
                                      promo.description,
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: AppTheme.space24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.space16),
                child: Divider(height: 1),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== BUILD SECTION TITLE (ENHANCED) ====================
  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Text(
            title,
            style: AppTheme.headlineMedium.copyWith(
              color: AppTheme.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD MENU ITEMS LIST (ENHANCED) ====================
  Widget _buildMenuItemsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(AppConfig.businessesCollection)
          .doc(widget.establishmentId)
          .collection(AppConfig.menuItemsSubcollection)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.space24),
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.space16),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppTheme.errorRed,
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Text(
                      'Error loading menu items',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.errorRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.space24),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(
                  color: AppTheme.borderLight,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 64,
                    color: AppTheme.textHint,
                  ),
                  const SizedBox(height: AppTheme.space12),
                  Text(
                    'No menu items yet',
                    style: AppTheme.titleMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    'This restaurant hasn\'t added their menu',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textHint,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Enhanced Menu Items Grid
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppTheme.space12,
              mainAxisSpacing: AppTheme.space12,
              childAspectRatio: 0.75,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final itemName = data['itemName'] ?? 'Unnamed Item';
              final price = data['price'] ?? 0.0;
              final photoUrl = data['photoUrl'] as String?;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  boxShadow: AppTheme.shadowCardLight,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Menu Item Image
                      AspectRatio(
                        aspectRatio: 1,
                        child: photoUrl != null && photoUrl.isNotEmpty
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: AppTheme.lightGreen,
                                    child: const Icon(
                                      Icons.restaurant,
                                      size: 48,
                                      color: AppTheme.textHint,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: AppTheme.lightGreen,
                                child: const Icon(
                                  Icons.restaurant,
                                  size: 48,
                                  color: AppTheme.textHint,
                                ),
                              ),
                      ),
                      
                      // Menu Item Details
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.space12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemName,
                                style: AppTheme.titleSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.space8,
                                  vertical: AppTheme.space4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                ),
                                child: Text(
                                  '₱${price.toStringAsFixed(2)}',
                                  style: AppTheme.labelMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ==================== BUILD REVIEWS LIST (FIXED - BUGS #2 & #3) ====================
  Widget _buildReviewsList(String businessName) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(AppConfig.businessesCollection)
          .doc(widget.establishmentId)
          .collection(AppConfig.reviewsSubcollection)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.space24),
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.space16),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppTheme.errorRed,
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Text(
                      'Error loading reviews',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.errorRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.space24),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(
                  color: AppTheme.borderLight,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 64,
                    color: AppTheme.textHint,
                  ),
                  const SizedBox(height: AppTheme.space12),
                  Text(
                    'No reviews yet',
                    style: AppTheme.titleMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    'Be the first to review $businessName!',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textHint,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.space16),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToReviewForm(businessName),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Write First Review'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Enhanced Review Cards with User Name Fetch and Owner Replies
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppTheme.space16),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final userId = data['userId'] as String?;
            final rating = (data['rating'] ?? 0).toDouble();
            final comment = data['comment'] ?? '';
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
            
            // 🐛 BUG #3 FIX: Get owner reply data
            final ownerReply = data['ownerReply'] as String?;
            final ownerReplyTimestamp = (data['ownerReplyTimestamp'] as Timestamp?)?.toDate();

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                boxShadow: AppTheme.shadowCardLight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🐛 BUG #2 FIX: Fetch user name from Firestore users collection
                    FutureBuilder<DocumentSnapshot>(
                      future: userId != null
                          ? _firestore.collection('users').doc(userId).get()
                          : null,
                      builder: (context, userSnapshot) {
                        // Default to stored userName or 'Anonymous'
                        String displayName = data['userName'] ?? 'Anonymous';
                        
                        // If user document exists, use their display name
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                          displayName = userData['displayName'] ?? 
                                       userData['name'] ?? 
                                       userData['email']?.split('@')[0] ?? 
                                       'User';
                        }

                        return Row(
                          children: [
                            // User Avatar
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                                  style: AppTheme.titleLarge.copyWith(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: AppTheme.titleMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.space4),
                                  if (timestamp != null)
                                    Text(
                                      _formatDate(timestamp),
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textHint,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Star Rating
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.space12,
                                vertical: AppTheme.space4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentYellow.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 16,
                                    color: AppTheme.accentYellow,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: AppTheme.labelLarge.copyWith(
                                      color: AppTheme.accentYellow,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    
                    const SizedBox(height: AppTheme.space12),
                    
                    // Review Comment
                    Text(
                      comment,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimary,
                        height: 1.5,
                      ),
                    ),

                    // 🐛 BUG #3 FIX: Display Owner Reply if it exists
                    if (ownerReply != null && ownerReply.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.space16),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.space12),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(
                            color: AppTheme.primaryGreen.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Owner Reply Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.store,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.space8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Response from Owner',
                                        style: AppTheme.labelLarge.copyWith(
                                          color: AppTheme.primaryGreen,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (ownerReplyTimestamp != null)
                                        Text(
                                          _formatDate(ownerReplyTimestamp),
                                          style: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.space8),
                            // Owner Reply Text
                            Text(
                              ownerReply,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textPrimary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  // ==================== REVIEW FORM NAVIGATION ====================
  Future<void> _navigateToReviewForm(String businessName) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      if (!mounted) return;
      
      final shouldSignIn = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          title: Text(
            'Sign In Required',
            style: AppTheme.headlineMedium,
          ),
          content: Text(
            'You need to create an account or sign in to write a review.',
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
                backgroundColor: AppTheme.primaryGreen,
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
                'Sign In',
                style: AppTheme.labelLarge.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );

      if (shouldSignIn == true && mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserAuthPage()),
        );

        if (result == true && mounted) {
          await _navigateToReviewForm(businessName);
        }
      }
      return;
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserReviewForm(
          establishmentId: widget.establishmentId,
          establishmentName: businessName,
        ),
      ),
    );
  }

  // ==================== HELPER: FORMAT DATE ====================
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  // [CONTINUED IN PART 3...]
// ====================================================================
// ENHANCED ESTABLISHMENT DETAILS PAGE - PART 3
// UI ENHANCEMENT PHASE - MODERN, CLEAN DESIGN WITH POPPINS FONT
// 
// PART 3 INCLUDES:
// - ROUTE MAP NAVIGATION
// - SOCIAL MEDIA LAUNCH
// - MAIN BUILD METHOD
// - HERO HEADER WITH COVER IMAGE
// - BUSINESS INFO CARD WITH RATING
// - BUSINESS DETAILS SECTION
// - PHOTO GALLERY SECTION
// ====================================================================

  // ==================== NAVIGATE TO ROUTE MAP ====================
  Future<void> _navigateToRouteMap({
    required double businessLat,
    required double businessLng,
    required String businessName,
  }) async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Get user's current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLocation = position;
        _isLoadingLocation = false;
      });

      if (!mounted) return;

      // Navigate to route map
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BusinessRouteMapPage(
            businessLat: businessLat,
            businessLng: businessLng,
            businessName: businessName,
            userLat: position.latitude,
            userLng: position.longitude,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get your location. Please enable location services.',
            style: AppTheme.bodyMedium.copyWith(color: Colors.white),
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

  // ==================== LAUNCH SOCIAL MEDIA ====================
  Future<void> _launchUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open link',
              style: AppTheme.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invalid URL format',
            style: AppTheme.bodyMedium.copyWith(color: Colors.white),
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

  // ==================== MAIN BUILD METHOD (ENHANCED) ====================
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection(AppConfig.businessesCollection)
          .doc(widget.establishmentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                'Error',
                style: AppTheme.titleLarge.copyWith(color: Colors.white),
              ),
              backgroundColor: AppTheme.primaryGreen,
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 80,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(height: AppTheme.space24),
                    Text(
                      'Business not found',
                      style: AppTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.space12),
                    Text(
                      'This business may have been removed or doesn\'t exist.',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.space24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final businessName = data['businessName'] ?? 'Unknown';
        final businessType = data['businessType'] ?? 'Restaurant';
        final businessAddress = data['businessAddress'] ?? 'No address';
        final businessDescription = data['businessDescription'] ?? 'No description';
        final logoUrl = data['logoUrl'] as String?;
        final coverImageUrl = data['coverImageUrl'] as String?;
        final avgRating = (data['avgRating'] ?? 0.0).toDouble();
        final reviewCount = data['reviewCount'] ?? 0;
        final phoneNumber = data['phoneNumber'] as String?;
        final facebookUrl = data['facebookUrl'] as String?;
        final instagramUrl = data['instagramUrl'] as String?;
        final websiteUrl = data['websiteUrl'] as String?;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // ==================== HERO HEADER (ENHANCED) ====================
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: AppTheme.primaryGreen,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGreen),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  // Bookmark Button
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: StreamBuilder<bool>(
                      stream: _bookmarkService.isBookmarkedStream(widget.establishmentId),
                      builder: (context, snapshot) {
                        final isBookmarked = snapshot.data ?? false;
                        return IconButton(
                          icon: Icon(
                            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: isBookmarked ? AppTheme.accentYellow : AppTheme.primaryGreen,
                          ),
                          onPressed: () => _handleBookmarkTap(businessName, businessType),
                        );
                      },
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Cover Image
                      if (coverImageUrl != null && coverImageUrl.isNotEmpty)
                        Image.network(
                          coverImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppTheme.primaryGreen,
                              child: const Icon(
                                Icons.restaurant,
                                size: 100,
                                color: Colors.white54,
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryGreen,
                                AppTheme.secondaryGreen,
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.restaurant,
                            size: 100,
                            color: Colors.white54,
                          ),
                        ),
                      
                      // Gradient Overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 150,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ==================== CONTENT ====================
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Business Info Card (Enhanced)
                    Transform.translate(
                      offset: const Offset(0, -40),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            boxShadow: AppTheme.shadowCard,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.space20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Business Name & Logo Row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Logo
                                    if (logoUrl != null && logoUrl.isNotEmpty)
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                                          border: Border.all(
                                            color: AppTheme.borderLight,
                                            width: 2,
                                          ),
                                          boxShadow: AppTheme.shadowCardLight,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge - 2),
                                          child: Image.network(
                                            logoUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: AppTheme.lightGreen,
                                                child: const Icon(
                                                  Icons.restaurant,
                                                  size: 40,
                                                  color: AppTheme.primaryGreen,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    
                                    const SizedBox(width: AppTheme.space16),
                                    
                                    // Business Name & Type
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            businessName,
                                            style: AppTheme.headlineMedium.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: AppTheme.space4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppTheme.space12,
                                              vertical: AppTheme.space4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryGreen.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
                                            ),
                                            child: Text(
                                              businessType,
                                              style: AppTheme.labelMedium.copyWith(
                                                color: AppTheme.primaryGreen,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: AppTheme.space16),
                                const Divider(height: 1),
                                const SizedBox(height: AppTheme.space16),
                                
                                // Rating & Reviews Row
                                Row(
                                  children: [
                                    // Rating
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppTheme.space16,
                                        vertical: AppTheme.space8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentYellow.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: AppTheme.accentYellow,
                                            size: 24,
                                          ),
                                          const SizedBox(width: AppTheme.space8),
                                          Text(
                                            avgRating > 0 ? avgRating.toStringAsFixed(1) : 'No ratings',
                                            style: AppTheme.titleMedium.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    const SizedBox(width: AppTheme.space12),
                                    
                                    // Review Count
                                    Text(
                                      '($reviewCount ${reviewCount == 1 ? 'review' : 'reviews'})',
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Adjust spacing after floating card
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Active Promotions
                          _buildActivePromotionsSection(),
                          
                          // Business Details Section
                          const SizedBox(height: AppTheme.space24),
                          _buildSectionTitle('About', Icons.info_outline),
                          const SizedBox(height: AppTheme.space16),
                          
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
                            child: Container(
                              padding: const EdgeInsets.all(AppTheme.space16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                                boxShadow: AppTheme.shadowCardLight,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Description
                                  Text(
                                    businessDescription,
                                    style: AppTheme.bodyLarge.copyWith(
                                      height: 1.6,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  
                                  const SizedBox(height: AppTheme.space16),
                                  const Divider(height: 1),
                                  const SizedBox(height: AppTheme.space16),
                                  
                                  // Address
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(AppTheme.space8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryGreen.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: AppTheme.primaryGreen,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.space12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Address',
                                              style: AppTheme.labelLarge.copyWith(
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: AppTheme.space4),
                                            Text(
                                              businessAddress,
                                              style: AppTheme.bodyMedium.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Phone Number
                                  if (phoneNumber != null && phoneNumber.isNotEmpty) ...[
                                    const SizedBox(height: AppTheme.space16),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(AppTheme.space8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryGreen.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                          ),
                                          child: const Icon(
                                            Icons.phone,
                                            color: AppTheme.primaryGreen,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: AppTheme.space12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Phone',
                                                style: AppTheme.labelLarge.copyWith(
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: AppTheme.space4),
                                              Text(
                                                phoneNumber,
                                                style: AppTheme.bodyMedium.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  
                                  // Social Media Links
                                  if ((facebookUrl != null && facebookUrl.isNotEmpty) ||
                                      (instagramUrl != null && instagramUrl.isNotEmpty) ||
                                      (websiteUrl != null && websiteUrl.isNotEmpty)) ...[
                                    const SizedBox(height: AppTheme.space16),
                                    const Divider(height: 1),
                                    const SizedBox(height: AppTheme.space16),
                                    
                                    Text(
                                      'Connect With Us',
                                      style: AppTheme.labelLarge.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: AppTheme.space12),
                                    
                                    Row(
                                      children: [
                                        if (facebookUrl != null && facebookUrl.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(right: AppTheme.space12),
                                            child: Material(
                                              color: const Color(0xFF1877F2),
                                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                              child: InkWell(
                                                onTap: () => _launchUrl(facebookUrl),
                                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                                child: Container(
                                                  padding: const EdgeInsets.all(AppTheme.space12),
                                                  child: const Icon(
                                                    Icons.facebook,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        
                                        if (instagramUrl != null && instagramUrl.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(right: AppTheme.space12),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                                gradient: const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Color(0xFFF58529),
                                                    Color(0xFFDD2A7B),
                                                    Color(0xFF8134AF),
                                                  ],
                                                ),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () => _launchUrl(instagramUrl),
                                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(AppTheme.space12),
                                                    child: const Icon(
                                                      Icons.camera_alt,
                                                      color: Colors.white,
                                                      size: 24,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        
                                        if (websiteUrl != null && websiteUrl.isNotEmpty)
                                          Material(
                                            color: AppTheme.primaryGreen,
                                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                            child: InkWell(
                                              onTap: () => _launchUrl(websiteUrl),
                                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                              child: Container(
                                                padding: const EdgeInsets.all(AppTheme.space12),
                                                child: const Icon(
                                                  Icons.language,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: AppTheme.space24),
                          
                          // Photo Gallery Section (Enhanced)
                          StreamBuilder<QuerySnapshot>(
                            stream: _firestore
                                .collection(AppConfig.businessesCollection)
                                .doc(widget.establishmentId)
                                .collection(AppConfig.photosSubcollection)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox.shrink();
                              }

                              final docs = snapshot.data?.docs ?? [];
                              final List<Map<String, dynamic>> photos = docs
                                  .map((doc) => doc.data() as Map<String, dynamic>)
                                  .toList();

                              if (photos.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Section Header
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(AppTheme.space8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryGreen.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                          ),
                                          child: const Icon(
                                            Icons.photo_library,
                                            color: AppTheme.primaryGreen,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: AppTheme.space12),
                                        Text(
                                          'Photo Gallery',
                                          style: AppTheme.headlineMedium.copyWith(
                                            color: AppTheme.primaryGreen,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PhotoGalleryViewerPage(
                                                photos: photos,
                                                initialIndex: 0,
                                                businessName: businessName,
                                              ),
                                            ),
                                          );
                                        },
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppTheme.primaryGreen,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'View All',
                                                style: AppTheme.labelLarge.copyWith(
                                                  color: AppTheme.primaryGreen,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.arrow_forward_ios,
                                                size: 14,
                                                color: AppTheme.primaryGreen,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: AppTheme.space16),
                                  
                                  // Photo Grid (Enhanced)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
                                    child: GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: AppTheme.space8,
                                        mainAxisSpacing: AppTheme.space8,
                                        childAspectRatio: 1,
                                      ),
                                      itemCount: photos.length > 9 ? 9 : photos.length,
                                      itemBuilder: (context, index) {
                                        final photo = photos[index];
                                        final photoUrl = photo['photoUrl'] as String?;

                                        if (index == 8 && photos.length > 9) {
                                          // Show "+X more" overlay on 9th item
                                          return GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => PhotoGalleryViewerPage(
                                                    photos: photos,
                                                    initialIndex: 8,
                                                    businessName: businessName,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                                boxShadow: AppTheme.shadowCardLight,
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    if (photoUrl != null && photoUrl.isNotEmpty)
                                                      Image.network(
                                                        photoUrl,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) {
                                                          return Container(
                                                            color: AppTheme.lightGreen,
                                                            child: const Icon(
                                                              Icons.image_not_supported,
                                                              color: AppTheme.textHint,
                                                            ),
                                                          );
                                                        },
                                                      )
                                                    else
                                                      Container(
                                                        color: AppTheme.lightGreen,
                                                        child: const Icon(
                                                          Icons.image,
                                                          color: AppTheme.textHint,
                                                        ),
                                                      ),
                                                    
                                                    // Overlay with "+X more"
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withOpacity(0.7),
                                                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          '+${photos.length - 9}\nmore',
                                                          style: AppTheme.titleMedium.copyWith(
                                                            color: Colors.white,
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
                                        }

                                        // Regular photo item
                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => PhotoGalleryViewerPage(
                                                  photos: photos,
                                                  initialIndex: index,
                                                  businessName: businessName,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                              boxShadow: AppTheme.shadowCardLight,
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                              child: photoUrl != null && photoUrl.isNotEmpty
                                                  ? Image.network(
                                                      photoUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return Container(
                                                          color: AppTheme.lightGreen,
                                                          child: const Icon(
                                                            Icons.image_not_supported,
                                                            color: AppTheme.textHint,
                                                          ),
                                                        );
                                                      },
                                                    )
                                                  : Container(
                                                      color: AppTheme.lightGreen,
                                                      child: const Icon(
                                                        Icons.image,
                                                        color: AppTheme.textHint,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  
                                  const SizedBox(height: AppTheme.space24),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: AppTheme.space16),
                                    child: Divider(height: 1),
                                  ),
                                ],
                              );
                            },
                          ),

                          // Location & Directions Section
                          _buildLocationAndDirectionsSection(data),

                          // Menu Items Section
                          const SizedBox(height: AppTheme.space24),
                          _buildSectionTitle('Menu Items', Icons.menu_book),
                          const SizedBox(height: AppTheme.space16),
                          _buildMenuItemsList(),
                          const SizedBox(height: AppTheme.space32),

                          // Reviews Section
                          _buildSectionTitle('Customer Reviews', Icons.rate_review),
                          const SizedBox(height: AppTheme.space16),
                          _buildReviewsList(businessName),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // ==================== FLOATING ACTION BUTTON (ENHANCED) ====================
          floatingActionButton: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: () => _navigateToReviewForm(businessName),
              label: Text(
                'Write a Review',
                style: AppTheme.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              icon: const Icon(Icons.edit_note, size: 28),
              backgroundColor: AppTheme.primaryGreen,
              elevation: 0, // Remove default elevation (we're using custom shadow)
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  // ==================== BUILD LOCATION & DIRECTIONS SECTION (ENHANCED) ====================
  Widget _buildLocationAndDirectionsSection(Map<String, dynamic> data) {
    final double? businessLat = data['latitude'] as double?;
    final double? businessLng = data['longitude'] as double?;
    final String businessName = data['businessName'] ?? 'Business';

    // Only show if business has location
    if (businessLat == null || businessLng == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.space24),
        
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: AppTheme.primaryGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Text(
                'Location & Directions',
                style: AppTheme.headlineMedium.copyWith(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: AppTheme.space16),
        
        // Mini Map Preview Card (Enhanced)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              boxShadow: AppTheme.shadowCard,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              child: Column(
                children: [
                  // Mini Map
                  Stack(
                    children: [
                      SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: GoogleMap(
                          onMapCreated: (controller) {
                            _miniMapController = controller;
                          },
                          initialCameraPosition: CameraPosition(
                            target: LatLng(businessLat, businessLng),
                            zoom: 15,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('business'),
                              position: LatLng(businessLat, businessLng),
                              infoWindow: InfoWindow(title: businessName),
                            ),
                          },
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                          scrollGesturesEnabled: false,
                          zoomGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                          rotateGesturesEnabled: false,
                        ),
                      ),
                      
                      // Fullscreen Button (Enhanced)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _navigateToRouteMap(
                                businessLat: businessLat,
                                businessLng: businessLng,
                                businessName: businessName,
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              child: Padding(
                                padding: const EdgeInsets.all(AppTheme.space8),
                                child: const Icon(
                                  Icons.fullscreen,
                                  color: AppTheme.primaryGreen,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Get Directions Button (Enhanced)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.space16),
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingLocation
                          ? null
                          : () => _navigateToRouteMap(
                                businessLat: businessLat,
                                businessLng: businessLng,
                                businessName: businessName,
                              ),
                      icon: _isLoadingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.directions, size: 24),
                      label: Text(
                        _isLoadingLocation ? 'Getting Location...' : 'Get Directions',
                        style: AppTheme.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: AppTheme.space24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.space16),
          child: Divider(height: 1),
        ),
      ],
    );
  }
}

// ====================================================================
// END OF ENHANCED ESTABLISHMENT DETAILS PAGE
// ====================================================================