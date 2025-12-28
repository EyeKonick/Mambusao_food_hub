// ====================================================================
// ENHANCED SEARCH PAGE
// UI Enhancement Phase - Modern, Clean Design with Poppins Font
// 
// ENHANCEMENTS:
// - Modern search bar with enhanced styling
// - Better business cards with improved layout
// - Enhanced empty states (initial + no results)
// - Improved suggestion chips
// - Better loading indicators
// - Enhanced results counter
// 
// BUSINESS LOGIC: 100% PRESERVED - NO CHANGES
// ====================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'establishment_details_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // ==================== FIREBASE & STATE ====================
  // NO CHANGES - Business logic preserved
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==================== SEARCH FUNCTION ====================
  // NO CHANGES - Business logic preserved
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      // Convert query to lowercase for case-insensitive search
      final searchQuery = query.toLowerCase().trim();

      // Get all approved businesses
      final snapshot = await _firestore
          .collection(AppConfig.businessesCollection)
          .where('approvalStatus', isEqualTo: 'approved')
          .get();

      // Filter results based on search query
      final results = snapshot.docs.where((doc) {
        final data = doc.data();
        final businessName = (data['businessName'] ?? '').toString().toLowerCase();
        final businessType = (data['businessType'] ?? '').toString().toLowerCase();
        final businessAddress = (data['businessAddress'] ?? '').toString().toLowerCase();

        // Search in business name, type, and address
        return businessName.contains(searchQuery) ||
            businessType.contains(searchQuery) ||
            businessAddress.contains(searchQuery);
      }).toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✓ Search completed: ${results.length} results for "$query"');
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Search error: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Search error: $e',
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

  // ==================== BUILD SEARCH BAR (ENHANCED) ====================
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: AppTheme.borderLight,
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          style: AppTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Search restaurants, cafes, carinderias...',
            hintStyle: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textHint,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(AppTheme.space12),
              child: Icon(
                Icons.search,
                color: AppTheme.primaryGreen,
                size: 24,
              ),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _performSearch('');
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space16,
              vertical: AppTheme.space16,
            ),
          ),
          onChanged: (value) {
            setState(() {}); // Update UI for clear button
            _performSearch(value);
          },
          onSubmitted: (value) {
            _performSearch(value);
          },
        ),
      ),
    );
  }

  // ==================== BUILD BUSINESS CARD (ENHANCED) ====================
  Widget _buildBusinessCard(DocumentSnapshot business) {
    final data = business.data() as Map<String, dynamic>;
    final businessName = data['businessName'] ?? 'Unnamed Business';
    final businessType = data['businessType'] ?? 'Restaurant';
    final businessAddress = data['businessAddress'] ?? 'No address';
    final logoUrl = data['logoUrl'];

    return Container(
      margin: const EdgeInsets.symmetric(
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
            padding: const EdgeInsets.all(AppTheme.space12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo (Enhanced)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    boxShadow: AppTheme.shadowCardLight,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    child: logoUrl != null && logoUrl.isNotEmpty
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
                ),
                const SizedBox(width: AppTheme.space12),

                // Details (Enhanced)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Business Name
                      Text(
                        businessName,
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTheme.space8),

                      // Business Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space12,
                          vertical: AppTheme.space4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
                          border: Border.all(
                            color: AppTheme.primaryGreen.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          businessType,
                          style: AppTheme.labelSmall.copyWith(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space8),

                      // Address
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: AppTheme.space4),
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
                    ],
                  ),
                ),

                const SizedBox(width: AppTheme.space8),

                // Arrow Icon (Enhanced)
                Container(
                  padding: const EdgeInsets.all(AppTheme.space8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== BUILD PLACEHOLDER LOGO (ENHANCED) ====================
  Widget _buildPlaceholderLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.lightGreen,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Icon(
        Icons.restaurant,
        size: 40,
        color: AppTheme.primaryGreen.withOpacity(0.7),
      ),
    );
  }

  // ==================== BUILD EMPTY STATE (ENHANCED) ====================
  Widget _buildEmptyState() {
    if (!_hasSearched) {
      // Initial state - no search performed yet (Enhanced)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Search Icon Container
              Container(
                padding: const EdgeInsets.all(AppTheme.space32),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: Icon(
                  Icons.search,
                  size: 80,
                  color: AppTheme.primaryGreen.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: AppTheme.space32),
              
              // Title
              Text(
                'Search for restaurants',
                style: AppTheme.headlineMedium.copyWith(
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              
              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.space24),
                child: Text(
                  'Try searching by name, type, or location',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppTheme.space32),
              
              // Quick Search Suggestions
              Text(
                'Quick search suggestions:',
                style: AppTheme.labelLarge.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.space16),
              
              Wrap(
                spacing: AppTheme.space12,
                runSpacing: AppTheme.space12,
                alignment: WrapAlignment.center,
                children: [
                  _buildSuggestionChip('Carinderia', Icons.restaurant),
                  _buildSuggestionChip('Cafe', Icons.local_cafe),
                  _buildSuggestionChip('Restaurant', Icons.dinner_dining),
                  _buildSuggestionChip('Fast Food', Icons.fastfood),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      // No results found (Enhanced)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // No Results Icon Container
              Container(
                padding: const EdgeInsets.all(AppTheme.space32),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.textSecondary.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: Icon(
                  Icons.search_off,
                  size: 80,
                  color: AppTheme.textSecondary.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: AppTheme.space32),
              
              // Title
              Text(
                'No results found',
                style: AppTheme.headlineMedium.copyWith(
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              
              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.space24),
                child: Text(
                  'Try different keywords or check your spelling',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppTheme.space24),
              
              // Try Again Button
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchResults = [];
                    _hasSearched = false;
                  });
                },
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Try New Search'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                  side: const BorderSide(
                    color: AppTheme.primaryGreen,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space24,
                    vertical: AppTheme.space12,
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
  }

  // ==================== BUILD SUGGESTION CHIP (ENHANCED) ====================
  Widget _buildSuggestionChip(String label, IconData icon) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
      elevation: 2,
      child: InkWell(
        onTap: () {
          _searchController.text = label;
          _performSearch(label);
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space16,
            vertical: AppTheme.space12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
            border: Border.all(
              color: AppTheme.primaryGreen.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(width: AppTheme.space8),
              Text(
                label,
                style: AppTheme.labelLarge.copyWith(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== BUILD METHOD (ENHANCED) ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Search',
          style: AppTheme.titleLarge.copyWith(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Results or empty state
          Expanded(
            child: _isSearching
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
                          'Searching...',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : _searchResults.isEmpty
                    ? _buildEmptyState()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Results count banner (Enhanced)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.space16,
                              vertical: AppTheme.space12,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              border: const Border(
                                bottom: BorderSide(
                                  color: AppTheme.borderLight,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 20,
                                  color: AppTheme.primaryGreen,
                                ),
                                const SizedBox(width: AppTheme.space8),
                                Text(
                                  '${_searchResults.length} result${_searchResults.length == 1 ? '' : 's'} found',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Results list
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.space8,
                              ),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                return _buildBusinessCard(_searchResults[index]);
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// END OF ENHANCED SEARCH PAGE
// Business Logic: 100% Preserved
// UI: Fully Enhanced with Modern Design
// ====================================================================