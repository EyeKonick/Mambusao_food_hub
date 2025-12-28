// lib/terms_page.dart

import 'package:flutter/material.dart';
import 'config/app_theme.dart';

/// Terms of Use Page
/// 
/// Displays the terms and conditions for using MamFood Hub
/// Required for app store compliance and legal protection
class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Terms of Use'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description,
                    color: AppTheme.primaryGreen,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'By using the MamFood Hub application, users agree to comply with and be bound by the following terms and conditions:',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // User Responsibilities
            _buildSection(
              icon: Icons.person,
              title: 'User Responsibilities',
              content: [
                'Users are expected to provide accurate and truthful information during registration and profile updates.',
                'Users must not post inappropriate, offensive, or false reviews or content.',
                'Bookmarking, reviewing, and other app features must be used respectfully and lawfully.',
              ],
            ),

            const SizedBox(height: 20),

            // Business Owner Guidelines
            _buildSection(
              icon: Icons.business,
              title: 'Business Owner Guidelines',
              content: [
                'Business owners must ensure that all information provided (e.g., restaurant name, menu, location, promotions) is accurate and updated regularly.',
                'They are responsible for maintaining their business profiles and responding to customer feedback professionally.',
              ],
            ),

            const SizedBox(height: 20),

            // Admin Rights
            _buildSection(
              icon: Icons.admin_panel_settings,
              title: 'Admin Rights',
              content: [
                'Admins reserve the right to approve or reject business registrations.',
                'Admins may moderate content, manage users, and maintain the integrity of the app.',
                'Any violation of app policies may result in suspension or deletion of user or business accounts.',
              ],
            ),

            const SizedBox(height: 20),

            // Privacy and Data
            _buildSection(
              icon: Icons.privacy_tip,
              title: 'Privacy and Data',
              content: [
                'MamFood Hub collects minimal personal data for account management and app functionality.',
                'Data is securely stored and will not be shared without user consent.',
              ],
            ),

            const SizedBox(height: 20),

            // Changes and Updates
            _buildSection(
              icon: Icons.update,
              title: 'Changes and Updates',
              content: [
                'MamFood Hub reserves the right to update or modify the terms at any time.',
                'Continued use of the app signifies acceptance of any changes made.',
                'By continuing to use MamFood Hub, you accept these terms and agree to use the platform responsibly.',
              ],
            ),

            const SizedBox(height: 32),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'If you have questions about these terms, please contact our support team.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<String> content,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Title
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryGreen, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.titleMedium.copyWith(
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            
            const Divider(height: 20),
            
            // Content
            ...content.map((text) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: AppTheme.bodyMedium.copyWith(
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }
}