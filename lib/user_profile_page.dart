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

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

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
          content: const Text('Profile updated successfully!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: AppTheme.errorRed,
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
          content: const Text('Profile photo updated!'),
          backgroundColor: AppTheme.successGreen,
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
          content: Text('Error uploading photo: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  // Bookmarks count stream (working correctly)
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

  // FIXED: Reviews count stream with comprehensive error handling
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
        })
        .map((snapshot) {
          final count = snapshot.docs.length;
          
          if (AppConfig.enableDebugMode) {
            debugPrint('✓ Reviews count loaded: $count');
            
            if (count > 0 && snapshot.docs.isNotEmpty) {
              final sampleReview = snapshot.docs.first.data() as Map<String, dynamic>;
              debugPrint('   Sample review:');
              debugPrint('     - Business: ${sampleReview['businessName'] ?? 'N/A'}');
              debugPrint('     - Comment: ${(sampleReview['comment'] ?? 'N/A').toString().substring(0, sampleReview['comment']?.toString().length ?? 30)}');
              debugPrint('     - Rating: ${sampleReview['rating']}');
              debugPrint('     - User ID: ${sampleReview['userId']}');
              debugPrint('     - Match: ${sampleReview['userId'] == user.uid ? '✓' : '✗'}');
            } else if (count == 0) {
              debugPrint('⚠️ No reviews found for this user');
              debugPrint('   Possible reasons:');
              debugPrint('   1. User hasn\'t written any reviews yet');
              debugPrint('   2. Field name mismatch (check if \'userId\' exists in review documents)');
              debugPrint('   3. Missing Firestore index (see error above)');
            }
            debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          }
          
          return count;
        });
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null || user.isAnonymous) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: AppTheme.textSecondary),
              const SizedBox(height: 16),
              Text('Please sign in to view profile', style: AppTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Profile',
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save Changes',
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileHeader(user),
            const SizedBox(height: 24),
            _buildStatsCards(),
            const SizedBox(height: 24),
            _buildProfileInfo(user),
            const SizedBox(height: 24),
            _buildSignOutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User user) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              children: [
                StreamBuilder<DocumentSnapshot>(
                  stream: _firestore
                      .collection(AppConfig.usersCollection)
                      .doc(user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final photoUrl = snapshot.data?.get('photoUrl') as String?;
                    
                    return CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.primaryGreen.withOpacity(0.2),
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null
                          ? Icon(Icons.person, size: 50, color: AppTheme.primaryGreen)
                          : null,
                    );
                  },
                ),
                if (!_isUploading)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primaryGreen,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 18),
                        color: Colors.white,
                        padding: EdgeInsets.zero,
                        onPressed: _uploadProfilePhoto,
                      ),
                    ),
                  ),
                if (_isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            if (_uploadProgress != null) ...[
              const SizedBox(height: 8),
              Text(
                _uploadProgress!,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              user.displayName ?? 'User',
              style: AppTheme.headingMedium,
            ),
            const SizedBox(height: 4),
            Text(
              user.email ?? '',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

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
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.bookmark, size: 32, color: AppTheme.primaryGreen),
                    const SizedBox(height: 8),
                    StreamBuilder<int>(
                      stream: _getBookmarksCountStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        
                        return Text(
                          '${snapshot.data ?? 0}',
                          style: AppTheme.headingMedium.copyWith(
                            color: AppTheme.primaryGreen,
                          ),
                        );
                      },
                    ),
                    Text('Bookmarks', style: AppTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        
        // Reviews Card
        Expanded(
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.rate_review, size: 32, color: AppTheme.accentYellow),
                  const SizedBox(height: 8),
                  StreamBuilder<int>(
                    stream: _getReviewsCountStream(),
                    builder: (context, snapshot) {
                      // Show loading indicator while fetching
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      
                      // Show error state (but display 0 to user)
                      if (snapshot.hasError) {
                        if (AppConfig.enableDebugMode) {
                          debugPrint('❌ StreamBuilder error: ${snapshot.error}');
                        }
                        return Text(
                          '0',
                          style: AppTheme.headingMedium.copyWith(
                            color: AppTheme.accentYellow,
                          ),
                        );
                      }
                      
                      // Show the actual count
                      final count = snapshot.data ?? 0;
                      return Text(
                        '$count',
                        style: AppTheme.headingMedium.copyWith(
                          color: AppTheme.accentYellow,
                        ),
                      );
                    },
                  ),
                  Text('Reviews', style: AppTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfo(User user) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile Information',
              style: AppTheme.titleMedium.copyWith(color: AppTheme.primaryGreen),
            ),
            const Divider(height: 24),
            
            // Name Field
            Text('Full Name', style: AppTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              enabled: _isEditing,
              decoration: InputDecoration(
                hintText: 'Enter your name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: !_isEditing,
                fillColor: _isEditing ? null : Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 16),
            
            // Email Field (Read-only)
            Text('Email Address', style: AppTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: user.email),
              enabled: false,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                suffixIcon: const Icon(Icons.lock_outline, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            
            // Phone Field
            Text('Phone Number', style: AppTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Enter your phone number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: !_isEditing,
                fillColor: _isEditing ? null : Colors.grey.shade100,
              ),
            ),
            
            if (_isEditing) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _isEditing = false);
                        _loadUserData();
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text('Save Changes'),
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

  Widget _buildSignOutButton() {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(Icons.logout, color: AppTheme.errorRed),
        title: Text(
          'Sign Out',
          style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.w600),
        ),
        trailing: Icon(Icons.chevron_right, color: AppTheme.errorRed),
        onTap: () async {
          final shouldSignOut = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sign Out'),
              content: const Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
                  child: const Text('Sign Out'),
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
      ),
    );
  }
}
