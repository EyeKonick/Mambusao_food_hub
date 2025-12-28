// lib/explore.dart

import 'package:flutter/material.dart';
import 'config/app_theme.dart';
import 'business_auth_page.dart';
import 'admin_auth_page.dart';
import 'home_page.dart';

/// Landing Page - First screen users see
/// 
/// This page offers two paths:
/// 1. Explore Mambusao (for customers/users)
/// 2. Business Owner Login/Registration
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

  /// Navigate to Home Page (for customers)
  Future<void> _navigateToHomePage() async {
    setState(() {
      _isLoadingExplore = true;
    });

    // Small delay for smooth UX
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );

    // Reset loading state after returning
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Image.asset('assets/logo.png', height: 120),
                    const SizedBox(height: 32),

                    // Main Heading
                    Text(
                      'Explore Mambusao',
                      style: AppTheme.headingLarge.copyWith(
                        color: AppTheme.primaryGreen,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Your Mambusao food trip starts here.',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Primary Button - Explore
                    _buildExploreButton(),
                    const SizedBox(height: 16),

                    // Secondary Button - Business Owner
                    _buildBusinessOwnerButton(),
                    const SizedBox(height: 32),

                    // Footer Info
                    _buildFooterInfo(),
                  ],
                ),
              ),
            ),

            // Admin icon in top-right corner
            Positioned(
              top: 16,
              right: 16,
              child: _buildAdminAccessButton(),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== UI COMPONENTS ====================

  /// Primary explore button
  Widget _buildExploreButton() {
    return ElevatedButton(
      onPressed: _isLoadingExplore ? null : _navigateToHomePage,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: AppTheme.primaryGreen, // <- make button primary green
      ),
      child: _isLoadingExplore
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Use app color palette: white icon on primary green button
                Icon(Icons.restaurant_menu, size: 24, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  'Explore Mambusao',
                  style: AppTheme.titleMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }

  /// Business owner button
  Widget _buildBusinessOwnerButton() {
    return OutlinedButton(
      onPressed: _isLoadingBusiness ? null : _navigateToBusinessAuth,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        side: BorderSide(
          color: AppTheme.primaryGreen,
          width: 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isLoadingBusiness
          ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
                strokeWidth: 3,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.business_center,
                  size: 24,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(width: 12),
                Text(
                  'I am a business owner',
                  style: AppTheme.titleMedium.copyWith(
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
    );
  }

  /// Footer information
  Widget _buildFooterInfo() {
    return Column(
      children: [
        // Features highlight
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFeatureChip(Icons.search, 'Discover'),
            _buildFeatureChip(Icons.bookmark, 'Bookmark'),
            _buildFeatureChip(Icons.rate_review, 'Review'),
          ],
        ),
        const SizedBox(height: 24),

        // Version info
        Text(
          'MamFood Hub',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Connecting you with local flavors',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Feature chip widget
  Widget _buildFeatureChip(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryGreen,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Admin access button (top-right corner)
  Widget _buildAdminAccessButton() {
    return Material(
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryGreen.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 20,
                color: AppTheme.primaryGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}