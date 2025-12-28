// lib/about_page.dart

import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';

/// About Us Page
/// 
/// Displays information about the app, team, and mission
/// Important for thesis defense and app credibility
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  final List<Map<String, dynamic>> _developers = const [
    {
      'name': 'Martin Francisco',
      'role': 'Lead Developer',
      'icon': Icons.code,
    },
    {
      'name': 'Arjay Lalis',
      'role': 'Backend Developer',
      'icon': Icons.storage,
    },
    {
      'name': 'Ela Lizada',
      'role': 'UI/UX Designer',
      'icon': Icons.palette,
    },
    {
      'name': 'Justin Roi Perlas',
      'role': 'Quality Assurance',
      'icon': Icons.verified,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('About Us'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App Logo and Name
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryGreen,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        Icons.restaurant_menu,
                        size: 50,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppConfig.appName,
                      style: AppTheme.headingLarge.copyWith(
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version ${AppConfig.appVersion}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // About Us Section
            _buildSection(
              icon: Icons.info,
              title: 'About Us',
              content: 'MamFood Hub is a mobile application proudly developed by a team of passionate Bachelor of Science in Computer Science students from Capiz State University – Mambusao Satellite College. As part of our thesis project, we created this app with a shared vision: to make food discovery easier and more accessible for the people of Mambusao.',
            ),

            const SizedBox(height: 20),

            // Our Mission Section
            _buildSection(
              icon: Icons.flag,
              title: 'Our Mission',
              content: 'To empower users and small food businesses in Mambusao by providing a digital platform that makes food discovery easier, promotes local eateries, and supports food tourism through innovative technology.',
            ),

            const SizedBox(height: 24),

            // Developers Section
            Text(
              'About the Developers',
              style: AppTheme.titleMedium.copyWith(
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 12),

            // Developer Cards
            ..._developers.map((dev) => Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        dev['icon'] as IconData,
                        color: AppTheme.primaryGreen,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dev['name'] as String,
                            style: AppTheme.titleSmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dev['role'] as String,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )).toList(),

            const SizedBox(height: 24),

            // Team Message Card
            Card(
              elevation: 4,
              color: AppTheme.primaryGreen,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.groups,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Made by Locals, for Locals',
                      style: AppTheme.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Together, we combined our skills and passion to develop MamFood Hub, a simple, user-friendly tool designed to connect the Mambusao community with local food businesses.',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Features Grid
            Text(
              'Key Features',
              style: AppTheme.titleMedium.copyWith(
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 12),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildFeatureCard(
                  icon: Icons.search,
                  title: 'Discover',
                  description: 'Find local restaurants',
                ),
                _buildFeatureCard(
                  icon: Icons.bookmark,
                  title: 'Bookmark',
                  description: 'Save favorites',
                ),
                _buildFeatureCard(
                  icon: Icons.rate_review,
                  title: 'Review',
                  description: 'Share experiences',
                ),
                _buildFeatureCard(
                  icon: Icons.map,
                  title: 'Navigate',
                  description: 'Get directions',
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Credits Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.school,
                    color: AppTheme.primaryGreen,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Capiz State University',
                    style: AppTheme.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mambusao Satellite College',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bachelor of Science in Computer Science',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '© 2024 MamFood Hub. All rights reserved.',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
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
    required String content,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryGreen, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: AppTheme.titleMedium.copyWith(
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              content,
              style: AppTheme.bodyMedium.copyWith(
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: AppTheme.primaryGreen,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTheme.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}