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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ==================== FIREBASE INSTANCES ====================
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BookmarkService _bookmarkService = BookmarkService();

  // ==================== STATE VARIABLES ====================
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String? _locationError;
  String _selectedCategory = 'All';
  FilterState _filterState = const FilterState();
  Map<String, double> _businessAvgRatingCache = {};

  // Categories for filtering
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
  // ==================== BOOKMARK HANDLING ====================
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

  // Check if already bookmarked
  final isCurrentlyBookmarked = await _bookmarkService.isBookmarked(businessId);

  if (isCurrentlyBookmarked) {
    // Already bookmarked - just remove it
    final success = await _bookmarkService.removeBookmark(businessId);
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from bookmarks'),
          backgroundColor: AppTheme.textSecondary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  } else {
    // Not bookmarked - show label selection dialog
    final label = await _showLabelSelectionDialog();
    
    if (label == null && !mounted) return; // User cancelled
    
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
          content: Text(
            label != null && label.isNotEmpty
                ? '✓ Added to "$label"'
                : '✓ Added to bookmarks',
          ),
          backgroundColor: AppTheme.successGreen,
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
}

// ==================== LABEL SELECTION DIALOG ====================
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
      title: const Text('Add Label (Optional)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Predefined labels
            ...labelColors.keys.map((label) => ListTile(
              leading: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: labelColors[label],
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(label),
              onTap: () => Navigator.pop(context, label),
            )),
            
            const Divider(),
            
            // No label option
            ListTile(
              leading: const Icon(Icons.bookmark_border, color: AppTheme.textSecondary),
              title: const Text('No Label'),
              onTap: () => Navigator.pop(context, ''),
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
          const SnackBar(
            content: Text('Welcome back!'),
            backgroundColor: AppTheme.successGreen,
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
  List<DocumentSnapshot> _applyAdvancedFilters(List<DocumentSnapshot> businesses) {
    if (!_filterState.hasActiveFilters) {
      return businesses;
    }

    return businesses.where((business) {
      final data = business.data() as Map<String, dynamic>;

      // Category filter (multi-select)
      if (_filterState.selectedCategories.isNotEmpty) {
        final businessType = data['businessType'] as String?;
        if (businessType == null || !_filterState.selectedCategories.contains(businessType)) {
          return false;
        }
      }

      // Apply rating filter (using stored avgRating)
      if (_filterState.minRating != null) {
        final businessId = business.id;
        final avgRating = data['avgRating'] as double? ?? 0.0;
        
        // Cache the rating for quick lookups
        _businessAvgRatingCache[businessId] = avgRating;
        
        if (avgRating < _filterState.minRating!) {
          return false;
        }
      }

      // Distance filter
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
          // Exclude businesses without location when distance filter is active
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ==================== SHOW FILTER MODAL ====================
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
  void _clearAllFilters() {
    setState(() {
      _filterState = const FilterState();
      _selectedCategory = 'All';
    });
  }

  // ==================== BUILD PROMOTIONS SECTION ====================
  Widget _buildPromotionsSection() {
    debugPrint('Building promotions section...');
    
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('promotions')
          .where('isActive', isEqualTo: true)
          .snapshots(), // Single where clause - no index needed
      builder: (context, snapshot) {
        debugPrint('Promotions stream state: ${snapshot.connectionState}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('Promotions: Still waiting...');
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          debugPrint('Promotions stream error: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData) {
          debugPrint('Promotions: No data');
          return const SizedBox.shrink();
        }

        // Filter promotions that haven't expired (endDate > now) in Dart
        final now = DateTime.now();
        final promotions = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final Timestamp? endDate = data['endDate'] as Timestamp?;
          if (endDate == null) return false;
          return endDate.toDate().isAfter(now);
        }).toList();

        debugPrint('✓ Promotions received: ${promotions.length}');

        if (promotions.isEmpty) {
          debugPrint('Promotions list is empty after filtering');
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Special Offers', style: AppTheme.headingMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: promotions.length,
                itemBuilder: (context, index) {
                  final promo = promotions[index].data() as Map<String, dynamic>;
                  debugPrint('Building promo card $index: ${promo['title']}');
                  return _buildPromotionCard(promo);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  // ==================== BUILD PROMOTION CARD ====================
  Widget _buildPromotionCard(Map<String, dynamic> promo) {
    final String title = promo['title'] ?? 'Special Offer';
    final String? imageUrl = promo['imageUrl'];
    final Timestamp? startDate = promo['startDate'] as Timestamp?;
    
    // Determine if promotion is scheduled (hasn't started yet) or active
    bool isScheduled = false;
    if (startDate != null) {
      isScheduled = startDate.toDate().isAfter(DateTime.now());
    }
    
    debugPrint('Promo "$title": scheduled=$isScheduled');

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppTheme.primaryGreen,
                      child: const Center(
                        child: Icon(Icons.local_offer, color: Colors.white, size: 40),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                color: AppTheme.primaryGreen,
                child: const Center(
                  child: Icon(Icons.local_offer, color: Colors.white, size: 40),
                ),
              ),
            
            // Dark overlay
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isScheduled
                          ? AppTheme.accentYellow
                          : AppTheme.errorRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isScheduled ? 'COMING SOON' : 'HOT DEAL',
                      style: TextStyle(
                        color: isScheduled ? Colors.black87 : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
  Widget _buildCategoryFilter() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              backgroundColor: AppTheme.surfaceColor,
              selectedColor: AppTheme.primaryGreen,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== BUILD ESTABLISHMENT CARD ====================
  Widget _buildEstablishmentCard(DocumentSnapshot business) {
    final data = business.data() as Map<String, dynamic>;
    final businessName = data['businessName'] ?? 'Unnamed Business';
    final businessType = data['businessType'] ?? 'Restaurant';
    final businessAddress = data['businessAddress'] ?? 'No address';
    final logoUrl = data['logoUrl'];
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
      distanceText = '${distance.toStringAsFixed(1)} km away';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: logoUrl != null
                    ? Image.network(
                        logoUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderLogo();
                        },
                      )
                    : _buildPlaceholderLogo(),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessName,
                      style: AppTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        businessType,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            businessAddress,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    if (distanceText != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.navigation,
                            size: 16,
                            color: AppTheme.accentBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            distanceText,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.accentBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              StreamBuilder<bool>(
                stream: _bookmarkService.watchBookmarkStatus(business.id),
                builder: (context, snapshot) {
                  final isBookmarked = snapshot.data ?? false;
                  
                  return IconButton(
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: isBookmarked
                          ? AppTheme.accentYellow
                          : AppTheme.textSecondary,
                    ),
                    tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
                    onPressed: () => _handleBookmarkTap(
                      business.id,
                      businessName,
                      businessType,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.restaurant,
        size: 40,
        color: AppTheme.primaryGreen,
      ),
    );
  }

  // ==================== BUILD ESTABLISHMENTS LIST ====================
Widget _buildEstablishmentsList() {
  return StreamBuilder<QuerySnapshot>(
    stream: _firestore
        .collection(AppConfig.businessesCollection)
        .where('approvalStatus', isEqualTo: 'approved')
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
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
                'Error loading restaurants',
                style: AppTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  snapshot.error.toString(),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {});
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      }

      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryGreen),
              const SizedBox(height: 16),
              Text(
                'Loading restaurants...',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        );
      }

      var businesses = snapshot.data!.docs;

      // Apply category filter from category chips
      if (_selectedCategory != 'All') {
        businesses = businesses.where((business) {
          final data = business.data() as Map<String, dynamic>;
          return data['businessType'] == _selectedCategory;
        }).toList();
      }

      // Apply advanced filters (rating, distance, multi-category)
      // Convert to List<DocumentSnapshot> for filtering, then back
      businesses = _applyAdvancedFilters(businesses.cast<DocumentSnapshot>()).cast<QueryDocumentSnapshot>();

      if (businesses.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 80,
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                ),
                const SizedBox(height: 24),
                Text(
                  _filterState.hasActiveFilters
                      ? 'No restaurants match your filters'
                      : (_selectedCategory == 'All'
                          ? 'No restaurants found'
                          : 'No $_selectedCategory found'),
                  style: AppTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _filterState.hasActiveFilters
                      ? 'Try adjusting your filters to see more results'
                      : 'Check back later for new businesses',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_filterState.hasActiveFilters) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _clearAllFilters,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Filters'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: ListView.builder(
          itemCount: businesses.length,
          itemBuilder: (context, index) {
            return _buildEstablishmentCard(businesses[index]);
          },
        ),
      );
    },
  );
}

  // ==================== BUILD LOCATION BANNER ====================
  Widget _buildLocationBanner() {
    if (_isLoadingLocation) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: AppTheme.accentBlue.withOpacity(0.1),
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
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Getting your location...',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.accentBlue,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_locationError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: AppTheme.warningOrange.withOpacity(0.1),
        child: Row(
          children: [
            Icon(
              Icons.location_off,
              size: 20,
              color: AppTheme.warningOrange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Location unavailable',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.warningOrange,
                ),
              ),
            ),
            TextButton(
              onPressed: _getCurrentLocation,
              child: Text(
                'Retry',
                style: AppTheme.bodySmall.copyWith(
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
        padding: const EdgeInsets.all(12),
        color: AppTheme.successGreen.withOpacity(0.1),
        child: Row(
          children: [
            Icon(
              Icons.my_location,
              size: 20,
              color: AppTheme.successGreen,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Showing restaurants near you',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.successGreen,
                ),
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
          
          // Filter button with badge
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
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.errorRed,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_filterState.activeFilterCount}',
                      style: const TextStyle(
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
              onRefresh: () async {
                setState(() {});
              },
              child: CustomScrollView(
                slivers: [
                  // Promotions Section
                  SliverToBoxAdapter(
                    child: _buildPromotionsSection(),
                  ),

                  // Category Filter
                  SliverToBoxAdapter(
                    child: _buildCategoryFilter(),
                  ),

                  // Restaurants Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            color: AppTheme.primaryGreen,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'All Restaurants',
                            style: AppTheme.headingMedium.copyWith(
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Establishments List
                  SliverFillRemaining(
                    child: _buildEstablishmentsList(),
                  ),
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_list, color: Colors.white),
                const SizedBox(width: 12),
                const Text(
                  'Filter Restaurants',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_filterState.hasActiveFilters)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterState = const FilterState();
                      });
                    },
                    child: const Text(
                      'Clear All',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),

          // Filter Options
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories Section
                  _buildSectionTitle('Categories', Icons.category),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((category) {
                      final isSelected = _filterState.selectedCategories.contains(category);
                      return FilterChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            final newCategories = List<String>.from(_filterState.selectedCategories);
                            if (selected) {
                              if (!newCategories.contains(category)) {
                                newCategories.add(category);
                              }
                            } else {
                              newCategories.remove(category);
                            }
                            _filterState = _filterState.copyWith(selectedCategories: newCategories);
                          });
                        },
                        backgroundColor: AppTheme.surfaceColor,
                        selectedColor: AppTheme.primaryGreen,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Rating Section
                  _buildSectionTitle('Minimum Rating', Icons.star),
                  const SizedBox(height: 12),
                  _buildRatingSection(),

                  // Distance Section (only if location available)
                  if (widget.hasLocation) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Distance', Icons.location_on),
                    const SizedBox(height: 12),
                    _buildDistanceSection(),
                  ],
                ],
              ),
            ),
          ),

          // Apply Button
          Container(
            padding: const EdgeInsets.all(20),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _filterState.hasActiveFilters
                      ? 'Apply Filters (${_filterState.activeFilterCount})'
                      : 'Apply Filters',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
        Icon(icon, size: 20, color: AppTheme.primaryGreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryGreen,
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
            title: Text(label),
            activeColor: AppTheme.primaryGreen,
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
          title: const Text('All Ratings'),
          activeColor: AppTheme.primaryGreen,
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
            title: Text('Within $label'),
            activeColor: AppTheme.primaryGreen,
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
          title: const Text('Any Distance'),
          activeColor: AppTheme.primaryGreen,
        ),
      ],
    );
  }
}
