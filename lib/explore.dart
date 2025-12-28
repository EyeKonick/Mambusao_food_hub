// lib/explore.dart

import 'package:flutter/material.dart';
import 'config/app_theme.dart';
import 'business_auth_page.dart';
import 'admin_auth_page.dart';
import 'home_page.dart';

/// Landing Page - First screen users see
/// 
/// Enhanced UI with modern design inspired by reference images
/// - Full-screen hero layout
/// - Gradient overlay on background
/// - Modern card-based buttons
/// - Feature highlights with icons
/// - Clean typography with Poppins font
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  // Loading states for buttons
  bool _isLoadingExplore = false;
  bool _isLoadingBusiness = false;

  // ==================== NAVIGATION HANDLERS ====================
  // NO CHANGES - Business logic preserved

  /// Navigate to Home Page (for customers)
  Future<void> _navigateToHomePage() async {
    setState(() {
      _isLoadingExplore = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );

    if (mounted) {
      setState(() {
        _isLoadingExplore = false;
      });
    }
  }

  /// Navigate to Business Auth Page (for business owners)
  Future<void> _navigateToBusinessAuth() async {
    setState(() {
      _isLoadingBusiness = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BusinessAuthPage()),
    );

    if (mounted) {
      setState(() {
        _isLoadingBusiness = false;
      });
    }
  }

  // ==================== BUILD METHOD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content with enhanced layout
            SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                             MediaQuery.of(context).padding.top,
                ),
                child: Column(
                  children: [
                    // Hero section with gradient background
                    _buildHeroSection(),
                    
                    // Main content area
                    _buildContentSection(),
                  ],
                ),
              ),
            ),

            // Admin icon in top-right corner
            Positioned(
              top: AppTheme.space16,
              right: AppTheme.space16,
              child: _buildAdminAccessButton(),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== UI COMPONENTS ====================

  /// Hero section with gradient and branding
  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppTheme.space24,
        AppTheme.space48,
        AppTheme.space24,
        AppTheme.space32,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen,
            AppTheme.secondaryGreen,
          ],
        ),
      ),
      child: Column(
        children: [
          // Logo with enhanced shadow
          Container(
            padding: EdgeInsets.all(AppTheme.space16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
              boxShadow: AppTheme.shadowCardHeavy,
            ),
            child: Image.asset(
              'assets/logo.png',
              height: 100,
              width: 100,
            ),
          ),
          SizedBox(height: AppTheme.space32),

          // Main heading with white text
          Text(
            'Explore Mambusao',
            style: AppTheme.displayLarge.copyWith(
              color: Colors.white,
              fontSize: 36,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.space12),

          // Subtitle with semi-transparent white
          Text(
            'Your Mambusao food trip starts here.',
            style: AppTheme.bodyLarge.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Main content section with buttons and features
  Widget _buildContentSection() {
    return Padding(
      padding: EdgeInsets.all(AppTheme.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome message
          Text(
            'What would you like to do?',
            style: AppTheme.headlineMedium.copyWith(
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.space8),
          
          Text(
            'Choose your path to discover local flavors',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.space32),

          // Primary Button - Explore (Enhanced Card Style)
          _buildExploreButton(),
          SizedBox(height: AppTheme.space16),

          // Secondary Button - Business Owner (Enhanced Card Style)
          _buildBusinessOwnerButton(),
          SizedBox(height: AppTheme.space48),

          // Feature highlights
          _buildFeatureHighlights(),
          SizedBox(height: AppTheme.space32),

          // Footer info
          _buildFooterInfo(),
        ],
      ),
    );
  }

  /// Enhanced primary explore button (card-based design)
  Widget _buildExploreButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: InkWell(
          onTap: _isLoadingExplore ? null : _navigateToHomePage,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Container(
            padding: EdgeInsets.all(AppTheme.space20),
            child: _isLoadingExplore
                ? Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      // Icon container with green background
                      Container(
                        padding: EdgeInsets.all(AppTheme.space12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: Icon(
                          Icons.restaurant_menu,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: AppTheme.space16),
                      
                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Explore Mambusao',
                              style: AppTheme.titleLarge.copyWith(
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: AppTheme.space4),
                            Text(
                              'Discover local restaurants & cafes',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Arrow icon
                      Icon(
                        Icons.arrow_forward_ios,
                        color: AppTheme.primaryGreen,
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Enhanced business owner button (card-based design)
  Widget _buildBusinessOwnerButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCardLight,
        border: Border.all(
          color: AppTheme.primaryGreen,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: InkWell(
          onTap: _isLoadingBusiness ? null : _navigateToBusinessAuth,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Container(
            padding: EdgeInsets.all(AppTheme.space20),
            child: _isLoadingBusiness
                ? Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      // Icon container with outlined style
                      Container(
                        padding: EdgeInsets.all(AppTheme.space12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(
                            color: AppTheme.primaryGreen,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.business_center,
                          color: AppTheme.primaryGreen,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: AppTheme.space16),
                      
                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'I am a business owner',
                              style: AppTheme.titleLarge.copyWith(
                                color: AppTheme.primaryGreen,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: AppTheme.space4),
                            Text(
                              'Register or manage your business',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Arrow icon
                      Icon(
                        Icons.arrow_forward_ios,
                        color: AppTheme.primaryGreen,
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Feature highlights section with modern cards
  Widget _buildFeatureHighlights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What you can do',
          style: AppTheme.headlineMedium.copyWith(
            fontSize: 18,
          ),
        ),
        SizedBox(height: AppTheme.space16),
        
        Row(
          children: [
            Expanded(child: _buildFeatureCard(Icons.search, 'Discover', 'Find great food spots')),
            SizedBox(width: AppTheme.space12),
            Expanded(child: _buildFeatureCard(Icons.bookmark, 'Bookmark', 'Save favorites')),
            SizedBox(width: AppTheme.space12),
            Expanded(child: _buildFeatureCard(Icons.rate_review, 'Review', 'Share feedback')),
          ],
        ),
      ],
    );
  }

  /// Individual feature card (modern card design)
  Widget _buildFeatureCard(IconData icon, String label, String description) {
    return Container(
      padding: EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCardLight,
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(AppTheme.space12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryGreen,
              size: 28,
            ),
          ),
          SizedBox(height: AppTheme.space12),
          Text(
            label,
            style: AppTheme.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.space4),
          Text(
            description,
            style: AppTheme.caption.copyWith(
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Footer information
  Widget _buildFooterInfo() {
    return Column(
      children: [
        // App branding
        Text(
          'MamFood Hub',
          style: AppTheme.titleMedium.copyWith(
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: AppTheme.space4),
        Text(
          'Connecting you with local flavors',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppTheme.space16),
        
        // Version badge
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.space16,
            vertical: AppTheme.space8,
          ),
          decoration: BoxDecoration(
            color: AppTheme.lightGreen.withOpacity(0.3),
            borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
          ),
          child: Text(
            'Version 1.0.0',
            style: AppTheme.labelSmall.copyWith(
              color: AppTheme.primaryGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Admin access button (enhanced, top-right corner)
  Widget _buildAdminAccessButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.shadowButton,
        border: Border.all(
          color: AppTheme.primaryGreen.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminAuthPage(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: EdgeInsets.all(AppTheme.space12),
            child: Icon(
              Icons.admin_panel_settings,
              size: 24,
              color: AppTheme.primaryGreen,
            ),
          ),
        ),
      ),
    );
  }
}