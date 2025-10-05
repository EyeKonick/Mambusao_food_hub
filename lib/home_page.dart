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
  /// Handle bookmark button tap
  Future<void> _handleBookmarkTap(
    String businessId,
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
          await _handleBookmarkTap(businessId, businessName, businessType);
        }
      }
      return;
    }

    // User is authenticated - toggle bookmark
    final success = await _bookmarkService.toggleBookmark(
      businessId: businessId,
      businessName: businessName,
      businessType: businessType,
    );

    if (!mounted) return;

    // Show feedback
    if (success) {
      final isBookmarked = await _bookmarkService.isBookmarked(businessId);
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

  // ==================== ACCOUNT NAVIGATION ====================
  /// Handles account navigation based on authentication state
  Future<void> _handleAccountNavigation() async {
    final user = FirebaseAuth.instance.currentUser;
    
    // Check if user is signed in (not anonymous)
    if (user == null || user.isAnonymous) {
      // User not signed in - navigate to login/registration
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UserAuthPage()),
      );
      
      // If user successfully logged in, refresh the page
      if (result == true && mounted) {
        setState(() {}); // Refresh to show updated state
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome back!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } else {
      // User is signed in - navigate to profile
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UserProfilePage()),
      );
      
      // Refresh in case user signed out
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
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable them in settings.');
      }

      // Check location permissions
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

      // Get current position
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

  // Calculate distance between two coordinates (in kilometers)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to km
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

    // Only show approved businesses
    if (approvalStatus != 'approved') {
      return const SizedBox.shrink();
    }

    // Calculate distance if location is available
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
                    // Business Name
                    Text(
                      businessName,
                      style: AppTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Business Type
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

                    // Address
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

                    // Distance (if available)
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

              // Bookmark button
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

  // Placeholder logo when no image is available
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
                    setState(() {}); // Trigger rebuild
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

        // Filter by category
        var businesses = snapshot.data!.docs;
        if (_selectedCategory != 'All') {
          businesses = businesses.where((business) {
            final data = business.data() as Map<String, dynamic>;
            return data['businessType'] == _selectedCategory;
          }).toList();
        }

        if (businesses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 64,
                  color: AppTheme.primaryGreen.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedCategory == 'All'
                      ? 'No restaurants found'
                      : 'No $_selectedCategory found',
                  style: AppTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back later for new businesses',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {}); // Trigger rebuild
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
          // Search button
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
          
          // Account button
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Account',
            onPressed: () => _handleAccountNavigation(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Location banner
          _buildLocationBanner(),

          // Category filter
          _buildCategoryFilter(),

          // Establishments list
          Expanded(
            child: _buildEstablishmentsList(),
          ),
        ],
      ),
    );
  }
}