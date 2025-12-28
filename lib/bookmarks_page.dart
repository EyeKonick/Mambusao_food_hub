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

  // ==================== SHOW LABEL SELECTION DIALOG ====================
  Future<String?> _showLabelSelectionDialog(String currentLabel) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Label'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Predefined labels
              ..._labelColors.keys.map((label) => ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _labelColors[label],
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(label),
                trailing: currentLabel == label
                    ? const Icon(Icons.check, color: AppTheme.successGreen)
                    : null,
                onTap: () => Navigator.pop(context, label),
              )),
              
              const Divider(),
              
              // Remove label option
              ListTile(
                leading: const Icon(Icons.clear, color: AppTheme.textSecondary),
                title: const Text('No Label'),
                trailing: currentLabel.isEmpty
                    ? const Icon(Icons.check, color: AppTheme.successGreen)
                    : null,
                onTap: () => Navigator.pop(context, ''),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD LABEL CHIP ====================
  Widget _buildLabelChip(String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    
    final color = _labelColors[label] ?? AppTheme.primaryGreen;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
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
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD LABEL FILTER DROPDOWN ====================
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryGreen.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            size: 20,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(width: 12),
          Text(
            'Filter:',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // "All" filter chip
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _selectedLabelFilter == null,
                      onSelected: (selected) {
                        setState(() {
                          _selectedLabelFilter = null;
                        });
                      },
                      backgroundColor: AppTheme.surfaceColor,
                      selectedColor: AppTheme.primaryGreen,
                      labelStyle: TextStyle(
                        color: _selectedLabelFilter == null
                            ? Colors.white
                            : AppTheme.textPrimary,
                        fontWeight: _selectedLabelFilter == null
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  
                  // Label filter chips
                  ...uniqueLabels.map((label) {
                    final color = _labelColors[label] ?? AppTheme.primaryGreen;
                    final isSelected = _selectedLabelFilter == label;
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
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
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : color,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD BOOKMARK CARD ====================
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

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  const SnackBar(
                    content: Text('This business is no longer available'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
              }
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

                        // Label chip
                        if (label.isNotEmpty) ...[
                          _buildLabelChip(label),
                          const SizedBox(height: 8),
                        ],

                        // Address (if available)
                        if (address != null)
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

                        // Bookmarked date
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              bookmarkedText,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        // Status badge if not approved
                        if (!isApproved) ...[
                          const SizedBox(height: 4),
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
                              'UNAVAILABLE',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.errorRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Actions column
                  Column(
                    children: [
                      // Edit label button
                      IconButton(
                        icon: const Icon(Icons.label_outline, size: 20),
                        color: AppTheme.accentBlue,
                        tooltip: 'Edit label',
                        onPressed: () => _editBookmarkLabel(businessId, label),
                      ),
                      
                      // Remove bookmark button
                      IconButton(
                        icon: const Icon(Icons.bookmark, size: 20),
                        color: AppTheme.accentYellow,
                        tooltip: 'Remove bookmark',
                        onPressed: () => _removeBookmark(businessId, businessName),
                      ),
                    ],
                  ),
                ],
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
          content: Text(
            newLabel.isEmpty
                ? 'Label removed'
                : 'Label updated to "$newLabel"',
          ),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update label'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  // ==================== REMOVE BOOKMARK ====================
  Future<void> _removeBookmark(String businessId, String businessName) async {
    // Show confirmation dialog
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Bookmark'),
        content: Text('Remove "$businessName" from your bookmarks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldRemove == true) {
      final success = await _bookmarkService.removeBookmark(businessId);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bookmark removed'),
            backgroundColor: AppTheme.textSecondary,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove bookmark'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  // ==================== BUILD EMPTY STATE ====================
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 100,
              color: AppTheme.primaryGreen.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              _selectedLabelFilter != null
                  ? 'No "$_selectedLabelFilter" Bookmarks'
                  : 'No Bookmarks Yet',
              style: AppTheme.headingMedium,
            ),
            const SizedBox(height: 12),
            Text(
              _selectedLabelFilter != null
                  ? 'Try selecting a different label or clear the filter'
                  : 'Start exploring and bookmark your favorite restaurants!',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
                _selectedLabelFilter != null ? Icons.clear : Icons.explore,
              ),
              label: Text(
                _selectedLabelFilter != null
                    ? 'Clear Filter'
                    : 'Explore Restaurants',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD METHOD ====================
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Safety check - should not happen if navigation is correct
    if (user == null || user.isAnonymous) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Bookmarks'),
        ),
        body: const Center(
          child: Text('Please sign in to view bookmarks'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookmarks'),
        actions: [
          // Bookmark count badge
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _bookmarkService.getUserBookmarks(),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              if (count == 0) return const SizedBox.shrink();

              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentYellow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryGreen),
                  const SizedBox(height: 16),
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

          // Error state
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
                    'Error loading bookmarks',
                    style: AppTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
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
                        child: ListView.builder(
                          itemCount: bookmarks.length,
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