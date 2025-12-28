// lib/privacy_page.dart
import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';

/// Privacy Policy Page
///
/// Displays privacy policy and data handling practices
/// Required for app store compliance and GDPR
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.privacy_tip,
                          color: AppTheme.warningOrange,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your Privacy Matters',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.warningOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Last Updated: December 2024',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This Privacy Policy explains how ${AppConfig.appName} collects, uses, and protects your personal information.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: Information We Collect
            _buildSection(
              context,
              icon: Icons.info,
              title: '1. Information We Collect',
              content: '''We collect the following types of information:

**Account Information:**
- Name, email address, and phone number
- Profile photo (optional)
- Account type (User or Business Owner)

**Business Information (for Business Owners):**
- Business name and description
- Business address and location coordinates
- Business type and category
- Contact information
- Business logo and photos
- Menu items and pricing
- Promotional offers

**User Activity:**
- Bookmarks and saved restaurants
- Reviews and ratings submitted
- Search history within the app
- Location data (when using map features)

**Device Information:**
- Device type and operating system
- App version and usage statistics
- IP address for security purposes''',
            ),
            const SizedBox(height: 16),

            // Section 2: How We Use Your Information
            _buildSection(
              context,
              icon: Icons.manage_accounts,
              title: '2. How We Use Your Information',
              content: '''We use your information to:

**Provide Core Services:**
- Create and manage your account
- Display restaurant information and reviews
- Enable bookmarking and saving favorites
- Process business registrations and approvals
- Show personalized recommendations

**Improve User Experience:**
- Analyze app usage patterns
- Optimize search and filter functionality
- Fix bugs and improve performance
- Develop new features based on feedback

**Communication:**
- Send account verification emails
- Notify about booking confirmations
- Share important app updates
- Respond to support requests

**Safety & Security:**
- Prevent fraud and unauthorized access
- Monitor for policy violations
- Enforce our Terms of Use
- Protect user data and privacy''',
            ),
            const SizedBox(height: 16),

            // Section 3: Data Sharing and Disclosure
            _buildSection(
              context,
              icon: Icons.share,
              title: '3. Data Sharing and Disclosure',
              content: '''**We DO NOT sell your personal data to third parties.**

We only share information in these limited cases:

**Public Information:**
- Restaurant listings and reviews are visible to all users
- Your display name and profile photo (if set) appear with reviews
- Business information is publicly accessible in the app

**Service Providers:**
- Firebase (Google) - Authentication and database hosting
- Cloudinary - Image storage and delivery
- Google Maps - Location and mapping services

**Legal Requirements:**
- When required by law or legal process
- To protect our rights and property
- To prevent fraud or security threats
- To comply with government requests

**Business Transfers:**
- In case of merger, acquisition, or sale of assets
- Users will be notified of any ownership changes''',
            ),
            const SizedBox(height: 16),

            // Section 4: Data Security
            _buildSection(
              context,
              icon: Icons.security,
              title: '4. Data Security',
              content: '''We implement industry-standard security measures:

**Technical Safeguards:**
- Encrypted data transmission (HTTPS/SSL)
- Secure Firebase Authentication
- Role-based access controls
- Regular security audits

**Access Controls:**
- Users can only access their own data
- Business owners manage only their business
- Admins have limited, audited access
- Email verification required for accounts

**Data Protection:**
- Regular backups of all data
- Secure cloud storage with Firebase
- Image validation (size and format limits)
- Protection against unauthorized access

**Your Responsibility:**
- Keep your password secure and confidential
- Log out on shared devices
- Report suspicious activity immediately
- Review your account settings regularly

While we strive to protect your data, no system is 100% secure. Please use caution when sharing personal information.''',
            ),
            const SizedBox(height: 16),

            // Section 5: Your Rights
            _buildSection(
              context,
              icon: Icons.verified_user,
              title: '5. Your Rights',
              content: '''You have the following rights regarding your data:

**Access & Correction:**
- View your profile information anytime
- Update your personal details
- Change your profile photo
- Edit your reviews and bookmarks

**Data Deletion:**
- Delete your own reviews
- Remove bookmarks
- Request account deletion (contact admin)
- Business data removed after account deletion

**Privacy Controls:**
- Choose what information to share
- Control visibility of profile photo
- Opt-out of promotional communications
- Manage location permissions

**Account Management:**
- Deactivate your account temporarily
- Permanently delete your account
- Export your data (upon request)
- Transfer data to another service

To exercise any of these rights, contact us through the "Report a Problem" feature in the app or email us at support@mamfoodhub.com.''',
            ),
            const SizedBox(height: 16),

            // Section 6: Contact Us
            _buildSection(
              context,
              icon: Icons.contact_support,
              title: '6. Contact Us',
              content: '''If you have questions about this Privacy Policy:

**In-App Support:**
- Use "Report a Problem" in the app menu
- Response time: 24-48 hours

**Email:**
- support@mamfoodhub.com
- For privacy concerns: privacy@mamfoodhub.com

**Mail:**
- ${AppConfig.appName} Development Team
- Capiz State University
- Mambusao, Capiz, Philippines

We take your privacy seriously and will respond to all inquiries promptly.''',
            ),
            const SizedBox(height: 24),

            // Footer
            Card(
              color: AppTheme.warningOrange.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.warningOrange,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'By using ${AppConfig.appName}, you agree to this Privacy Policy.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last Updated: December 2024 | Version 1.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.warningOrange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warningOrange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}