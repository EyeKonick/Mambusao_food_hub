import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'menu_items_page.dart';
import 'admin_dashboard_page.dart';
import 'business_promotions_page.dart';
import 'services/promotion_service.dart';

class BusinessDashboardPage extends StatefulWidget {
  const BusinessDashboardPage({super.key});

  @override
  State<BusinessDashboardPage> createState() => _BusinessDashboardState();
}

class _BusinessDashboardState extends State<BusinessDashboardPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PromotionService _promotionService = PromotionService();

  User? _currentUser;
  String _businessName = 'Loading...';
  String _businessType = '';
  String _approvalStatus = 'pending';
  String? _rejectionReason;
  String? _logoUrl;
  bool _isLoading = true;
  int _activePromotionCount = 0;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchBusinessData();
    _loadActivePromotionCount();
  }

  Future<void> _fetchBusinessData() async {
    if (_currentUser == null) {
      setState(() {
        _businessName = 'No User';
        _isLoading = false;
      });
      return;
    }

    try {
      final businessDoc = await _firestore
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

      final data = businessDoc.data() as Map<String, dynamic>;
      setState(() {
        _businessName = data['businessName'] ?? 'Unnamed Business';
        _businessType = data['businessType'] ?? '';
        _approvalStatus = data['approvalStatus'] ?? 'pending';
        _rejectionReason = data['rejectionReason'];
        _logoUrl = data['logoUrl'];
        _isLoading = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✓ Business loaded: $_businessName');
        debugPrint('✓ Approval Status: $_approvalStatus');
        if (_rejectionReason != null) {
          debugPrint('✓ Rejection Reason: $_rejectionReason');
        }
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error loading business: $e');
      }
      setState(() {
        _businessName = 'Error Loading Business';
        _isLoading = false;
      });
    }
  }

// ==================== LOAD ACTIVE PROMOTION COUNT ====================
  Future<void> _loadActivePromotionCount() async {
    if (_currentUser == null) return;

    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('promotions')
          .where('businessId', isEqualTo: _currentUser!.uid)
          .where('isActive', isEqualTo: true)
          .get();

      // Filter promotions that haven't expired
      final activePromos = snapshot.docs.where((doc) {
        final data = doc.data();
        final endDate = data['endDate'] as Timestamp?;
        return endDate != null && endDate.toDate().isAfter(now);
      }).length;

      setState(() {
        _activePromotionCount = activePromos;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✓ Active promotions: $activePromos');
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error loading promotion count: $e');
      }
    }
  }

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
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryGreen),
              const SizedBox(height: 16),
              Text('Loading business...', style: AppTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (AppConfig.requireBusinessApproval) {
      if (_approvalStatus == 'pending') {
        return _buildPendingApprovalScreen();
      } else if (_approvalStatus == 'rejected') {
        return _buildRejectedScreen();
      }
    }

    return _buildDashboardScreen();
  }

  Widget _buildRejectedScreen() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Application Rejected'),
        backgroundColor: AppTheme.errorRed,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await _auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cancel_outlined,
                  size: 80,
                  color: AppTheme.errorRed,
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'Application Rejected',
                style: AppTheme.headingLarge.copyWith(
                  color: AppTheme.errorRed,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'Unfortunately, your business application has been rejected by our admin team.',
                style: AppTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Application Details:',
                        style: AppTheme.titleMedium.copyWith(
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const Divider(height: 24),
                      _buildInfoRow('Business Name:', _businessName),
                      _buildInfoRow('Business Type:', _businessType),
                      _buildInfoRow('Email:', _currentUser?.email ?? 'N/A'),
                      
                      if (_rejectionReason != null && _rejectionReason!.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(
                          'Reason for Rejection:',
                          style: AppTheme.titleSmall.copyWith(
                            color: AppTheme.errorRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.errorRed.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _rejectionReason!,
                            style: AppTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 32),
                    const SizedBox(height: 12),
                    Text(
                      'What You Can Do',
                      style: AppTheme.titleMedium.copyWith(color: Colors.blue.shade900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Review the rejection reason above\n'
                      '• Contact admin for clarification\n'
                      '• Submit a new application with corrections\n'
                      '• Ensure all requirements are met',
                      style: AppTheme.bodyMedium,
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Contact admin feature coming soon!'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                  icon: const Icon(Icons.email),
                  label: const Text('Contact Admin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _auth.signOut();
                    if (!mounted) return;
                    Navigator.of(context).pushReplacementNamed('/');
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: BorderSide(color: AppTheme.errorRed),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalScreen() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Pending Approval'),
        backgroundColor: AppTheme.warningOrange,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await _auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: Center(
        child: RefreshIndicator(
          onRefresh: _fetchBusinessData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hourglass_empty,
                    size: 80,
                    color: AppTheme.warningOrange,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Waiting for Approval',
                  style: AppTheme.headingLarge.copyWith(
                    color: AppTheme.warningOrange,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your business registration is being reviewed by our admin team. This usually takes 24-48 hours.',
                  style: AppTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Your Business Details:',
                          style: AppTheme.titleMedium.copyWith(
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const Divider(height: 24),
                        _buildInfoRow('Name:', _businessName),
                        _buildInfoRow('Type:', _businessType),
                        _buildInfoRow('Email:', _currentUser?.email ?? 'N/A'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _fetchBusinessData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Check Status'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardScreen() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Business Dashboard'),
        actions: [
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
        onRefresh: () async {
          await _fetchBusinessData();
          await _loadActivePromotionCount();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 24),
              _buildModulesGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.business, size: 40, color: AppTheme.primaryGreen);
                        },
                      ),
                    )
                  : Icon(Icons.business, size: 40, color: AppTheme.primaryGreen),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back!',
                    style: AppTheme.bodySmall.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _businessName,
                    style: AppTheme.headingMedium.copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildModuleCard(
          icon: Icons.visibility,
          label: 'Views',
          value: '0',
          color: Colors.blue,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Analytics coming soon!')),
            );
          },
        ),
        _buildModuleCard(
          icon: Icons.star,
          label: 'Rating',
          value: '5.0',
          color: Colors.amber,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reviews coming soon!')),
            );
          },
        ),
        _buildModuleCard(
          icon: Icons.bookmark,
          label: 'Bookmarks',
          value: '0',
          color: Colors.red,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bookmarks analytics coming soon!')),
            );
          },
        ),
        _buildModuleCard(
          icon: Icons.rate_review,
          label: 'Reviews',
          value: '0',
          color: Colors.purple,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reviews management coming soon!')),
            );
          },
        ),
        _buildModuleCard(
          icon: Icons.restaurant_menu,
          label: 'Menu Items',
          value: 'Manage',
          color: AppTheme.primaryGreen,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MenuItemsPage()),
            );
          },
        ),
        // Promotions card with StreamBuilder for real-time count
        StreamBuilder<QuerySnapshot>(
          stream: _currentUser != null
              ? _firestore
                  .collection('promotions')
                  .where('businessId', isEqualTo: _currentUser!.uid)
                  .where('isActive', isEqualTo: true)
                  .snapshots()
              : Stream.empty(),
          builder: (context, snapshot) {
            int activeCount = 0;
            
            if (snapshot.hasData) {
              final now = DateTime.now();
              activeCount = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final endDate = data['endDate'] as Timestamp?;
                return endDate != null && endDate.toDate().isAfter(now);
              }).length;
            }

            return _buildModuleCard(
              icon: Icons.local_offer,
              label: 'Promotions',
              value: '$activeCount Active',
              color: AppTheme.accentYellow,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BusinessPromotionsPage(),
                  ),
                );
              },
            );
          },
        ),
        _buildModuleCard(
          icon: Icons.analytics,
          label: 'Analytics',
          value: 'View',
          color: Colors.indigo,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Analytics coming soon!')),
            );
          },
        ),
        _buildModuleCard(
          icon: Icons.settings,
          label: 'Settings',
          value: 'Configure',
          color: Colors.grey,
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
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                label,
                style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTheme.titleMedium.copyWith(color: color),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _logoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.business, size: 40, color: AppTheme.primaryGreen);
                            },
                          ),
                        )
                      : Icon(Icons.business, size: 40, color: AppTheme.primaryGreen),
                ),
                const SizedBox(height: 12),
                Text(
                  _businessName,
                  style: AppTheme.titleMedium.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _currentUser?.email ?? '',
                  style: AppTheme.bodySmall.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: const Text('Manage Menu'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MenuItemsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_offer),
            title: const Text('Promotions'),
            trailing: _activePromotionCount > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentYellow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_activePromotionCount',
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BusinessPromotionsPage(),
                ),
              ).then((_) => _loadActivePromotionCount());
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: AppTheme.errorRed),
            title: Text('Sign Out', style: TextStyle(color: AppTheme.errorRed)),
            onTap: () async {
              await _auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
    );
  }
}