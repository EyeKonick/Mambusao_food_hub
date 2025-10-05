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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  Future<void> _toggleUserStatus(DocumentSnapshot user) async {
    final data = user.data() as Map<String, dynamic>;
    final currentStatus = data['isActive'] ?? true;
    final userName = data['name'] ?? 'User';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${currentStatus ? 'Deactivate' : 'Activate'} User'),
        content: Text(
          currentStatus
              ? 'Deactivate $userName?\n\nThey won\'t be able to:\n• Write reviews\n• Bookmark businesses\n• Use app features'
              : 'Activate $userName?\n\nThey will regain full access.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus ? AppTheme.warningOrange : AppTheme.successGreen,
            ),
            child: Text(currentStatus ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection(AppConfig.usersCollection).doc(user.id).update({
        'isActive': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${currentStatus ? 'deactivated' : 'activated'}'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  Future<void> _deleteUser(DocumentSnapshot user) async {
    final data = user.data() as Map<String, dynamic>;
    final userName = data['name'] ?? 'User';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Permanently delete $userName?\n\nThis will delete:\n• User account\n• All bookmarks\n• All reviews\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
          content: Text('$userName deleted'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  Widget _buildUserCard(DocumentSnapshot user) {
    final data = user.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown User';
    final email = data['email'] ?? 'No email';
    final phoneNumber = data['phoneNumber'] ?? 'No phone';
    final isActive = data['isActive'] ?? true;
    final photoUrl = data['photoUrl'];
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      name[0].toUpperCase(),
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            if (!isActive)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.block, color: Colors.white, size: 10),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(name, style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            ),
            if (!isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'INACTIVE',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.errorRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(email, style: AppTheme.bodySmall),
        ),
        children: [
          FutureBuilder<Map<String, int>>(
            future: _getUserStats(user.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final stats = snapshot.data ?? {'bookmarks': 0, 'reviews': 0};
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.accentYellow.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.bookmark, size: 24, color: AppTheme.accentYellow),
                              const SizedBox(height: 6),
                              Text(
                                stats['bookmarks'].toString(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentYellow,
                                ),
                              ),
                              Text('Bookmarks', style: AppTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.rate_review, size: 24, color: AppTheme.accentBlue),
                              const SizedBox(height: 6),
                              Text(
                                stats['reviews'].toString(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentBlue,
                                ),
                              ),
                              Text('Reviews', style: AppTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.email, 'Email', email),
                        _buildInfoRow(Icons.phone, 'Phone', phoneNumber),
                        if (createdAt != null)
                          _buildInfoRow(
                            Icons.calendar_today,
                            'Joined',
                            '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _toggleUserStatus(user),
                          icon: Icon(isActive ? Icons.block : Icons.check_circle, size: 18),
                          label: Text(isActive ? 'Deactivate' : 'Activate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                isActive ? AppTheme.warningOrange : AppTheme.successGreen,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: isActive ? AppTheme.warningOrange : AppTheme.successGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _deleteUser(user),
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorRed,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: AppTheme.errorRed),
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
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: AppTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('User Management'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection(AppConfig.usersCollection).snapshots(),
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
                    const Text('Error loading users'),
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
                  Icon(Icons.people_outline, size: 80,
                      color: AppTheme.textSecondary.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text('No users found'),
                ],
              ),
            );
          }

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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 80,
                      color: AppTheme.textSecondary.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text('No users match your search'),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.primaryGreen.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people, color: AppTheme.primaryGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${users.length} ${users.length == 1 ? 'User' : 'Users'}',
                      style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    return _buildUserCard(users[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}