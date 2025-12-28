// ====================================================================
// ENHANCED USER PROFILE PAGE
// UI Enhancement Phase - Modern, Clean Design with Poppins Font
// 
// ENHANCEMENTS APPLIED:
// - Modern profile header with large circular avatar
// - Enhanced stats cards with icons and colors
// - Improved profile info card design
// - Menu items with modern list tiles
// - Enhanced dialogs and snackbars
// - Consistent spacing and typography
// - Professional shadows and borders
// ====================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'bookmarks_page.dart';
import 'terms_page.dart';
import 'privacy_page.dart';
import 'report_page.dart';
import 'about_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isEditing = false;
  bool _isUploading = false;
  String? _uploadProgress;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ==================== DATA LOADING ====================
  
  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      final userDoc = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
        });
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error loading user data: $e');
      }
    }
  }

  // ==================== PROFILE OPERATIONS ====================
  
  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Validation
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Name cannot be empty',
            style: AppTheme.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );
      return;
    }

    try {
      await _firestore.collection(AppConfig.usersCollection).doc(user.uid).update({
        'name': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await user.updateDisplayName(_nameController.text.trim());

      setState(() => _isEditing = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Profile updated successfully!',
                style: AppTheme.bodyMedium.copyWith(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error updating profile: $e',
            style: AppTheme.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );
    }
  }

  Future<void> _uploadProfilePhoto() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
        _uploadProgress = 'Preparing upload...';
      });

      final File imageFile = File(image.path);
      final fileSize = await imageFile.length();

      if (!AppConfig.isValidImageSize(fileSize)) {
        throw Exception('Image too large. Max size: 5MB');
      }

      setState(() => _uploadProgress = 'Uploading to Cloudinary...');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConfig.cloudinaryApiUrl),
      );

      request.fields['upload_preset'] = AppConfig.cloudinaryUploadPreset;
      request.fields['folder'] = 'user_profiles';

      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Upload failed: ${response.body}');
      }

      final responseData = json.decode(response.body);
      final imageUrl = responseData['secure_url'] as String;

      setState(() => _uploadProgress = 'Saving to profile...');

      await _firestore.collection(AppConfig.usersCollection).doc(user.uid).update({
        'photoUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await user.updatePhotoURL(imageUrl);

      setState(() {
        _isUploading = false;
        _uploadProgress = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Profile photo updated!',
                style: AppTheme.bodyMedium.copyWith(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgress = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error uploading photo: $e',
            style: AppTheme.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );
    }
  }

  // ==================== STATISTICS STREAMS ====================
  
  Stream<int> _getBookmarksCountStream() {
    final user = _auth.currentUser;
    
    if (user == null || user.isAnonymous) {
      if (AppConfig.enableDebugMode) {
        debugPrint('⚠️ Bookmarks: User not authenticated');
      }
      return Stream.value(0);
    }

    return _firestore
        .collection(AppConfig.usersCollection)
        .doc(user.uid)
        .collection(AppConfig.bookmarksSubcollection)
        .snapshots()
        .map((snapshot) {
          final count = snapshot.docs.length;
          if (AppConfig.enableDebugMode) {
            debugPrint('✓ Bookmarks count: $count');
          }
          return count;
        });
  }

  Stream<int> _getReviewsCountStream() {
    final user = _auth.currentUser;
    
    if (user == null || user.isAnonymous) {
      if (AppConfig.enableDebugMode) {
        debugPrint('⚠️ Reviews: User not authenticated');
      }
      return Stream.value(0);
    }

    if (AppConfig.enableDebugMode) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📊 Fetching review count for user: ${user.uid}');
      debugPrint('   Collection: ${AppConfig.reviewsSubcollection}');
    }

    return _firestore
        .collectionGroup(AppConfig.reviewsSubcollection)
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .handleError((error) {
          if (AppConfig.enableDebugMode) {
            debugPrint('❌ Review count error: $error');
            if (error.toString().contains('index')) {
              debugPrint('⚠️ MISSING FIRESTORE INDEX!');
              debugPrint('   Click the link above in the error to create it.');
              debugPrint('   Or manually create index in Firebase Console:');
              debugPrint('   Collection: reviews (collection group)');
              debugPrint('   Field: userId (Ascending)');
            }
          }
          return Stream.value(0);
        })
        .map((snapshot) {
          final count = snapshot.docs.length;
          if (AppConfig.enableDebugMode) {
            debugPrint('✓ Reviews count: $count documents found');
            if (count > 0) {
              debugPrint('   Review IDs: ${snapshot.docs.map((d) => d.id).join(", ")}');
            }
          }
          return count;
        });
  }

  // ==================== MAIN BUILD METHOD (ENHANCED) ====================
  
  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null || user.isAnonymous) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Profile',
            style: AppTheme.titleLarge.copyWith(color: Colors.white),
          ),
          backgroundColor: AppTheme.primaryGreen,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  size: 100,
                  color: AppTheme.textHint,
                ),
                const SizedBox(height: AppTheme.space24),
                Text(
                  'Sign in to view your profile',
                  style: AppTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.space12),
                Text(
                  'Create an account to bookmark restaurants and write reviews',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.space32),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/');
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: AppTheme.titleLarge.copyWith(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection(AppConfig.usersCollection)
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(height: AppTheme.space16),
                    Text(
                      'Error loading profile',
                      style: AppTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Please try again later',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final photoUrl = userData?['photoUrl'] as String?;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header with Avatar
                _buildProfileHeader(user, photoUrl),
                
                const SizedBox(height: AppTheme.space24),
                
                // Stats Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
                  child: _buildStatsCards(),
                ),
                
                const SizedBox(height: AppTheme.space24),
                
                // Profile Information Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
                  child: _buildProfileInfo(user),
                ),
                
                const SizedBox(height: AppTheme.space24),
                
                // Menu Items
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
                  child: _buildMenuItems(),
                ),
                
                const SizedBox(height: AppTheme.space24),
                
                // Sign Out Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
                  child: _buildSignOutButton(),
                ),
                
                const SizedBox(height: AppTheme.space32),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== PROFILE HEADER (ENHANCED) ====================
  
  Widget _buildProfileHeader(User user, String? photoUrl) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusXLarge),
          bottomRight: Radius.circular(AppTheme.radiusXLarge),
        ),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.space24),
          
          // Avatar with Camera Button
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Text(
                          user.displayName?.isNotEmpty == true
                              ? user.displayName![0].toUpperCase()
                              : user.email![0].toUpperCase(),
                          style: AppTheme.displayLarge.copyWith(
                            color: AppTheme.primaryGreen,
                            fontSize: 48,
                          ),
                        )
                      : null,
                ),
              ),
              
              // Camera button
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isUploading ? null : _uploadProfilePhoto,
                      borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.space8),
                        child: _isUploading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryGreen,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: AppTheme.primaryGreen,
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.space16),
          
          // User Name
          Text(
            user.displayName ?? 'User',
            style: AppTheme.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: AppTheme.space4),
          
          // User Email
          Text(
            user.email ?? '',
            style: AppTheme.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          
          // Upload Progress
          if (_isUploading && _uploadProgress != null) ...[
            const SizedBox(height: AppTheme.space12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space16,
                vertical: AppTheme.space8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
              ),
              child: Text(
                _uploadProgress!,
                style: AppTheme.bodySmall.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
          
          const SizedBox(height: AppTheme.space32),
        ],
      ),
    );
  }

  // ==================== STATS CARDS (ENHANCED) ====================
  
  Widget _buildStatsCards() {
    return Row(
      children: [
        // Bookmarks Card
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BookmarksPage()),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                boxShadow: AppTheme.shadowCardLight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bookmark,
                        size: 32,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space12),
                    StreamBuilder<int>(
                      stream: _getBookmarksCountStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryGreen,
                              ),
                            ),
                          );
                        }
                        
                        return Text(
                          '${snapshot.data ?? 0}',
                          style: AppTheme.headlineLarge.copyWith(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      'Bookmarks',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: AppTheme.space16),
        
        // Reviews Card
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              boxShadow: AppTheme.shadowCardLight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.space12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentYellow.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.rate_review,
                      size: 32,
                      color: AppTheme.accentYellow,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space12),
                  StreamBuilder<int>(
                    stream: _getReviewsCountStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.accentYellow,
                            ),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        if (AppConfig.enableDebugMode) {
                          debugPrint('❌ StreamBuilder error: ${snapshot.error}');
                        }
                        return Text(
                          '0',
                          style: AppTheme.headlineLarge.copyWith(
                            color: AppTheme.accentYellow,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }
                      
                      final count = snapshot.data ?? 0;
                      return Text(
                        '$count',
                        style: AppTheme.headlineLarge.copyWith(
                          color: AppTheme.accentYellow,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    'Reviews',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== PROFILE INFO CARD (ENHANCED) ====================
  
  Widget _buildProfileInfo(User user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.space8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Text(
                  'Profile Information',
                  style: AppTheme.titleLarge.copyWith(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.space20),
            const Divider(height: 1),
            const SizedBox(height: AppTheme.space20),
            
            // Name Field
            Text(
              'Full Name',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            TextField(
              controller: _nameController,
              enabled: _isEditing,
              style: AppTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Enter your name',
                hintStyle: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textHint,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryGreen,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: _isEditing ? Colors.white : AppTheme.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space16,
                  vertical: AppTheme.space16,
                ),
              ),
            ),
            
            const SizedBox(height: AppTheme.space20),
            
            // Email Field (Read-only)
            Text(
              'Email Address',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            TextField(
              controller: TextEditingController(text: user.email),
              enabled: false,
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                filled: true,
                fillColor: AppTheme.backgroundLight,
                suffixIcon: const Icon(
                  Icons.lock_outline,
                  size: 20,
                  color: AppTheme.textHint,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space16,
                  vertical: AppTheme.space16,
                ),
              ),
            ),
            
            const SizedBox(height: AppTheme.space20),
            
            // Phone Field
            Text(
              'Phone Number',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            TextField(
              controller: _phoneController,
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
              style: AppTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Enter your phone number',
                hintStyle: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textHint,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryGreen,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: _isEditing ? Colors.white : AppTheme.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space16,
                  vertical: AppTheme.space16,
                ),
              ),
            ),
            
            // Action Buttons (when editing)
            if (_isEditing) ...[
              const SizedBox(height: AppTheme.space24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _isEditing = false);
                        _loadUserData();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(
                          color: AppTheme.borderMedium,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.space16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTheme.labelLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.space16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Save Changes',
                        style: AppTheme.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== MENU ITEMS (ENHANCED) ====================
  
  Widget _buildMenuItems() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.bookmark,
            iconColor: AppTheme.primaryGreen,
            title: 'My Bookmarks',
            subtitle: 'View saved restaurants',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BookmarksPage()),
              );
            },
          ),
          const Divider(height: 1, indent: 68, endIndent: 16),
          
          _buildMenuItem(
            icon: Icons.description_outlined,
            iconColor: AppTheme.accentBlue,
            title: 'Terms of Use',
            subtitle: 'Read our terms',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermsPage()),
              );
            },
          ),
          const Divider(height: 1, indent: 68, endIndent: 16),
          
          _buildMenuItem(
            icon: Icons.privacy_tip_outlined,
            iconColor: AppTheme.accentYellow,
            title: 'Privacy Policy',
            subtitle: 'How we protect your data',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPage()),
              );
            },
          ),
          const Divider(height: 1, indent: 68, endIndent: 16),
          
          _buildMenuItem(
            icon: Icons.report_problem_outlined,
            iconColor: AppTheme.warningOrange,
            title: 'Report a Problem',
            subtitle: 'Get help with issues',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportPage()),
              );
            },
          ),
          const Divider(height: 1, indent: 68, endIndent: 16),
          
          _buildMenuItem(
            icon: Icons.info_outline,
            iconColor: AppTheme.accentBlue,
            title: 'About MamFood Hub',
            subtitle: 'Learn more about us',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutPage()),
              );
            },
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isLast ? 0 : AppTheme.radiusLarge),
          bottom: Radius.circular(isLast ? AppTheme.radiusLarge : 0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      subtitle,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textHint,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SIGN OUT BUTTON (ENHANCED) ====================
  
  Widget _buildSignOutButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCardLight,
        border: Border.all(
          color: AppTheme.errorRed.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final shouldSignOut = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space8),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: AppTheme.errorRed,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space12),
                    Text(
                      'Sign Out',
                      style: AppTheme.headlineMedium,
                    ),
                  ],
                ),
                content: Text(
                  'Are you sure you want to sign out?',
                  style: AppTheme.bodyLarge,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTheme.labelLarge,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                    child: Text(
                      'Sign Out',
                      style: AppTheme.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );

            if (shouldSignOut == true) {
              await _auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/');
            }
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.space12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(
                    Icons.logout,
                    color: AppTheme.errorRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sign Out',
                        style: AppTheme.titleMedium.copyWith(
                          color: AppTheme.errorRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        'Sign out of your account',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.errorRed,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}