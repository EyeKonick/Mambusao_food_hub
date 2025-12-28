// ====================================================================
// ENHANCED ADMIN USER MANAGEMENT PAGE
// UI Enhancement Phase - Modern, Clean Design with Poppins Font
// 
// ENHANCEMENTS:
// - Modern user cards with expansion tiles
// - Enhanced search bar with rounded design
// - Better stat displays with color coding
// - Improved action buttons
// - Enhanced empty states
// - Modern dialogs and confirmations
// - Better loading indicators
// 
// BUSINESS LOGIC: 100% PRESERVED - NO CHANGES
// ====================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';

class AdminUserManagementPage extends StatefulWidget {
  const AdminUserManagementPage({super.key});

  @override
  State<AdminUserManagementPage> createState() => _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage> {
  // ==================== FIREBASE & STATE ====================
  // NO CHANGES - Business logic preserved
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==================== GET USER STATS ====================
  // NO CHANGES - Business logic preserved
  Future<Map<String, int>> _getUserStats(String userId) async {
    try {
      final bookmarksSnapshot = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(userId)
          .collection(AppConfig.bookmarksSubcollection)
          .get();

      int reviewCount = 0;
      final businessesSnapshot = await _firestore
          .collection(AppConfig.businessesCollection)
          .get();

      for (var businessDoc in businessesSnapshot.docs) {
        try {
          final reviewsSnapshot = await _firestore
              .collection(AppConfig.businessesCollection)
              .doc(businessDoc.id)
              .collection(AppConfig.reviewsSubcollection)
              .where('userId', isEqualTo: userId)
              .get();
          reviewCount += reviewsSnapshot.docs.length;
        } catch (e) {
          continue;
        }
      }

      return {'bookmarks': bookmarksSnapshot.docs.length, 'reviews': reviewCount};
    } catch (e) {
      return {'bookmarks': 0, 'reviews': 0};
    }
  }

  // ==================== TOGGLE USER STATUS ====================
  // ENHANCED UI - Dialog styling improved, logic preserved
  Future<void> _toggleUserStatus(DocumentSnapshot user) async {
    final data = user.data() as Map<String, dynamic>;
    final currentStatus = data['isActive'] ?? true;
    final userName = data['name'] ?? 'User';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text(
          '${currentStatus ? 'Deactivate' : 'Activate'} User',
          style: AppTheme.headlineMedium,
        ),
        content: Text(
          currentStatus
              ? 'Deactivate $userName?\n\nThey won\'t be able to:\n• Write reviews\n• Bookmark businesses\n• Use app features'
              : 'Activate $userName?\n\nThey will regain full access.',
          style: AppTheme.bodyLarge.copyWith(height: 1.6),
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
              backgroundColor: currentStatus ? AppTheme.warningOrange : AppTheme.successGreen,
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
              currentStatus ? 'Deactivate' : 'Activate',
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

    // NO CHANGES - Firebase update logic preserved
    try {
      await _firestore.collection(AppConfig.usersCollection).doc(user.id).update({
        'isActive': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'User ${currentStatus ? 'deactivated' : 'activated'}',
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

  // ==================== DELETE USER ====================
  // ENHANCED UI - Dialog styling improved, logic preserved
  Future<void> _deleteUser(DocumentSnapshot user) async {
    final data = user.data() as Map<String, dynamic>;
    final userName = data['name'] ?? 'User';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text(
          'Delete User',
          style: AppTheme.headlineMedium.copyWith(
            color: AppTheme.errorRed,
          ),
        ),
        content: Text(
          'Permanently delete $userName?\n\nThis will delete:\n• User account\n• All bookmarks\n• All reviews\n\nThis action cannot be undone.',
          style: AppTheme.bodyLarge.copyWith(height: 1.6),
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
      final bookmarks = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.id)
          .collection(AppConfig.bookmarksSubcollection)
          .get();
      
      for (var doc in bookmarks.docs) {
        await doc.reference.delete();
      }

      final businessesSnapshot = await _firestore
          .collection(AppConfig.businessesCollection)
          .get();

      for (var businessDoc in businessesSnapshot.docs) {
        final reviewsSnapshot = await _firestore
            .collection(AppConfig.businessesCollection)
            .doc(businessDoc.id)
            .collection(AppConfig.reviewsSubcollection)
            .where('userId', isEqualTo: user.id)
            .get();
        
        for (var reviewDoc in reviewsSnapshot.docs) {
          await reviewDoc.reference.delete();
        }
      }

      await user.reference.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '$userName deleted',
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

  // ==================== BUILD USER CARD (ENHANCED) ====================
  Widget _buildUserCard(DocumentSnapshot user) {
    final data = user.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown User';
    final email = data['email'] ?? 'No email';
    final phoneNumber = data['phoneNumber'] ?? 'No phone';
    final isActive = data['isActive'] ?? true;
    final photoUrl = data['photoUrl'];
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    // ENHANCED UI - Modern card design
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCard,
        border: !isActive
            ? Border.all(color: AppTheme.errorRed.withOpacity(0.3), width: 2)
            : null,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space16,
            vertical: AppTheme.space8,
          ),
          childrenPadding: const EdgeInsets.all(AppTheme.space16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          leading: Stack(
            children: [
              // User Avatar (Enhanced)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? AppTheme.primaryGreen.withOpacity(0.3)
                        : AppTheme.errorRed.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: AppTheme.shadowCardLight,
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          name[0].toUpperCase(),
                          style: AppTheme.headlineMedium.copyWith(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              
              // Inactive Badge
              if (!isActive)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: AppTheme.shadowButton,
                    ),
                    child: const Icon(
                      Icons.block,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space12,
                    vertical: AppTheme.space4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
                    border: Border.all(
                      color: AppTheme.errorRed.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'INACTIVE',
                    style: AppTheme.labelSmall.copyWith(
                      color: AppTheme.errorRed,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppTheme.space4),
            child: Text(
              email,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          children: [
            FutureBuilder<Map<String, int>>(
              future: _getUserStats(user.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.all(AppTheme.space24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryGreen,
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: AppTheme.space12),
                        Text(
                          'Loading stats...',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final stats = snapshot.data ?? {'bookmarks': 0, 'reviews': 0};
                return Column(
                  children: [
                    // Stats Cards (Enhanced)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(AppTheme.space16),
                            decoration: BoxDecoration(
                              color: AppTheme.accentYellow.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(
                                color: AppTheme.accentYellow.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppTheme.space8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentYellow.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                  ),
                                  child: Icon(
                                    Icons.bookmark,
                                    size: 24,
                                    color: AppTheme.accentYellow,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.space8),
                                Text(
                                  stats['bookmarks'].toString(),
                                  style: AppTheme.displayMedium.copyWith(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentYellow,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.space4),
                                Text(
                                  'Bookmarks',
                                  style: AppTheme.bodySmall.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.space12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(AppTheme.space16),
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(
                                color: AppTheme.accentBlue.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppTheme.space8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentBlue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                  ),
                                  child: Icon(
                                    Icons.rate_review,
                                    size: 24,
                                    color: AppTheme.accentBlue,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.space8),
                                Text(
                                  stats['reviews'].toString(),
                                  style: AppTheme.displayMedium.copyWith(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentBlue,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.space4),
                                Text(
                                  'Reviews',
                                  style: AppTheme.bodySmall.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space16),
                    
                    // User Info Container (Enhanced)
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space16),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(
                          color: AppTheme.borderLight,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(Icons.email_outlined, 'Email', email),
                          _buildInfoRow(Icons.phone_outlined, 'Phone', phoneNumber),
                          if (createdAt != null)
                            _buildInfoRow(
                              Icons.calendar_today_outlined,
                              'Joined',
                              '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.space16),
                    
                    // Action Buttons (Enhanced)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(
                                color: isActive ? AppTheme.warningOrange : AppTheme.successGreen,
                                width: 1.5,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _toggleUserStatus(user),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.space12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isActive ? Icons.block : Icons.check_circle,
                                        size: 20,
                                        color: isActive
                                            ? AppTheme.warningOrange
                                            : AppTheme.successGreen,
                                      ),
                                      const SizedBox(width: AppTheme.space8),
                                      Text(
                                        isActive ? 'Deactivate' : 'Activate',
                                        style: AppTheme.labelLarge.copyWith(
                                          color: isActive
                                              ? AppTheme.warningOrange
                                              : AppTheme.successGreen,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.space12),
                        Expanded(
                          child: Container(
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
                                onTap: () => _deleteUser(user),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.space12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: AppTheme.errorRed,
                                      ),
                                      const SizedBox(width: AppTheme.space8),
                                      Text(
                                        'Delete',
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
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD INFO ROW (ENHANCED) ====================
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.labelSmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  value,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          'User Management',
          style: AppTheme.titleLarge.copyWith(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space16,
              0,
              AppTheme.space16,
              AppTheme.space16,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: AppTheme.shadowCardLight,
              ),
              child: TextField(
                controller: _searchController,
                style: AppTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  hintStyle: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textHint,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppTheme.primaryGreen,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                          color: AppTheme.textSecondary,
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space16,
                    vertical: AppTheme.space16,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection(AppConfig.usersCollection).snapshots(),
        builder: (context, snapshot) {
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
                    'Loading users...',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
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
                        Icons.error_outline,
                        size: 64,
                        color: AppTheme.errorRed,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space24),
                    Text(
                      'Error loading users',
                      style: AppTheme.titleLarge,
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space24),
                      child: Text(
                        snapshot.error.toString(),
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space32),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.people_outline,
                        size: 80,
                        color: AppTheme.primaryGreen.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space24),
                    Text(
                      'No users found',
                      style: AppTheme.titleLarge,
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Users will appear here once they register',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // NO CHANGES - Filter logic preserved
          var users = snapshot.data!.docs;
          if (_searchQuery.isNotEmpty) {
            users = users.where((user) {
              final data = user.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toLowerCase();
              final email = (data['email'] ?? '').toLowerCase();
              return name.contains(_searchQuery) || email.contains(_searchQuery);
            }).toList();
          }

          if (users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space32),
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.search_off,
                        size: 80,
                        color: AppTheme.textSecondary.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space24),
                    Text(
                      'No users match your search',
                      style: AppTheme.titleLarge,
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Try different keywords',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // User Count Banner (Enhanced)
              Container(
                padding: const EdgeInsets.all(AppTheme.space16),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: Icon(
                        Icons.people,
                        color: AppTheme.primaryGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Text(
                      '${users.length} ${users.length == 1 ? 'User' : 'Users'}',
                      style: AppTheme.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Users List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  color: AppTheme.primaryGreen,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.space16),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      return _buildUserCard(users[index]);
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
// END OF ENHANCED ADMIN USER MANAGEMENT PAGE
// Business Logic: 100% Preserved
// UI: Fully Enhanced with Modern Design
// ====================================================================