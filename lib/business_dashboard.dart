// lib/business_dashboard.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import config and theme
import 'config/app_config.dart';
import 'config/app_theme.dart';

// Import pages
import 'menu_items_page.dart';
import 'admin_dashboard_page.dart';

/// Business Dashboard Page
/// 
/// Main control center for business owners to:
/// - View their business statistics
/// - Manage menu items
/// - View customer reviews
/// - Edit business profile
/// 
/// Note: Since one account = one business, this dashboard manages
/// the single business associated with the logged-in user
class BusinessDashboardPage extends StatefulWidget {
  const BusinessDashboardPage({super.key});

  @override
  _BusinessDashboardPageState createState() => _BusinessDashboardPageState();
}

class _BusinessDashboardPageState extends State<BusinessDashboardPage> {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Current user
  User? _currentUser;
  
  // Business data
  String _businessName = 'Loading...';
  String _businessType = '';
  String _approvalStatus = 'pending';
  String? _logoUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _fetchBusinessData();
    }
  }

  // ==================== DATA FETCHING ====================

  /// Fetch business data from Firestore
  Future<void> _fetchBusinessData() async {
    try {
      // Get business document using user's ID
      DocumentSnapshot businessDoc = await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(_currentUser!.uid)
          .get();

      if (!businessDoc.exists) {
        setState(() {
          _businessName = 'No Business Found';
          _isLoading = false;
        });
        return;
      }

      // Extract data from document
      final data = businessDoc.data() as Map<String, dynamic>;

      setState(() {
        _businessName = data['businessName'] ?? 'Unnamed Business';
        _businessType = data['businessType'] ?? '';
        _approvalStatus = data['approvalStatus'] ?? 'pending';
        _logoUrl = data['logoUrl'];
        _isLoading = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('Business loaded: $_businessName');
        debugPrint('Approval status: $_approvalStatus');
        debugPrint('Logo URL: $_logoUrl');
      }
      
    } catch (e) {
      debugPrint('Error fetching business data: $e');
      setState(() {
        _businessName = 'Error Loading Business';
        _isLoading = false;
      });
    }
  }

  /// Check if current user is an admin
  Future<bool> _checkIfAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      final adminDoc = await _firestore
          .collection('admins')
          .doc(user.uid)
          .get();
      
      return adminDoc.exists && adminDoc.data()?['isAdmin'] == true;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('Error checking admin status: $e');
      }
      return false;
    }
  }

  // ==================== UI BUILD METHOD ====================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (AppConfig.requireBusinessApproval && _approvalStatus == 'pending') {
      return _buildPendingApprovalScreen();
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_businessName),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon!')),
              );
            },
          ),
          // Admin panel button (only shows if user is admin)
          FutureBuilder<bool>(
            future: _checkIfAdmin(),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return IconButton(
                  icon: const Icon(Icons.admin_panel_settings),
                  tooltip: 'Admin Panel',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminDashboardPage(),
                      ),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _fetchBusinessData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 24),
              Text('Overview', style: AppTheme.headingMedium),
              const SizedBox(height: 16),
              _buildModulesGrid(),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== PENDING APPROVAL SCREEN ====================

  Widget _buildPendingApprovalScreen() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Pending Approval'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.accentYellow.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_empty,
                  size: 80,
                  color: AppTheme.accentYellow,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Waiting for Approval',
                style: AppTheme.headingLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your business registration is being reviewed by our admin team. This usually takes 24-48 hours.',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Business Details', style: AppTheme.headingSmall),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.business, 'Name', _businessName),
                      _buildInfoRow(Icons.category, 'Type', _businessType),
                      _buildInfoRow(Icons.email, 'Email', _currentUser?.email ?? 'N/A'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _fetchBusinessData,
                icon: const Icon(Icons.refresh),
                label: const Text('Check Status'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await _auth.signOut();
                  if (!mounted) return;
                  Navigator.of(context).pushReplacementNamed('/');
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryGreen),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(value, style: AppTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  // ==================== DASHBOARD COMPONENTS ====================

  Widget _buildWelcomeCard() {
    return Card(
      color: AppTheme.primaryGreen,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            // Display logo if available, otherwise show default icon
            _logoUrl != null && _logoUrl!.isNotEmpty
                ? CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    backgroundImage: NetworkImage(_logoUrl!),
                  )
                : CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.business,
                      size: 30,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back!',
                    style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _businessName,
                    style: AppTheme.headingMedium.copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_businessType.isNotEmpty)
                    Text(
                      _businessType,
                      style: AppTheme.bodySmall.copyWith(color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModulesGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildModuleCard(
          icon: Icons.visibility,
          label: 'Views',
          value: '0',
          color: AppTheme.accentBlue,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Analytics coming soon!')),
            );
          },
        ),
        _buildModuleCard(
          icon: Icons.star,
          label: 'Rating',
          value: '0.0',
          color: AppTheme.accentYellow,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rating details coming soon!')),
            );
          },
        ),
        _buildModuleCard(
          icon: Icons.bookmark,
          label: 'Bookmarks',
          value: '0',
          color: AppTheme.secondaryGreen,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bookmark analytics coming soon!')),
            );
          },
        ),
        _buildModuleCard(
          icon: Icons.rate_review,
          label: 'Reviews',
          value: '0',
          color: AppTheme.primaryGreen,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Customer reviews coming soon!')),
            );
          },
        ),
        _buildModuleCard(
          icon: Icons.fastfood,
          label: 'Menu Items',
          value: '',
          color: AppTheme.secondaryGreen,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MenuItemsPage()),
            );
          },
        ),
        _buildModuleCard(
          icon: Icons.edit,
          label: 'Edit Profile',
          value: '',
          color: AppTheme.accentBlue,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Edit profile coming soon!')),
            );
          },
        ),
        _buildModuleCard(
          icon: Icons.analytics,
          label: 'Analytics',
          value: '',
          color: AppTheme.primaryGreen,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Detailed analytics coming soon!')),
            );
          },
        ),
        _buildModuleCard(
          icon: Icons.settings,
          label: 'Settings',
          value: '',
          color: AppTheme.textSecondary,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings coming soon!')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildModuleCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              if (value.isNotEmpty)
                Text(
                  value,
                  style: AppTheme.headingMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== DRAWER ====================

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: AppTheme.primaryGreen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Display logo in drawer too
                _logoUrl != null && _logoUrl!.isNotEmpty
                    ? CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        backgroundImage: NetworkImage(_logoUrl!),
                      )
                    : CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.business,
                          size: 30,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                const SizedBox(height: 12),
                Text(
                  _businessName,
                  style: AppTheme.headingSmall.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _currentUser?.email ?? 'N/A',
                  style: AppTheme.bodySmall.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerTile(
                  icon: Icons.dashboard,
                  title: 'Dashboard',
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerTile(
                  icon: Icons.fastfood,
                  title: 'Manage Menu',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MenuItemsPage()),
                    );
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.rate_review,
                  title: 'Customer Reviews',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reviews coming soon!')),
                    );
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.analytics,
                  title: 'Analytics',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Analytics coming soon!')),
                    );
                  },
                ),
                const Divider(),
                _buildDrawerTile(
                  icon: Icons.settings,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings coming soon!')),
                    );
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Help coming soon!')),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          _buildDrawerTile(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () async {
              await _auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryGreen),
      title: Text(title),
      onTap: onTap,
    );
  }
}