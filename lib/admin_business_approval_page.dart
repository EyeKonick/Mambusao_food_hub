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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _approveBusiness(DocumentSnapshot business) async {
    final data = business.data() as Map<String, dynamic>?;
    final businessName = data?['businessName'] ?? 'this business';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Business'),
        content: Text('Approve $businessName?\n\nThe business will be visible to all users.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
            child: const Text('Approve'),
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
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$businessName approved'),
              ),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _deleteBusiness(DocumentSnapshot business) async {
    final data = business.data() as Map<String, dynamic>?;
    final businessName = data?['businessName'] ?? 'this business';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Business'),
        content: Text(
          'Permanently delete $businessName?\n\nThis will delete:\n• All menu items\n• All reviews\n• All related data\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
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
              const Icon(Icons.delete, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('$businessName deleted')),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: logoUrl != null
              ? Image.network(
                  logoUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholderLogo(),
                )
              : _buildPlaceholderLogo(),
        ),
        title: Text(
          businessName,
          style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: AppTheme.successGreen),
                const SizedBox(width: 4),
                Text(
                  'APPROVED',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.successGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business Information',
                  style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.category, 'Type', businessType),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _deleteBusiness(business),
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Delete Business'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorRed,
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: AppTheme.errorRed),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderLogo() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.restaurant, size: 28, color: AppTheme.primaryGreen),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTheme.bodyMedium,
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

  Widget _buildApprovedBusinessList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(AppConfig.businessesCollection)
          .where('approvalStatus', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
                  const SizedBox(height: 16),
                  const Text('Error loading businesses'),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: AppTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.business,
                  size: 80,
                  color: AppTheme.textSecondary.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text('No approved businesses', style: AppTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Approved businesses will appear here',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        final businesses = snapshot.data!.docs;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.successGreen.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppTheme.successGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${businesses.length} Approved ${businesses.length == 1 ? 'Business' : 'Businesses'}',
                    style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Approved Businesses'),
        elevation: 0,
      ),
      body: _buildApprovedBusinessList(),
    );
  }
}