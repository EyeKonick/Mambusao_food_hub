// ====================================================================
// ENHANCED BOOKMARKS PAGE
// UI Enhancement Phase - Modern, Clean Design with Poppins Font
// 
// ENHANCEMENTS:
// - Modern card-based bookmark listings
// - Enhanced label chips with better colors and shadows
// - Improved filter section with better visual hierarchy
// - Better empty state design
// - Enhanced dialogs and interactions
// - Consistent spacing and typography
// ====================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'services/bookmark_service.dart';
import 'establishment_details_page.dart';

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  // ==================== FIREBASE INSTANCES ====================
  final BookmarkService _bookmarkService = BookmarkService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== STATE VARIABLES ====================
  String? _selectedLabelFilter;

  // Predefined labels with colors
  final Map<String, Color> _labelColors = {
    'Want to Try': AppTheme.accentYellow,
    'Favorites': AppTheme.errorRed,
    'Date Night': Colors.pink,
    'Good for Groups': AppTheme.accentBlue,
  };

  // ==================== SHOW LABEL SELECTION DIALOG (ENHANCED) ====================
  Future<String?> _showLabelSelectionDialog(String currentLabel) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text(
          'Select Label',
          style: AppTheme.headlineMedium,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Predefined labels with enhanced design
              ..._labelColors.keys.map((label) => Container(
                margin: const EdgeInsets.only(bottom: AppTheme.space8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: currentLabel == label 
                        ? _labelColors[label]! 
                        : AppTheme.borderLight,
                    width: currentLabel == label ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _labelColors[label],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_labelColors[label] ?? Colors.grey).withOpacity(0.3),
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
                  trailing: currentLabel == label
                      ? Icon(
                          Icons.check_circle,
                          color: _labelColors[label],
                          size: 24,
                        )
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  onTap: () => Navigator.pop(context, label),
                ),
              )),
              
              const SizedBox(height: AppTheme.space8),
              const Divider(),
              const SizedBox(height: AppTheme.space8),
              
              // Remove label option
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: currentLabel.isEmpty 
                        ? AppTheme.primaryGreen 
                        : AppTheme.borderLight,
                    width: currentLabel.isEmpty ? 2 : 1,
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
                  trailing: currentLabel.isEmpty
                      ? const Icon(
                          Icons.check_circle,
                          color: AppTheme.successGreen,
                          size: 24,
                        )
                      : null,
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
            onPressed: () => Navigator.pop(context),
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

  // ==================== BUILD LABEL CHIP (ENHANCED) ====================
  Widget _buildLabelChip(String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    
    final color = _labelColors[label] ?? AppTheme.primaryGreen;
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          Text(
            label,
            style: AppTheme.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD LABEL FILTER SECTION (ENHANCED) ====================
  Widget _buildLabelFilter(List<Map<String, dynamic>> allBookmarks) {
    // Get unique labels from bookmarks
    final uniqueLabels = allBookmarks
        .map((b) => b['label'] as String?)
        .where((label) => label != null && label.isNotEmpty)
        .toSet()
        .toList();

    if (uniqueLabels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.filter_list,
                  size: 20,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Text(
                'Filter by Label',
                style: AppTheme.titleMedium.copyWith(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "All" filter chip
                Padding(
                  padding: const EdgeInsets.only(right: AppTheme.space8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _selectedLabelFilter == null,
                    onSelected: (selected) {
                      setState(() {
                        _selectedLabelFilter = null;
                      });
                    },
                    backgroundColor: AppTheme.backgroundLight,
                    selectedColor: AppTheme.primaryGreen,
                    side: BorderSide(
                      color: _selectedLabelFilter == null
                          ? AppTheme.primaryGreen
                          : AppTheme.borderLight,
                      width: _selectedLabelFilter == null ? 2 : 1,
                    ),
                    labelStyle: AppTheme.labelMedium.copyWith(
                      color: _selectedLabelFilter == null
                          ? Colors.white
                          : AppTheme.textPrimary,
                      fontWeight: _selectedLabelFilter == null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    elevation: _selectedLabelFilter == null ? 2 : 0,
                  ),
                ),
                
                // Label filter chips
                ...uniqueLabels.map((label) {
                  final color = _labelColors[label] ?? AppTheme.primaryGreen;
                  final isSelected = _selectedLabelFilter == label;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: AppTheme.space8),
                    child: FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppTheme.space8),
                          Text(label ?? ''),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedLabelFilter = selected ? label : null;
                        });
                      },
                      backgroundColor: color.withOpacity(0.1),
                      selectedColor: color,
                      side: BorderSide(
                        color: isSelected ? color : color.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      labelStyle: AppTheme.labelMedium.copyWith(
                        color: isSelected ? Colors.white : color,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      elevation: isSelected ? 2 : 0,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD BOOKMARK CARD (ENHANCED) ====================
  Widget _buildBookmarkCard(Map<String, dynamic> bookmark) {
    final businessId = bookmark['businessId'] as String;
    final businessName = bookmark['businessName'] ?? 'Unnamed Business';
    final businessType = bookmark['businessType'] ?? 'Restaurant';
    final label = bookmark['label'] as String? ?? '';
    
    // Get timestamp
    String bookmarkedText = 'Recently added';
    if (bookmark['bookmarkedAt'] != null) {
      final timestamp = bookmark['bookmarkedAt'] as Timestamp;
      final date = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        bookmarkedText = 'Added today';
      } else if (difference.inDays == 1) {
        bookmarkedText = 'Added yesterday';
      } else if (difference.inDays < 7) {
        bookmarkedText = 'Added ${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        bookmarkedText = 'Added $weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
      } else {
        bookmarkedText = 'Added ${date.toString().split(' ')[0]}';
      }
    }

    // Fetch business details from Firestore
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection(AppConfig.businessesCollection)
          .doc(businessId)
          .snapshots(),
      builder: (context, snapshot) {
        String? logoUrl;
        String? address;
        bool isApproved = true;
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          logoUrl = data['logoUrl'];
          address = data['businessAddress'];
          isApproved = data['approvalStatus'] == 'approved';
        }

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
                if (isApproved) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EstablishmentDetailsPage(
                        establishmentId: businessId,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white, size: 20),
                          const SizedBox(width: AppTheme.space8),
                          const Expanded(
                            child: Text('This business is no longer available'),
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
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space12),
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
                    const SizedBox(width: AppTheme.space12),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Business Name
                          Text(
                            businessName,
                            style: AppTheme.titleMedium.copyWith(fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppTheme.space4),

                          // Business Type
                          Container(
                            padding: const EdgeInsets.symmetric(
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
                          const SizedBox(height: AppTheme.space8),

                          // Label chip
                          if (label.isNotEmpty) ...[
                            _buildLabelChip(label),
                            const SizedBox(height: AppTheme.space8),
                          ],

                          // Address (if available)
                          if (address != null) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: AppTheme.space4),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.space4),
                          ],

                          // Bookmarked date
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: AppTheme.textHint,
                              ),
                              const SizedBox(width: AppTheme.space4),
                              Text(
                                bookmarkedText,
                                style: AppTheme.caption.copyWith(
                                  color: AppTheme.textHint,
                                ),
                              ),
                            ],
                          ),

                          // Status badge if not approved
                          if (!isApproved) ...[
                            const SizedBox(height: AppTheme.space8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.space8,
                                vertical: AppTheme.space4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 12,
                                    color: AppTheme.errorRed,
                                  ),
                                  const SizedBox(width: AppTheme.space4),
                                  Text(
                                    'UNAVAILABLE',
                                    style: AppTheme.labelSmall.copyWith(
                                      color: AppTheme.errorRed,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Actions column with enhanced buttons
                    Column(
                      children: [
                        // Edit label button
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.label_outline, size: 20),
                            color: AppTheme.accentBlue,
                            tooltip: 'Edit label',
                            onPressed: () => _editBookmarkLabel(businessId, label),
                          ),
                        ),
                        
                        const SizedBox(height: AppTheme.space4),
                        
                        // Remove bookmark button
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.accentYellow.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.bookmark, size: 20),
                            color: AppTheme.accentYellow,
                            tooltip: 'Remove bookmark',
                            onPressed: () => _removeBookmark(businessId, businessName),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Placeholder logo
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

  // ==================== EDIT BOOKMARK LABEL ====================
  Future<void> _editBookmarkLabel(String businessId, String currentLabel) async {
    final newLabel = await _showLabelSelectionDialog(currentLabel);
    
    if (newLabel == null) return; // User cancelled
    
    final success = await _bookmarkService.updateBookmarkLabel(
      businessId,
      newLabel.isEmpty ? null : newLabel,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: Text(
                  newLabel.isEmpty
                      ? 'Label removed'
                      : 'Label updated to "$newLabel"',
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
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: AppTheme.space8),
              const Expanded(child: Text('Failed to update label')),
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

  // ==================== REMOVE BOOKMARK (ENHANCED DIALOG) ====================
  Future<void> _removeBookmark(String businessId, String businessName) async {
    // Show confirmation dialog
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text(
          'Remove Bookmark',
          style: AppTheme.headlineMedium,
        ),
        content: Text(
          'Remove "$businessName" from your bookmarks?',
          style: AppTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
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
              'Remove',
              style: AppTheme.labelLarge.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldRemove == true) {
      final success = await _bookmarkService.removeBookmark(businessId);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: AppTheme.space8),
                const Text('Bookmark removed'),
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: AppTheme.space8),
                const Expanded(child: Text('Failed to remove bookmark')),
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

  // ==================== BUILD EMPTY STATE (ENHANCED) ====================
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with background
            Container(
              padding: const EdgeInsets.all(AppTheme.space32),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_border,
                size: 80,
                color: AppTheme.primaryGreen.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            
            // Title
            Text(
              _selectedLabelFilter != null
                  ? 'No "$_selectedLabelFilter" Bookmarks'
                  : 'No Bookmarks Yet',
              style: AppTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.space12),
            
            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space24),
              child: Text(
                _selectedLabelFilter != null
                    ? 'Try selecting a different label or clear the filter to see all your bookmarks'
                    : 'Start exploring and bookmark your favorite restaurants! Tap the bookmark icon on any restaurant to save it here.',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppTheme.space32),
            
            // Action button
            ElevatedButton.icon(
              onPressed: () {
                if (_selectedLabelFilter != null) {
                  setState(() {
                    _selectedLabelFilter = null;
                  });
                } else {
                  Navigator.pop(context); // Go back to home
                }
              },
              icon: Icon(
                _selectedLabelFilter != null ? Icons.clear_all : Icons.explore,
                size: 20,
              ),
              label: Text(
                _selectedLabelFilter != null
                    ? 'Clear Filter'
                    : 'Explore Restaurants',
              ),
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
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD METHOD (ENHANCED) ====================
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Safety check - should not happen if navigation is correct
    if (user == null || user.isAnonymous) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          title: Text(
            'My Bookmarks',
            style: AppTheme.titleLarge.copyWith(color: Colors.white),
          ),
          backgroundColor: AppTheme.primaryGreen,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.space24),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: AppTheme.errorRed,
                  ),
                ),
                const SizedBox(height: AppTheme.space24),
                Text(
                  'Sign In Required',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: AppTheme.space12),
                Text(
                  'Please sign in to view your bookmarks',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(
          'My Bookmarks',
          style: AppTheme.titleLarge.copyWith(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        actions: [
          // Bookmark count badge (enhanced)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _bookmarkService.getUserBookmarks(),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              if (count == 0) return const SizedBox.shrink();

              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppTheme.space16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space12,
                      vertical: AppTheme.space8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentYellow,
                      borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
                      boxShadow: AppTheme.shadowButton,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bookmark,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: AppTheme.space4),
                        Text(
                          '$count',
                          style: AppTheme.labelMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _bookmarkService.getUserBookmarks(),
        builder: (context, snapshot) {
          // Loading state (enhanced)
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
                  const SizedBox(height: AppTheme.space24),
                  Text(
                    'Loading bookmarks...',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          // Error state (enhanced)
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space20),
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
                    const SizedBox(height: AppTheme.space24),
                    Text(
                      'Error loading bookmarks',
                      style: AppTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppTheme.space12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space32),
                      child: Text(
                        snapshot.error.toString(),
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space24),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
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

          // Get all bookmarks
          final allBookmarks = snapshot.data ?? [];
          
          // Filter bookmarks by selected label
          final bookmarks = _selectedLabelFilter == null
              ? allBookmarks
              : allBookmarks.where((bookmark) {
                  final label = bookmark['label'] as String?;
                  return label == _selectedLabelFilter;
                }).toList();

          // Build UI
          return Column(
            children: [
              // Label filter (only show if there are labeled bookmarks)
              _buildLabelFilter(allBookmarks),

              // Bookmarks list or empty state
              Expanded(
                child: bookmarks.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async {
                          // Trigger rebuild
                          setState(() {});
                        },
                        color: AppTheme.primaryGreen,
                        child: ListView.builder(
                          itemCount: bookmarks.length,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
                          itemBuilder: (context, index) {
                            return _buildBookmarkCard(bookmarks[index]);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ====================================================================
// END OF ENHANCED BOOKMARKS PAGE
// ====================================================================