// ====================================================================
// ENHANCED ADMIN BUSINESS APPROVAL PAGE
// UI Enhancement Phase - Modern, Clean Design with Poppins Font
// 
// ENHANCEMENTS APPLIED:
// - Modern card-based business listings
// - Enhanced approval/delete dialogs with better visuals
// - Improved business information display
// - Better empty states with illustrations
// - Enhanced status badges and indicators
// - Modern button styles
// - Consistent spacing and typography
// - Better shadows and elevation
// 
// BUSINESS LOGIC: 100% PRESERVED - NO CHANGES
// ====================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';

class AdminBusinessApprovalPage extends StatefulWidget {
  final int initialTab;
  
  const AdminBusinessApprovalPage({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<AdminBusinessApprovalPage> createState() => _AdminBusinessApprovalPageState();
}

class _AdminBusinessApprovalPageState extends State<AdminBusinessApprovalPage> {
  // ==================== FIREBASE INSTANCES ====================
  // NO CHANGES - Business logic preserved
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
  }

  // ==================== APPROVE BUSINESS (ENHANCED UI) ====================
  // Business logic preserved - Only dialog UI enhanced
  Future<void> _approveBusiness(DocumentSnapshot business) async {
    final data = business.data() as Map<String, dynamic>?;
    final businessName = data?['businessName'] ?? 'this business';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space8),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppTheme.successGreen,
                size: 28,
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Text(
                'Approve Business',
                style: AppTheme.headlineMedium,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approve $businessName?',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            Container(
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: AppTheme.successGreen.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.successGreen,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text(
                      'The business will be visible to all users.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check, size: 18),
                const SizedBox(width: AppTheme.space8),
                Text(
                  'Approve',
                  style: AppTheme.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection(AppConfig.businessesCollection).doc(business.id).update({
        'approvalStatus': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _auth.currentUser?.uid,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Text(
                  '$businessName approved',
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: AppTheme.space12),
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

  // ==================== DELETE BUSINESS (ENHANCED UI) ====================
  // Business logic preserved - Only dialog UI enhanced
  Future<void> _deleteBusiness(DocumentSnapshot business) async {
    final data = business.data() as Map<String, dynamic>?;
    final businessName = data?['businessName'] ?? 'this business';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.space8),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: const Icon(
                Icons.delete_forever,
                color: AppTheme.errorRed,
                size: 28,
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Text(
                'Delete Business',
                style: AppTheme.headlineMedium.copyWith(
                  color: AppTheme.errorRed,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permanently delete $businessName?',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            Container(
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: AppTheme.errorRed.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.errorRed,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.space8),
                      Text(
                        'This will delete:',
                        style: AppTheme.labelLarge.copyWith(
                          color: AppTheme.errorRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space8),
                  _buildDeleteInfoRow('All menu items'),
                  _buildDeleteInfoRow('All reviews'),
                  _buildDeleteInfoRow('All related data'),
                  const SizedBox(height: AppTheme.space8),
                  Text(
                    '⚠️ This action cannot be undone.',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.errorRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_forever, size: 18),
                const SizedBox(width: AppTheme.space8),
                Text(
                  'Delete',
                  style: AppTheme.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Delete menu items
      final menuItems = await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(business.id)
          .collection(AppConfig.menuItemsSubcollection)
          .get();
      
      for (var doc in menuItems.docs) {
        await doc.reference.delete();
      }

      // Delete reviews
      final reviews = await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(business.id)
          .collection(AppConfig.reviewsSubcollection)
          .get();
      
      for (var doc in reviews.docs) {
        await doc.reference.delete();
      }

      // Delete business
      await business.reference.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Text(
                  '$businessName deleted',
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: AppTheme.space12),
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

  // ==================== BUILD DELETE INFO ROW ====================
  Widget _buildDeleteInfoRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space4),
      child: Row(
        children: [
          const Icon(
            Icons.close,
            size: 14,
            color: AppTheme.errorRed,
          ),
          const SizedBox(width: AppTheme.space8),
          Text(
            text,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.errorRed,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD BUSINESS CARD (ENHANCED) ====================
  Widget _buildBusinessCard(DocumentSnapshot business) {
    final data = business.data() as Map<String, dynamic>;
    final businessName = data['businessName'] ?? 'Unnamed Business';
    final businessType = data['businessType'] ?? 'Restaurant';
    final ownerName = data['ownerName'] ?? 'Unknown';
    final email = data['email'] ?? 'No email';
    final phoneNumber = data['phoneNumber'] ?? 'No phone';
    final address = data['businessAddress'] ?? 'No address';
    final logoUrl = data['logoUrl'];
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCard,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.all(AppTheme.space16),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppTheme.space16,
              0,
              AppTheme.space16,
              AppTheme.space16,
            ),
            leading: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: AppTheme.shadowCardLight,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: logoUrl != null
                    ? Image.network(
                        logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderLogo(),
                      )
                    : _buildPlaceholderLogo(),
              ),
            ),
            title: Text(
              businessName,
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppTheme.space8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space8,
                      vertical: AppTheme.space4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 12,
                          color: AppTheme.successGreen,
                        ),
                        const SizedBox(width: AppTheme.space4),
                        Text(
                          'APPROVED',
                          style: AppTheme.labelSmall.copyWith(
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space8,
                      vertical: AppTheme.space4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
                    ),
                    child: Text(
                      businessType,
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            children: [
              const SizedBox(height: AppTheme.space12),
              
              // Business Information Section
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppTheme.space4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: AppTheme.space8),
                        Text(
                          'Business Information',
                          style: AppTheme.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space16),
                    _buildInfoRow(Icons.person, 'Owner', ownerName),
                    _buildInfoRow(Icons.email, 'Email', email),
                    _buildInfoRow(Icons.phone, 'Phone', phoneNumber),
                    _buildInfoRow(Icons.location_on, 'Address', address),
                    if (createdAt != null)
                      _buildInfoRow(
                        Icons.calendar_today,
                        'Registered',
                        '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppTheme.space16),
              
              // Delete Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _deleteBusiness(business),
                  icon: const Icon(Icons.delete_forever, size: 20),
                  label: Text(
                    'Delete Business',
                    style: AppTheme.titleMedium.copyWith(
                      color: AppTheme.errorRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: BorderSide(color: AppTheme.errorRed, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== BUILD PLACEHOLDER LOGO ====================
  Widget _buildPlaceholderLogo() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: const Icon(
        Icons.restaurant,
        size: 32,
        color: AppTheme.primaryGreen,
      ),
    );
  }

  // ==================== BUILD INFO ROW (ENHANCED) ====================
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              icon,
              size: 16,
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
                    color: AppTheme.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  value,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD APPROVED BUSINESS LIST (ENHANCED) ====================
  Widget _buildApprovedBusinessList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(AppConfig.businessesCollection)
          .where('approvalStatus', isEqualTo: 'approved')
          .snapshots(),
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
                  'Loading businesses...',
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
                    padding: const EdgeInsets.all(AppTheme.space20),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.errorRed,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space24),
                  Text(
                    'Error loading businesses',
                    style: AppTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.space8),
                  Text(
                    snapshot.error.toString(),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
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
                    padding: const EdgeInsets.all(AppTheme.space24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.business,
                      size: 80,
                      color: AppTheme.primaryGreen.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space24),
                  Text(
                    'No approved businesses',
                    style: AppTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppTheme.space8),
                  Text(
                    'Approved businesses will appear here',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final businesses = snapshot.data!.docs;

        return Column(
          children: [
            // Header with count (Enhanced)
            Container(
              padding: const EdgeInsets.all(AppTheme.space16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.successGreen.withOpacity(0.1),
                    AppTheme.successGreen.withOpacity(0.05),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.successGreen.withOpacity(0.2),
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
                      color: AppTheme.successGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.successGreen.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${businesses.length}',
                        style: AppTheme.displayMedium.copyWith(
                          color: AppTheme.successGreen,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Approved ${businesses.length == 1 ? 'Business' : 'Businesses'}',
                        style: AppTheme.labelLarge.copyWith(
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Business List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppTheme.space16),
                itemCount: businesses.length,
                itemBuilder: (context, index) {
                  return _buildBusinessCard(businesses[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ==================== BUILD METHOD (ENHANCED) ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Approved Businesses',
          style: AppTheme.titleLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildApprovedBusinessList(),
    );
  }
}

// ====================================================================
// END OF ENHANCED ADMIN BUSINESS APPROVAL PAGE
// ====================================================================