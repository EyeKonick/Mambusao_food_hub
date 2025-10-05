import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'admin_business_approval_page.dart';
import 'admin_pending_businesses_page.dart';
import 'admin_review_moderation_page.dart';
import 'admin_user_management_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isAdmin = false;
  String? _adminEmail;

  // Stats
  int _totalBusinesses = 0;
  int _pendingBusinesses = 0;
  int _approvedBusinesses = 0;
  int _totalUsers = 0;
  int _totalReviews = 0;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = _auth.currentUser;

    if (user == null || user.isAnonymous) {
      _redirectToLogin();
      return;
    }

    try {
      final adminDoc = await _firestore.collection('admins').doc(user.uid).get();

      if (!adminDoc.exists || adminDoc.data()?['isAdmin'] != true) {
        _showAccessDenied();
        return;
      }

      setState(() {
        _isAdmin = true;
        _adminEmail = user.email;
      });

      await _loadDashboardStats();
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('Error checking admin access: $e');
      }
      _showAccessDenied();
    }
  }

  void _redirectToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  void _showAccessDenied() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Access Denied'),
        content: const Text('You do not have admin privileges.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDashboardStats() async {
    try {
      setState(() => _isLoading = true);

      // Get ALL businesses first
      final businessesSnapshot = await _firestore
          .collection(AppConfig.businessesCollection)
          .get();

      // Filter by status IN DART (not Firestore)
      final allBusinesses = businessesSnapshot.docs;
      final pendingList = allBusinesses
          .where((doc) => doc.data()['approvalStatus'] == 'pending')
          .toList();
      final approvedList = allBusinesses
          .where((doc) => doc.data()['approvalStatus'] == 'approved')
          .toList();

      // Get users count
      final usersSnapshot = await _firestore
          .collection(AppConfig.usersCollection)
          .get();

      // Count reviews manually
      int totalReviews = 0;
      for (var businessDoc in allBusinesses) {
        try {
          final reviewsSnapshot = await _firestore
              .collection(AppConfig.businessesCollection)
              .doc(businessDoc.id)
              .collection(AppConfig.reviewsSubcollection)
              .get();
          totalReviews += reviewsSnapshot.docs.length;
        } catch (e) {
          continue;
        }
      }

      setState(() {
        _totalBusinesses = allBusinesses.length;
        _pendingBusinesses = pendingList.length;
        _approvedBusinesses = approvedList.length;
        _totalUsers = usersSnapshot.docs.length;
        _totalReviews = totalReviews;
        _isLoading = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('Stats loaded:');
        debugPrint('  Total: $_totalBusinesses');
        debugPrint('  Pending: $_pendingBusinesses');
        debugPrint('  Approved: $_approvedBusinesses');
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('Error loading stats: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  if (onTap != null)
                    Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Stats',
            onPressed: _loadDashboardStats,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card - Compact
              Card(
                color: AppTheme.primaryGreen,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin Dashboard',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _adminEmail ?? 'Administrator',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Stats Grid
              Text('Overview Statistics', style: AppTheme.headingMedium),
              const SizedBox(height: 12),

              // Row 1: Pending and Approved
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Pending',
                      value: _pendingBusinesses.toString(),
                      icon: Icons.pending_actions,
                      color: AppTheme.warningOrange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminPendingBusinessesPage(initialTab: 0),
                          ),
                        ).then((_) => _loadDashboardStats());
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Approved',
                      value: _approvedBusinesses.toString(),
                      icon: Icons.check_circle,
                      color: AppTheme.successGreen,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminBusinessApprovalPage(),
                          ),
                        ).then((_) => _loadDashboardStats());
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Total Businesses and Users
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Businesses',
                      value: _totalBusinesses.toString(),
                      icon: Icons.business,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Users',
                      value: _totalUsers.toString(),
                      icon: Icons.people,
                      color: AppTheme.accentBlue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminUserManagementPage(),
                          ),
                        ).then((_) => _loadDashboardStats());
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 3: Reviews (full width)
              _buildStatCard(
                title: 'Total Reviews',
                value: _totalReviews.toString(),
                icon: Icons.rate_review,
                color: AppTheme.accentYellow,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminReviewModerationPage(),
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
}