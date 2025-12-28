import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'search_page.dart';
import 'establishment_details_page.dart';
import 'user_auth_page.dart';
import 'user_profile_page.dart';
import 'services/bookmark_service.dart';
import 'models/filter_state.dart';

/// Enhanced Home Page - Main browsing interface
/// 
/// UI ENHANCEMENTS:
/// - Modern card-based restaurant listings
/// - Enhanced promotion cards with better visuals
/// - Improved category chips with icons
/// - Better spacing and typography
/// - Enhanced location banner
/// - Modern filter modal
/// 
/// BUSINESS LOGIC: 100% PRESERVED - NO CHANGES

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ==================== FIREBASE INSTANCES ====================
  // NO CHANGES - Business logic preserved
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BookmarkService _bookmarkService = BookmarkService();

  // ==================== STATE VARIABLES ====================
  // NO CHANGES - All state management preserved
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String? _locationError;
  String _selectedCategory = 'All';
  FilterState _filterState = const FilterState();
  Map<String, double> _businessAvgRatingCache = {};

  final List<String> _categories = [
    'All',
    'Tea & Coffee Shop',
    'Bakery',
    'Carinderia',
    'Pizzeria',
    'Casual Dining',
    'Fast Food',
    'Noodle & Soup Spot',
    'Food Stall',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // ==================== BOOKMARK HANDLING ====================
  // NO CHANGES - Complete logic preserved
  Future<void> _handleBookmarkTap(
    String businessId,
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
          title: Text('Sign In Required', style: AppTheme.titleLarge),
          content: Text(
            'You need to create an account or sign in to bookmark restaurants.',
            style: AppTheme.bodyMedium,
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
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserAuthPage()),
        );

        if (result == true && mounted) {
          await _handleBookmarkTap(businessId, businessName, businessType);
        }
      }
      return;
    }

    final isCurrentlyBookmarked = await _bookmarkService.isBookmarked(businessId);

    if (isCurrentlyBookmarked) {
      final success = await _bookmarkService.removeBookmark(businessId);
      
      if (!mounted) return;
      
      if (success) {
        // Force UI update after bookmark removal
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: AppTheme.space8),
                const Text('Removed from bookmarks'),
              ],
            ),
            backgroundColor: AppTheme.textSecondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      final label = await _showLabelSelectionDialog();
      
      if (label == null && !mounted) return;
      
      final success = await _bookmarkService.addBookmark(
        businessId: businessId,
        businessName: businessName,
        businessType: businessType,
        label: label?.isEmpty ?? true ? null : label,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bookmark, color: Colors.white, size: 20),
                SizedBox(width: AppTheme.space8),
                Expanded(
                  child: Text(
                    label != null && label.isNotEmpty
                        ? 'Added to "$label"'
                        : 'Added to bookmarks',
                  ),
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to update bookmark. Please try again.')),
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
  }

  // ==================== LABEL SELECTION DIALOG ====================
  // ENHANCED UI - Logic preserved
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
        title: Text('Add Label (Optional)', style: AppTheme.titleLarge),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...labelColors.keys.map((label) => Container(
                margin: EdgeInsets.only(bottom: AppTheme.space8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderLight),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: ListTile(
                  leading: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: labelColors[label],
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(label, style: AppTheme.bodyMedium),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textHint),
                  onTap: () => Navigator.pop(context, label),
                ),
              )),
              
              const Divider(),
              SizedBox(height: AppTheme.space8),
              
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderLight),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: ListTile(
                  leading: const Icon(Icons.bookmark_border, color: AppTheme.textSecondary),
                  title: Text('No Label', style: AppTheme.bodyMedium),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textHint),
                  onTap: () => Navigator.pop(context, ''),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ==================== ACCOUNT NAVIGATION ====================
  // NO CHANGES - Complete logic preserved
  Future<void> _handleAccountNavigation() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null || user.isAnonymous) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UserAuthPage()),
      );
      
      if (result == true && mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Welcome back!'),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UserProfilePage()),
      );
      
      if (mounted) {
        setState(() {});
      }
    }
  }

  // ==================== LOCATION SERVICES ====================
  // NO CHANGES - Complete logic preserved
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable them in settings.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied. Please grant permission to find nearby restaurants.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable them in app settings.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✓ Location obtained: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      setState(() {
        _locationError = e.toString();
        _isLoadingLocation = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Location error: $e');
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  // ==================== APPLY ADVANCED FILTERS ====================
  // NO CHANGES - Complete filtering logic preserved
  List<DocumentSnapshot> _applyAdvancedFilters(List<DocumentSnapshot> businesses) {
    if (!_filterState.hasActiveFilters) {
      return businesses;
    }

    return businesses.where((business) {
      final data = business.data() as Map<String, dynamic>;

      if (_filterState.selectedCategories.isNotEmpty) {
        final businessType = data['businessType'] as String?;
        if (businessType == null || !_filterState.selectedCategories.contains(businessType)) {
          return false;
        }
      }

      if (_filterState.minRating != null) {
        final businessId = business.id;
        final avgRating = data['avgRating'] as double? ?? 0.0;
        
        _businessAvgRatingCache[businessId] = avgRating;
        
        if (avgRating < _filterState.minRating!) {
          return false;
        }
      }

      if (_filterState.maxDistance != null && _currentPosition != null) {
        final lat = data['latitude'] as double?;
        final lon = data['longitude'] as double?;

        if (lat != null && lon != null) {
          final distance = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            lat,
            lon,
          );

          if (distance > _filterState.maxDistance!) {
            return false;
          }
        } else {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ==================== SHOW FILTER MODAL ====================
  // NO CHANGES - Logic preserved
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterModal(
        filterState: _filterState,
        hasLocation: _currentPosition != null,
        onApply: (newFilterState) {
          setState(() {
            _filterState = newFilterState;
          });
        },
      ),
    );
  }

  // ==================== CLEAR ALL FILTERS ====================
  // NO CHANGES
  void _clearAllFilters() {
    setState(() {
      _filterState = const FilterState();
      _selectedCategory = 'All';
    });
  }

  // ==================== BUILD PROMOTIONS SECTION ====================
  // ENHANCED UI - Logic preserved
  Widget _buildPromotionsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('promotions')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final promotions = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final Timestamp? endDate = data['endDate'] as Timestamp?;
          if (endDate == null) return false;
          return endDate.toDate().isAfter(now);
        }).toList();

        if (promotions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: EdgeInsets.symmetric(vertical: AppTheme.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.space16),
                child: Row(
                  children: [
                    Icon(Icons.local_offer, color: AppTheme.accentYellow, size: 24),
                    SizedBox(width: AppTheme.space8),
                    Text('Special Offers', style: AppTheme.headlineMedium),
                  ],
                ),
              ),
              SizedBox(height: AppTheme.space12),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.space16),
                  itemCount: promotions.length,
                  itemBuilder: (context, index) {
                    final promo = promotions[index].data() as Map<String, dynamic>;
                    return _buildPromotionCard(promo);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== BUILD PROMOTION CARD ====================
  // ENHANCED UI - Modern card design
  Widget _buildPromotionCard(Map<String, dynamic> promo) {
    final String title = promo['title'] ?? 'Special Offer';
    final String description = promo['description'] ?? '';
    final String? imageUrl = promo['imageUrl'];
    final Timestamp? startDate = promo['startDate'] as Timestamp?;
    
    bool isScheduled = false;
    if (startDate != null) {
      isScheduled = startDate.toDate().isAfter(DateTime.now());
    }

    return Container(
      width: 280,
      margin: EdgeInsets.only(right: AppTheme.space12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCard,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            if (imageUrl != null && imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryGreen,
                        AppTheme.secondaryGreen,
                      ],
                    ).createShader(const Rect.fromLTWH(0, 0, 280, 180)) as Decoration,
                    child: const Center(
                      child: Icon(Icons.local_offer, color: Colors.white, size: 48),
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
                child: const Center(
                  child: Icon(Icons.local_offer, color: Colors.white, size: 48),
                ),
              ),
            
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            
            // Content
            Padding(
              padding: EdgeInsets.all(AppTheme.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Badge
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.space12,
                        vertical: AppTheme.space8,
                      ),
                      decoration: BoxDecoration(
                        color: isScheduled
                            ? AppTheme.accentYellow
                            : AppTheme.errorRed,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
                        boxShadow: AppTheme.shadowButton,
                      ),
                      child: Text(
                        isScheduled ? 'COMING SOON' : 'HOT DEAL',
                        style: AppTheme.labelSmall.copyWith(
                          color: isScheduled ? Colors.black87 : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  // Title and description
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.titleLarge.copyWith(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description.isNotEmpty) ...[
                        SizedBox(height: AppTheme.space8),
                        Text(
                          description,
                          style: AppTheme.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD CATEGORY FILTER ====================
  // ENHANCED UI - Better chip design
  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(vertical: AppTheme.space8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppTheme.space16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return Padding(
            padding: EdgeInsets.only(right: AppTheme.space8),
            child: FilterChip(
              label: Text(category, style: AppTheme.labelMedium),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              backgroundColor: Colors.white,
              selectedColor: AppTheme.primaryGreen,
              side: BorderSide(
                color: isSelected ? AppTheme.primaryGreen : AppTheme.borderLight,
                width: isSelected ? 2 : 1,
              ),
              labelStyle: AppTheme.labelMedium.copyWith(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              elevation: isSelected ? 2 : 0,
              shadowColor: AppTheme.shadowLight,
            ),
          );
        },
      ),
    );
  }

  // ==================== BUILD ESTABLISHMENT CARD ====================
  // ENHANCED UI - Modern card with better layout
  Widget _buildEstablishmentCard(DocumentSnapshot business) {
    final data = business.data() as Map<String, dynamic>;
    final businessName = data['businessName'] ?? 'Unnamed Business';
    final businessType = data['businessType'] ?? 'Restaurant';
    final businessAddress = data['businessAddress'] ?? 'No address';
    final logoUrl = data['logoUrl'];
    final avgRating = data['avgRating'] as double? ?? 0.0;
    final reviewCount = data['reviewCount'] as int? ?? 0;
    final approvalStatus = data['approvalStatus'] ?? 'pending';

    if (approvalStatus != 'approved') {
      return const SizedBox.shrink();
    }

    String? distanceText;
    if (_currentPosition != null && data['latitude'] != null && data['longitude'] != null) {
      final distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        data['latitude'],
        data['longitude'],
      );
      distanceText = '${distance.toStringAsFixed(1)} km';
    }

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EstablishmentDetailsPage(
                  establishmentId: business.id,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Padding(
            padding: EdgeInsets.all(AppTheme.space12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo with enhanced styling
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    boxShadow: AppTheme.shadowCardLight,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    child: logoUrl != null
                        ? Image.network(
                            logoUrl,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholderLogo();
                            },
                          )
                        : _buildPlaceholderLogo(),
                  ),
                ),
                SizedBox(width: AppTheme.space12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName,
                        style: AppTheme.titleMedium.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: AppTheme.space4),

                      // Category badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.space8,
                          vertical: AppTheme.space4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Text(
                          businessType,
                          style: AppTheme.labelSmall.copyWith(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: AppTheme.space8),

                      // Rating
                      if (reviewCount > 0)
                        Row(
                          children: [
                            Icon(Icons.star, size: 16, color: AppTheme.accentYellow),
                            SizedBox(width: AppTheme.space4),
                            Text(
                              avgRating.toStringAsFixed(1),
                              style: AppTheme.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            SizedBox(width: AppTheme.space4),
                            Text(
                              '($reviewCount)',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textHint,
                              ),
                            ),
                          ],
                        ),

                      // Distance
                      if (distanceText != null) ...[
                        SizedBox(height: AppTheme.space4),
                        Row(
                          children: [
                            Icon(Icons.navigation, size: 14, color: AppTheme.accentBlue),
                            SizedBox(width: AppTheme.space4),
                            Text(
                              distanceText,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.accentBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Bookmark button
                StreamBuilder<bool>(
                  stream: _bookmarkService.watchBookmarkStatus(business.id),
                  builder: (context, snapshot) {
                    final isBookmarked = snapshot.data ?? false;
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: isBookmarked
                            ? AppTheme.accentYellow.withOpacity(0.1)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: isBookmarked
                              ? AppTheme.accentYellow
                              : AppTheme.textSecondary,
                          size: 24,
                        ),
                        tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
                        onPressed: () => _handleBookmarkTap(
                          business.id,
                          businessName,
                          businessType,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderLogo() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Icon(
        Icons.restaurant,
        size: 40,
        color: AppTheme.primaryGreen.withOpacity(0.5),
      ),
    );
  }

  // ==================== BUILD ESTABLISHMENTS LIST ====================
  // ENHANCED UI - Better empty states and loading
  Widget _buildEstablishmentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(AppConfig.businessesCollection)
          .where('approvalStatus', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Container(
              padding: EdgeInsets.all(AppTheme.space32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(AppTheme.space20),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.errorRed,
                    ),
                  ),
                  SizedBox(height: AppTheme.space24),
                  Text('Error loading restaurants', style: AppTheme.titleMedium),
                  SizedBox(height: AppTheme.space8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppTheme.space32),
                    child: Text(
                      snapshot.error.toString(),
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: AppTheme.space24),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
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
                SizedBox(height: AppTheme.space24),
                Text(
                  'Loading restaurants...',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        var businesses = snapshot.data!.docs;

        if (_selectedCategory != 'All') {
          businesses = businesses.where((business) {
            final data = business.data() as Map<String, dynamic>;
            return data['businessType'] == _selectedCategory;
          }).toList();
        }

        businesses = _applyAdvancedFilters(businesses.cast<DocumentSnapshot>()).cast<QueryDocumentSnapshot>();

        if (businesses.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.space32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(AppTheme.space24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 80,
                      color: AppTheme.primaryGreen.withOpacity(0.5),
                    ),
                  ),
                  SizedBox(height: AppTheme.space24),
                  Text(
                    _filterState.hasActiveFilters
                        ? 'No restaurants match your filters'
                        : (_selectedCategory == 'All'
                            ? 'No restaurants found'
                            : 'No $_selectedCategory found'),
                    style: AppTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppTheme.space12),
                  Text(
                    _filterState.hasActiveFilters
                        ? 'Try adjusting your filters to see more results'
                        : 'Check back later for new businesses',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  if (_filterState.hasActiveFilters) ...[
                    SizedBox(height: AppTheme.space24),
                    ElevatedButton.icon(
                      onPressed: _clearAllFilters,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear Filters'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          color: AppTheme.primaryGreen,
          child: ListView.builder(
            itemCount: businesses.length,
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return _buildEstablishmentCard(businesses[index]);
            },
          ),
        );
      },
    );
  }

  // ==================== BUILD LOCATION BANNER ====================
  // ENHANCED UI - Modern banner design
  Widget _buildLocationBanner() {
    if (_isLoadingLocation) {
      return Container(
        padding: EdgeInsets.all(AppTheme.space12),
        decoration: BoxDecoration(
          color: AppTheme.accentBlue.withOpacity(0.1),
          border: Border(
            bottom: BorderSide(color: AppTheme.accentBlue.withOpacity(0.3), width: 1),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
              ),
            ),
            SizedBox(width: AppTheme.space12),
            Expanded(
              child: Text(
                'Getting your location...',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.accentBlue),
              ),
            ),
          ],
        ),
      );
    }

    if (_locationError != null) {
      return Container(
        padding: EdgeInsets.all(AppTheme.space12),
        decoration: BoxDecoration(
          color: AppTheme.warningOrange.withOpacity(0.1),
          border: Border(
            bottom: BorderSide(color: AppTheme.warningOrange.withOpacity(0.3), width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off, size: 20, color: AppTheme.warningOrange),
            SizedBox(width: AppTheme.space12),
            Expanded(
              child: Text(
                'Location unavailable',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.warningOrange),
              ),
            ),
            TextButton(
              onPressed: _getCurrentLocation,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.space12),
              ),
              child: Text(
                'Retry',
                style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.warningOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_currentPosition != null) {
      return Container(
        padding: EdgeInsets.all(AppTheme.space12),
        decoration: BoxDecoration(
          color: AppTheme.successGreen.withOpacity(0.1),
          border: Border(
            bottom: BorderSide(color: AppTheme.successGreen.withOpacity(0.3), width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.my_location, size: 20, color: AppTheme.successGreen),
            SizedBox(width: AppTheme.space12),
            Expanded(
              child: Text(
                'Showing restaurants near you',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.successGreen),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ==================== BUILD METHOD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search restaurants',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
          ),
          
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter',
                onPressed: _showFilterModal,
              ),
              if (_filterState.hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(AppTheme.space4),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.shadowButton,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '${_filterState.activeFilterCount}',
                      style: AppTheme.labelSmall.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Account',
            onPressed: _handleAccountNavigation,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildLocationBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => setState(() {}),
              color: AppTheme.primaryGreen,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildPromotionsSection()),
                  SliverToBoxAdapter(child: _buildCategoryFilter()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppTheme.space16,
                        AppTheme.space16,
                        AppTheme.space16,
                        AppTheme.space8,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.restaurant_menu, color: AppTheme.primaryGreen, size: 24),
                          SizedBox(width: AppTheme.space8),
                          Text(
                            'All Restaurants',
                            style: AppTheme.headlineMedium.copyWith(color: AppTheme.primaryGreen),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverFillRemaining(child: _buildEstablishmentsList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== FILTER MODAL WIDGET ====================
// ENHANCED UI - Modern modal design
class _FilterModal extends StatefulWidget {
  final FilterState filterState;
  final bool hasLocation;
  final Function(FilterState) onApply;

  const _FilterModal({
    required this.filterState,
    required this.hasLocation,
    required this.onApply,
  });

  @override
  State<_FilterModal> createState() => _FilterModalState();
}

class _FilterModalState extends State<_FilterModal> {
  late FilterState _filterState;

  final List<String> _categories = [
    'Tea & Coffee Shop',
    'Bakery',
    'Carinderia',
    'Pizzeria',
    'Casual Dining',
    'Fast Food',
    'Noodle & Soup Spot',
    'Food Stall',
  ];

  @override
  void initState() {
    super.initState();
    _filterState = widget.filterState;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXLarge)),
        boxShadow: AppTheme.shadowCardHeavy,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with gradient
          Container(
            padding: EdgeInsets.all(AppTheme.space20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryGreen, AppTheme.secondaryGreen],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXLarge)),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_list, color: Colors.white, size: 28),
                SizedBox(width: AppTheme.space12),
                Text(
                  'Filter Restaurants',
                  style: AppTheme.headlineMedium.copyWith(color: Colors.white, fontSize: 20),
                ),
                const Spacer(),
                if (_filterState.hasActiveFilters)
                  TextButton(
                    onPressed: () => setState(() => _filterState = const FilterState()),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.space16,
                        vertical: AppTheme.space8,
                      ),
                    ),
                    child: Text('Clear All', style: AppTheme.labelMedium.copyWith(color: Colors.white)),
                  ),
              ],
            ),
          ),

          // Filter options
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.space20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Categories', Icons.category),
                  SizedBox(height: AppTheme.space12),
                  Wrap(
                    spacing: AppTheme.space8,
                    runSpacing: AppTheme.space8,
                    children: _categories.map((category) {
                      final isSelected = _filterState.selectedCategories.contains(category);
                      return FilterChip(
                        label: Text(category, style: AppTheme.labelMedium),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            final newCategories = List<String>.from(_filterState.selectedCategories);
                            selected ? newCategories.add(category) : newCategories.remove(category);
                            _filterState = _filterState.copyWith(selectedCategories: newCategories);
                          });
                        },
                        backgroundColor: AppTheme.backgroundLight,
                        selectedColor: AppTheme.primaryGreen,
                        side: BorderSide(
                          color: isSelected ? AppTheme.primaryGreen : AppTheme.borderLight,
                          width: isSelected ? 2 : 1,
                        ),
                        labelStyle: AppTheme.labelMedium.copyWith(
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: AppTheme.space24),
                  const Divider(),
                  SizedBox(height: AppTheme.space24),

                  _buildSectionTitle('Minimum Rating', Icons.star),
                  SizedBox(height: AppTheme.space12),
                  _buildRatingSection(),

                  if (widget.hasLocation) ...[
                    SizedBox(height: AppTheme.space24),
                    const Divider(),
                    SizedBox(height: AppTheme.space24),
                    _buildSectionTitle('Distance', Icons.location_on),
                    SizedBox(height: AppTheme.space12),
                    _buildDistanceSection(),
                  ],
                ],
              ),
            ),
          ),

          // Apply button
          Container(
            padding: EdgeInsets.all(AppTheme.space20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_filterState);
                  Navigator.pop(context);
                },
                child: Text(
                  _filterState.hasActiveFilters
                      ? 'Apply Filters (${_filterState.activeFilterCount})'
                      : 'Apply Filters',
                  style: AppTheme.titleMedium.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppTheme.primaryGreen),
        SizedBox(width: AppTheme.space8),
        Text(
          title,
          style: AppTheme.titleMedium.copyWith(
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    final ratings = [
      {'value': 5, 'label': '5⭐ Only'},
      {'value': 4, 'label': '4⭐ & Above'},
      {'value': 3, 'label': '3⭐ & Above'},
      {'value': 2, 'label': '2⭐ & Above'},
    ];

    return Column(
      children: [
        ...ratings.map((rating) {
          final value = rating['value'] as int;
          final label = rating['label'] as String;
          return RadioListTile<int>(
            value: value,
            groupValue: _filterState.minRating,
            onChanged: (selected) {
              setState(() {
                _filterState = _filterState.copyWith(minRating: selected);
              });
            },
            title: Text(label, style: AppTheme.bodyMedium),
            activeColor: AppTheme.primaryGreen,
            contentPadding: EdgeInsets.zero,
          );
        }).toList(),
        RadioListTile<int?>(
          value: null,
          groupValue: _filterState.minRating,
          onChanged: (selected) {
            setState(() {
              _filterState = _filterState.copyWith(clearMinRating: true);
            });
          },
          title: Text('All Ratings', style: AppTheme.bodyMedium),
          activeColor: AppTheme.primaryGreen,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildDistanceSection() {
    final distances = [
      {'value': 1.0, 'label': '1 km'},
      {'value': 5.0, 'label': '5 km'},
      {'value': 10.0, 'label': '10 km'},
    ];

    return Column(
      children: [
        ...distances.map((distance) {
          final value = distance['value'] as double;
          final label = distance['label'] as String;
          return RadioListTile<double>(
            value: value,
            groupValue: _filterState.maxDistance,
            onChanged: (selected) {
              setState(() {
                _filterState = _filterState.copyWith(maxDistance: selected);
              });
            },
            title: Text('Within $label', style: AppTheme.bodyMedium),
            activeColor: AppTheme.primaryGreen,
            contentPadding: EdgeInsets.zero,
          );
        }).toList(),
        RadioListTile<double?>(
          value: null,
          groupValue: _filterState.maxDistance,
          onChanged: (selected) {
            setState(() {
              _filterState = _filterState.copyWith(clearMaxDistance: true);
            });
          },
          title: Text('Any Distance', style: AppTheme.bodyMedium),
          activeColor: AppTheme.primaryGreen,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}