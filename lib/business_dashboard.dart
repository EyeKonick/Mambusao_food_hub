import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'menu_items_page.dart';
import 'admin_dashboard_page.dart';
import 'business_promotions_page.dart';
import 'services/promotion_service.dart';
import 'business_profile_editor_page.dart';
import 'terms_page.dart';
import 'privacy_page.dart';
import 'report_page.dart';
import 'about_page.dart';

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

  // ==================== LOGOUT CONFIRMATION DIALOG ====================
  Future<bool> _showLogoutConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: AppTheme.errorRed),
            const SizedBox(width: 12),
            const Text('Confirm Logout'),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ==================== HANDLE LOGOUT ====================
  Future<void> _handleLogout() async {
    final confirmed = await _showLogoutConfirmation();
    if (confirmed) {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/');
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
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        final shouldLogout = await _showLogoutConfirmation();
        if (shouldLogout && mounted) {
          await _auth.signOut();
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/');
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Application Rejected'),
          backgroundColor: AppTheme.errorRed,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleLogout,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
              tooltip: 'Logout',
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cancel,
                      size: 80,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Application Rejected',
                      style: AppTheme.titleLarge.copyWith(
                        color: AppTheme.errorRed,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your business registration was not approved.',
                      style: AppTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (_rejectionReason != null && _rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reason:',
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.errorRed,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _rejectionReason!,
                              style: AppTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingApprovalScreen() {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        final shouldLogout = await _showLogoutConfirmation();
        if (shouldLogout && mounted) {
          await _auth.signOut();
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/');
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Pending Approval'),
          backgroundColor: AppTheme.accentYellow,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleLogout,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
              tooltip: 'Logout',
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      size: 80,
                      color: AppTheme.accentYellow,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Registration Pending',
                      style: AppTheme.titleLarge.copyWith(
                        color: AppTheme.accentYellow,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your business registration is under review.',
                      style: AppTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'An admin will review your application shortly. You will be notified once approved.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _fetchBusinessData();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Status'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentYellow,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _handleLogout,
                      child: Text(
                        'Logout',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardScreen() {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        final shouldLogout = await _showLogoutConfirmation();
        if (shouldLogout && mounted) {
          await _auth.signOut();
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/');
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Business Dashboard'),
          elevation: 0,
          backgroundColor: AppTheme.primaryGreen,
          actions: [
            // Edit Profile Icon
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BusinessProfileEditorPage(),
                  ),
                );
                
                if (result == true) {
                  await _fetchBusinessData();
                  await _loadActivePromotionCount();
                }
              },
              tooltip: 'Edit Profile',
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
            padding: const EdgeInsets.all(16.0),
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
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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
                  style: AppTheme.titleLarge.copyWith(color: Colors.white),
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
        // VIEWS CARD - Display only (not clickable)
        StreamBuilder<DocumentSnapshot>(
          stream: _currentUser != null
              ? _firestore
                  .collection(AppConfig.businessesCollection)
                  .doc(_currentUser!.uid)
                  .snapshots()
              : Stream.empty(),
          builder: (context, snapshot) {
            int viewCount = 0;
            
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              viewCount = data?['viewCount'] ?? 0;
            }

            return _buildModuleCard(
              icon: Icons.visibility,
              label: 'Views',
              value: '$viewCount',
              color: Colors.blue,
              onTap: () {
                // Display only - no action
              },
            );
          },
        ),
        
        // BOOKMARKS CARD - Display from business document
        StreamBuilder<DocumentSnapshot>(
          stream: _currentUser != null
              ? _firestore
                  .collection(AppConfig.businessesCollection)
                  .doc(_currentUser!.uid)
                  .snapshots()
              : Stream.empty(),
          builder: (context, snapshot) {
            int bookmarkCount = 0;
            
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              bookmarkCount = data?['bookmarkCount'] ?? 0;
            }

            return _buildModuleCard(
              icon: Icons.bookmark,
              label: 'Bookmarks',
              value: '$bookmarkCount',
              color: Colors.red,
              onTap: () {
                if (_currentUser != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BusinessBookmarksPage(
                        businessId: _currentUser!.uid,
                        businessName: _businessName,
                      ),
                    ),
                  );
                }
              },
            );
          },
        ),
        
        // REVIEWS CARD - Shows rating + review count, clickable to view all reviews
        StreamBuilder<DocumentSnapshot>(
          stream: _currentUser != null
              ? _firestore
                  .collection(AppConfig.businessesCollection)
                  .doc(_currentUser!.uid)
                  .snapshots()
              : Stream.empty(),
          builder: (context, businessSnapshot) {
            double avgRating = 0.0;
            int reviewCount = 0;
            
            if (businessSnapshot.hasData && businessSnapshot.data!.exists) {
              final data = businessSnapshot.data!.data() as Map<String, dynamic>?;
              avgRating = (data?['avgRating'] ?? 0.0).toDouble();
              reviewCount = data?['reviewCount'] ?? 0;
            }

            return _buildModuleCard(
              icon: Icons.rate_review,
              label: 'Reviews',
              value: '$reviewCount (${avgRating.toStringAsFixed(1)}★)',
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BusinessReviewsPage(
                      businessId: _currentUser!.uid,
                      businessName: _businessName,
                    ),
                  ),
                );
              },
            );
          },
        ),
        
        // MENU ITEMS CARD
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
        
        // PROMOTIONS CARD - with real-time count
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
        
        // ANALYTICS CARD - Business insights
        _buildModuleCard(
          icon: Icons.analytics,
          label: 'Analytics',
          value: 'Insights',
          color: Colors.indigo,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BusinessAnalyticsPage(
                  businessId: _currentUser!.uid,
                  businessName: _businessName,
                ),
              ),
            );
          },
        ),
        
        // SETTINGS CARD REMOVED - as per request
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
          
          // ========== MAIN MENU ITEMS ==========
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Profile'),
            onTap: () async {
              Navigator.pop(context);
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BusinessProfileEditorPage(),
                ),
              );
              
              // Refresh dashboard if profile was updated
              if (result == true) {
                await _fetchBusinessData();
                await _loadActivePromotionCount();
              }
            },
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
          
          // ========== INFORMATION & SUPPORT ==========
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.blue),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description, color: Colors.orange),
            title: const Text('Terms & Conditions'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: Colors.green),
            title: const Text('Privacy Policy'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag, color: Colors.red),
            title: const Text('Report Issue'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportPage()),
              );
            },
          ),
          
          const Divider(),
          
          // ========== LOGOUT ==========
          ListTile(
            leading: Icon(Icons.logout, color: AppTheme.errorRed),
            title: Text('Sign Out', style: TextStyle(color: AppTheme.errorRed)),
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
}

// ============================================================================
// BUSINESS VIEWS PAGE
// ============================================================================
class BusinessViewsPage extends StatelessWidget {
  final String businessId;
  final String businessName;

  const BusinessViewsPage({
    Key? key,
    required this.businessId,
    required this.businessName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Views'),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(AppConfig.businessesCollection)
            .doc(businessId)
            .collection('views')
            .orderBy('viewedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility_off, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No views yet',
                    style: AppTheme.titleLarge.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Views will appear here when users visit your business profile',
                    style: AppTheme.bodyMedium.copyWith(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final views = snapshot.data!.docs;
          final totalViews = views.length;

          // Group views by date
          final Map<String, List<QueryDocumentSnapshot>> viewsByDate = {};
          for (var view in views) {
            final data = view.data() as Map<String, dynamic>;
            final viewedAt = (data['viewedAt'] as Timestamp).toDate();
            final dateKey = '${viewedAt.year}-${viewedAt.month.toString().padLeft(2, '0')}-${viewedAt.day.toString().padLeft(2, '0')}';
            
            if (!viewsByDate.containsKey(dateKey)) {
              viewsByDate[dateKey] = [];
            }
            viewsByDate[dateKey]!.add(view);
          }

          return Column(
            children: [
              // Stats Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.blue.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '$totalViews',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Total Views',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${viewsByDate.length} days with activity',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // Views List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: viewsByDate.length,
                  itemBuilder: (context, index) {
                    final dateKey = viewsByDate.keys.elementAt(index);
                    final dateViews = viewsByDate[dateKey]!;
                    final date = DateTime.parse(dateKey);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: const Icon(Icons.calendar_today, color: Colors.blue),
                        title: Text(
                          _formatDate(date),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${dateViews.length} views'),
                        children: dateViews.map((viewDoc) {
                          final data = viewDoc.data() as Map<String, dynamic>;
                          final viewedAt = (data['viewedAt'] as Timestamp).toDate();
                          final userId = data['userId'] as String?;
                          final isAnonymous = userId == null || userId.isEmpty || userId == 'anonymous';

                          return ListTile(
                            dense: true,
                            leading: Icon(
                              isAnonymous ? Icons.person_outline : Icons.person,
                              color: isAnonymous ? Colors.grey : Colors.blue,
                            ),
                            title: Text(
                              isAnonymous ? 'Anonymous User' : 'Registered User',
                              style: TextStyle(
                                color: isAnonymous ? Colors.grey[600] : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              '${viewedAt.hour.toString().padLeft(2, '0')}:${viewedAt.minute.toString().padLeft(2, '0')}',
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
}

// ============================================================================
// BUSINESS BOOKMARKS PAGE
// ============================================================================
class BusinessBookmarksPage extends StatelessWidget {
  final String businessId;
  final String businessName;

  const BusinessBookmarksPage({
    Key? key,
    required this.businessId,
    required this.businessName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        backgroundColor: Colors.red,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('bookmarks')
            .where('businessId', isEqualTo: businessId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No bookmarks yet',
                    style: AppTheme.titleLarge.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When users bookmark your business, they\'ll appear here',
                    style: AppTheme.bodyMedium.copyWith(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final bookmarks = snapshot.data!.docs;
          
          // Group by label
          final Map<String, int> labelCounts = {};
          for (var bookmark in bookmarks) {
            final data = bookmark.data() as Map<String, dynamic>;
            final label = data['label'] as String? ?? 'No Label';
            labelCounts[label] = (labelCounts[label] ?? 0) + 1;
          }

          return Column(
            children: [
              // Stats Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red, Colors.red.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '${bookmarks.length}',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Total Bookmarks',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // Label Statistics
              if (labelCounts.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.label, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Bookmark Labels',
                                style: AppTheme.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          ...labelCounts.entries.map((entry) {
                            final percentage = (entry.value / bookmarks.length * 100).toStringAsFixed(1);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(entry.key),
                                  ),
                                  Text(
                                    '${entry.value} ($percentage%)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Recent Bookmarks
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Bookmarks',
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: bookmarks.length,
                  itemBuilder: (context, index) {
                    final data = bookmarks[index].data() as Map<String, dynamic>;
                    final label = data['label'] as String? ?? 'No Label';
                    final bookmarkedAt = (data['bookmarkedAt'] as Timestamp).toDate();

                    Color labelColor;
                    switch (label) {
                      case 'Want to Try':
                        labelColor = Colors.orange;
                        break;
                      case 'Favorites':
                        labelColor = Colors.red;
                        break;
                      case 'Date Night':
                        labelColor = Colors.pink;
                        break;
                      case 'Good for Groups':
                        labelColor = Colors.blue;
                        break;
                      default:
                        labelColor = Colors.grey;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          Icons.bookmark,
                          color: labelColor,
                        ),
                        title: Text(label),
                        subtitle: Text(_formatDateTime(bookmarkedAt)),
                        trailing: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: labelColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'Just now';
        }
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
}

// ============================================================================
// BUSINESS REVIEWS PAGE
// ============================================================================
class BusinessReviewsPage extends StatefulWidget {
  final String businessId;
  final String businessName;

  const BusinessReviewsPage({
    Key? key,
    required this.businessId,
    required this.businessName,
  }) : super(key: key);

  @override
  State<BusinessReviewsPage> createState() => _BusinessReviewsPageState();
}

class _BusinessReviewsPageState extends State<BusinessReviewsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, TextEditingController> _replyControllers = {};

  @override
  void dispose() {
    for (var controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submitReply(String reviewId, String reply) async {
    if (reply.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reply')),
      );
      return;
    }

    try {
      await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(widget.businessId)
          .collection('reviews')
          .doc(reviewId)
          .update({
        'businessReply': reply.trim(),
        'businessRepliedAt': FieldValue.serverTimestamp(),
      });

      _replyControllers[reviewId]?.clear();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply posted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting reply: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    try {
      print('=======================================');
      print('FETCHING USER DATA');
      print('User ID: $userId');
      print('Collection: ${AppConfig.usersCollection}');
      
      final userDoc = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(userId)
          .get();
      
      print('Document exists: ${userDoc.exists}');
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        print('SUCCESS - USER DATA FOUND:');
        print('   Name: ${userData?['name']}');
        print('   Email: ${userData?['email']}');
        print('   Photo URL: ${userData?['photoUrl']}');
        print('=======================================');
        return userData;
      } else {
        print('ERROR - USER DOCUMENT DOES NOT EXIST');
        print('=======================================');
      }
    } catch (e) {
      print('ERROR FETCHING USER DATA: $e');
      print('=======================================');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews'),
        backgroundColor: Colors.purple,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection(AppConfig.businessesCollection)
            .doc(widget.businessId)
            .snapshots(),
        builder: (context, businessSnapshot) {
          double avgRating = 0.0;
          int reviewCount = 0;

          if (businessSnapshot.hasData && businessSnapshot.data!.exists) {
            final data = businessSnapshot.data!.data() as Map<String, dynamic>?;
            avgRating = (data?['avgRating'] ?? 0.0).toDouble();
            reviewCount = data?['reviewCount'] ?? 0;
          }

          return Column(
            children: [
              // Rating Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple, Colors.purple.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return Icon(
                          index < avgRating.floor()
                              ? Icons.star
                              : index < avgRating
                                  ? Icons.star_half
                                  : Icons.star_border,
                          color: Colors.amber,
                          size: 24,
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$reviewCount ${reviewCount == 1 ? 'Review' : 'Reviews'}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // Reviews List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection(AppConfig.businessesCollection)
                      .doc(widget.businessId)
                      .collection('reviews')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.rate_review_outlined, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No reviews yet',
                              style: AppTheme.titleLarge.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Reviews from customers will appear here',
                              style: AppTheme.bodyMedium.copyWith(color: Colors.grey[500]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    final reviews = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: reviews.length,
                      itemBuilder: (context, index) {
                        final reviewData = reviews[index].data() as Map<String, dynamic>;
                        final reviewId = reviews[index].id;
                        final userId = reviewData['userId'] as String;
                        final rating = (reviewData['rating'] ?? 0).toDouble();
                        final comment = reviewData['comment'] as String? ?? '';
                        final createdAt = reviewData['timestamp'] as Timestamp?;
                        final businessReply = reviewData['businessReply'] as String?;
                        final repliedAt = reviewData['businessRepliedAt'] as Timestamp?;

                        // Create controller if it doesn't exist
                        if (!_replyControllers.containsKey(reviewId)) {
                          _replyControllers[reviewId] = TextEditingController();
                        }

                        return FutureBuilder<Map<String, dynamic>?>(
                          future: _getUserData(userId),
                          builder: (context, userSnapshot) {
                            // Handle loading state
                            if (userSnapshot.connectionState == ConnectionState.waiting) {
                              final userName = 'Loading...';
                              final userPhoto = null;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: AppTheme.primaryGreen.withOpacity(0.2),
                                            child: const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  userName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                if (createdAt != null)
                                                  Text(
                                                    _formatDateTime(createdAt.toDate()),
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                rating.toStringAsFixed(1),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.star, color: Colors.amber, size: 20),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            
                            // Use fetched data with proper null safety
                            final userName = userSnapshot.hasData && userSnapshot.data != null
                                ? (userSnapshot.data!['name'] ?? 'Anonymous User')
                                : 'Anonymous User';
                            final userPhoto = userSnapshot.hasData && userSnapshot.data != null
                                ? userSnapshot.data!['photoUrl']
                                : null;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // User Info & Rating
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: AppTheme.primaryGreen.withOpacity(0.2),
                                          backgroundImage: userPhoto != null
                                              ? NetworkImage(userPhoto)
                                              : null,
                                          child: userPhoto == null
                                              ? Text(
                                                  userName[0].toUpperCase(),
                                                  style: TextStyle(
                                                    color: AppTheme.primaryGreen,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                userName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (createdAt != null)
                                                Text(
                                                  _formatDateTime(createdAt.toDate()),
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              rating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.star, color: Colors.amber, size: 20),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Review Text
                                    if (comment.isNotEmpty)
                                      Text(
                                        comment,
                                        style: const TextStyle(fontSize: 14),
                                      ),

                                    // Business Reply (if exists)
                                    if (businessReply != null && businessReply.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryGreen.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppTheme.primaryGreen.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.business,
                                                  size: 16,
                                                  color: AppTheme.primaryGreen,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Response from ${widget.businessName}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.primaryGreen,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              businessReply,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                            if (repliedAt != null) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                _formatDateTime(repliedAt.toDate()),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],

                                    // Reply Form (if no reply exists)
                                    if (businessReply == null || businessReply.isEmpty) ...[
                                      const SizedBox(height: 16),
                                      TextField(
                                        controller: _replyControllers[reviewId],
                                        decoration: InputDecoration(
                                          hintText: 'Write a response...',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: AppTheme.primaryGreen,
                                              width: 2,
                                            ),
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(Icons.send, color: AppTheme.primaryGreen),
                                            onPressed: () {
                                              _submitReply(
                                                reviewId,
                                                _replyControllers[reviewId]!.text,
                                              );
                                            },
                                          ),
                                        ),
                                        maxLines: 2,
                                        textCapitalization: TextCapitalization.sentences,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'Just now';
        }
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
}

// ============================================================================
// BUSINESS ANALYTICS PAGE
// ============================================================================
class BusinessAnalyticsPage extends StatelessWidget {
  final String businessId;
  final String businessName;

  const BusinessAnalyticsPage({
    Key? key,
    required this.businessId,
    required this.businessName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection(AppConfig.businessesCollection)
            .doc(businessId)
            .snapshots(),
        builder: (context, businessSnapshot) {
          if (businessSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final businessData = businessSnapshot.data?.data() as Map<String, dynamic>?;
          final avgRating = (businessData?['avgRating'] ?? 0.0).toDouble();
          final reviewCount = businessData?['reviewCount'] ?? 0;
          final viewCount = businessData?['viewCount'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview Card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics, color: Colors.indigo, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'Performance Overview',
                              style: AppTheme.titleLarge.copyWith(
                                color: Colors.indigo,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildStatRow('Total Views', '$viewCount', Icons.visibility, Colors.blue),
                        _buildStatRow('Average Rating', avgRating.toStringAsFixed(1), Icons.star, Colors.amber),
                        _buildStatRow('Total Reviews', '$reviewCount', Icons.rate_review, Colors.purple),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Bookmarks Analytics
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('bookmarks')
                      .where('businessId', isEqualTo: businessId)
                      .snapshots(),
                  builder: (context, bookmarkSnapshot) {
                    if (!bookmarkSnapshot.hasData) {
                      return const SizedBox();
                    }

                    final bookmarks = bookmarkSnapshot.data!.docs;
                    final bookmarkCount = bookmarks.length;

                    // Count by label
                    final Map<String, int> labelCounts = {
                      'Want to Try': 0,
                      'Favorites': 0,
                      'Date Night': 0,
                      'Good for Groups': 0,
                    };

                    for (var bookmark in bookmarks) {
                      final data = bookmark.data() as Map<String, dynamic>;
                      final label = data['label'] as String?;
                      if (label != null && labelCounts.containsKey(label)) {
                        labelCounts[label] = labelCounts[label]! + 1;
                      }
                    }

                    return Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bookmark, color: Colors.red, size: 28),
                                const SizedBox(width: 12),
                                Text(
                                  'Bookmark Insights',
                                  style: AppTheme.titleLarge.copyWith(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _buildStatRow('Total Bookmarks', '$bookmarkCount', Icons.bookmark, Colors.red),
                            const SizedBox(height: 16),
                            ...labelCounts.entries.map((entry) {
                              final percentage = bookmarkCount > 0
                                  ? (entry.value / bookmarkCount * 100).toStringAsFixed(1)
                                  : '0.0';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(entry.key),
                                        Text(
                                          '${entry.value} ($percentage%)',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: bookmarkCount > 0 ? entry.value / bookmarkCount : 0,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _getLabelColor(entry.key),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Rating Distribution
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(AppConfig.businessesCollection)
                      .doc(businessId)
                      .collection('reviews')
                      .snapshots(),
                  builder: (context, reviewSnapshot) {
                    if (!reviewSnapshot.hasData) {
                      return const SizedBox();
                    }

                    final reviews = reviewSnapshot.data!.docs;
                    final Map<int, int> ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

                    for (var review in reviews) {
                      final data = review.data() as Map<String, dynamic>;
                      final rating = (data['rating'] ?? 0).toInt();
                      if (ratingDistribution.containsKey(rating)) {
                        ratingDistribution[rating] = ratingDistribution[rating]! + 1;
                      }
                    }

                    return Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 28),
                                const SizedBox(width: 12),
                                Text(
                                  'Rating Distribution',
                                  style: AppTheme.titleLarge.copyWith(
                                    color: Colors.amber[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            ...ratingDistribution.entries.toList().reversed.map((entry) {
                              final percentage = reviews.isNotEmpty
                                  ? (entry.value / reviews.length * 100).toStringAsFixed(1)
                                  : '0.0';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 60,
                                          child: Row(
                                            children: [
                                              Text('${entry.key}'),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.star, size: 16, color: Colors.amber),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            value: reviews.isNotEmpty ? entry.value / reviews.length : 0,
                                            backgroundColor: Colors.grey[200],
                                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 80,
                                          child: Text(
                                            '${entry.value} ($percentage%)',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                // Response Rate
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(AppConfig.businessesCollection)
                      .doc(businessId)
                      .collection('reviews')
                      .snapshots(),
                  builder: (context, reviewSnapshot) {
                    if (!reviewSnapshot.hasData) {
                      return const SizedBox();
                    }

                    final reviews = reviewSnapshot.data!.docs;
                    final totalReviews = reviews.length;
                    final repliedReviews = reviews.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final reply = data['businessReply'] as String?;
                      return reply != null && reply.isNotEmpty;
                    }).length;

                    final responseRate = totalReviews > 0
                        ? (repliedReviews / totalReviews * 100).toStringAsFixed(1)
                        : '0.0';

                    return Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.reply, color: AppTheme.primaryGreen, size: 28),
                                const SizedBox(width: 12),
                                Text(
                                  'Customer Engagement',
                                  style: AppTheme.titleLarge.copyWith(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _buildStatRow(
                              'Response Rate',
                              '$responseRate%',
                              Icons.check_circle,
                              AppTheme.primaryGreen,
                            ),
                            _buildStatRow(
                              'Replied Reviews',
                              '$repliedReviews of $totalReviews',
                              Icons.reply,
                              AppTheme.primaryGreen,
                            ),
                            if (totalReviews > repliedReviews) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info, color: Colors.orange, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${totalReviews - repliedReviews} review(s) waiting for response',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 15)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getLabelColor(String label) {
    switch (label) {
      case 'Want to Try':
        return Colors.orange;
      case 'Favorites':
        return Colors.red;
      case 'Date Night':
        return Colors.pink;
      case 'Good for Groups':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}