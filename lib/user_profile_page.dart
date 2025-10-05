import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'user_auth_page.dart';
import 'bookmarks_page.dart';

/// User profile page for viewing and editing user information
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  // ==================== FIREBASE INSTANCES ====================
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // ==================== FORM CONTROLLERS ====================
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // ==================== STATE VARIABLES ====================
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  
  String? _userEmail;
  String? _photoUrl;
  DateTime? _createdAt;

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ==================== CHECK AUTH FIRST ====================
  Future<void> _checkAuthAndLoadData() async {
    final user = _auth.currentUser;
    
    // CRITICAL: Check authentication BEFORE any Firestore operations
    if (user == null || user.isAnonymous) {
      if (AppConfig.enableDebugMode) {
        debugPrint('User not authenticated - redirecting to login');
      }
      
      // Redirect to auth page
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const UserAuthPage()),
            );
          }
        });
      }
      return; // CRITICAL: Stop execution here
    }

    // User is authenticated - now it's safe to load data
    await _loadUserData();
  }

  // ==================== DATA LOADING ====================
  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      setState(() => _isLoading = true);

      if (AppConfig.enableDebugMode) {
        debugPrint('Loading profile for user: ${user.uid}');
      }

      // Fetch user document
      final userDoc = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        // Create user document if it doesn't exist
        if (AppConfig.enableDebugMode) {
          debugPrint('User document not found, creating one...');
        }
        
        await _firestore
            .collection(AppConfig.usersCollection)
            .doc(user.uid)
            .set({
          'name': user.displayName ?? 'User',
          'email': user.email ?? '',
          'phoneNumber': '',
          'photoUrl': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });

        // Fetch again after creating
        final newUserDoc = await _firestore
            .collection(AppConfig.usersCollection)
            .doc(user.uid)
            .get();
            
        final data = newUserDoc.data() as Map<String, dynamic>;
        
        setState(() {
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _userEmail = data['email'] ?? user.email;
          _photoUrl = data['photoUrl'];
          _createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          _isLoading = false;
        });
        
        if (AppConfig.enableDebugMode) {
          debugPrint('User document created and profile loaded');
        }
        return;
      }

      // Document exists - load data
      final data = userDoc.data() as Map<String, dynamic>;

      setState(() {
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phoneNumber'] ?? '';
        _userEmail = data['email'] ?? user.email;
        _photoUrl = data['photoUrl'];
        _createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        _isLoading = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('Profile loaded successfully');
      }

    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('Error loading profile: $e');
      }
      
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error Loading Profile'),
          content: Text('Failed to load your profile: ${e.toString()}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Go Back'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isLoading = true;
                });
                _loadUserData();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
  }

  // ==================== REAL-TIME STATS STREAMS ====================
  Stream<int> _getBookmarksCountStream() {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      return Stream.value(0);
    }

    return _firestore
        .collection(AppConfig.usersCollection)
        .doc(user.uid)
        .collection(AppConfig.bookmarksSubcollection)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _getReviewsCountStream() {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      return Stream.value(0);
    }

    return _firestore
        .collectionGroup(AppConfig.reviewsSubcollection)
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ==================== IMAGE UPLOAD ====================
  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      final File imageFile = File(image.path);
      final fileSize = await imageFile.length();

      if (!AppConfig.isValidImageSize(fileSize)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image too large. Max size is ${AppConfig.maxImageSizeBytes ~/ (1024 * 1024)}MB'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        return;
      }

      setState(() => _isUploadingImage = true);

      final url = Uri.parse(AppConfig.cloudinaryApiUrl);
      var request = http.MultipartRequest('POST', url);
      
      request.fields['upload_preset'] = AppConfig.cloudinaryUploadPreset;
      request.fields['folder'] = 'user_avatars';
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        final imageUrl = jsonResponse['secure_url'];

        await _firestore
            .collection(AppConfig.usersCollection)
            .doc(_auth.currentUser!.uid)
            .update({
          'photoUrl': imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _photoUrl = imageUrl;
          _isUploadingImage = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  // ==================== SAVE PROFILE ====================
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.uid)
          .update({
        'name': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await user.updateDisplayName(_nameController.text.trim());

      setState(() {
        _isEditing = false;
        _isSaving = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  // ==================== SIGN OUT ====================
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ==================== UI BUILD METHOD ====================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _isEditing = false);
                _loadUserData();
              },
              tooltip: 'Cancel',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildProfilePhoto(),
              const SizedBox(height: 24),
              
              // Stats cards with real-time counts
              Row(
                children: [
                  // Bookmarks stat (real-time)
                  Expanded(
                    child: StreamBuilder<int>(
                      stream: _getBookmarksCountStream(),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BookmarksPage(),
                              ),
                            );
                          },
                          child: _buildStatCard('Bookmarks', count, Icons.bookmark),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Reviews stat (real-time)
                  Expanded(
                    child: StreamBuilder<int>(
                      stream: _getReviewsCountStream(),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return _buildStatCard('Reviews', count, Icons.rate_review);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Profile Information Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile Information', style: AppTheme.titleMedium),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                        ),
                        enabled: _isEditing,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _userEmail,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_createdAt != null)
                        ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: const Text('Member Since'),
                          subtitle: Text(
                            '${_createdAt!.day}/${_createdAt!.month}/${_createdAt!.year}',
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      if (_isEditing) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Save Changes'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Sign Out Card
              Card(
                child: ListTile(
                  leading: Icon(Icons.logout, color: AppTheme.errorRed),
                  title: Text('Sign Out', style: TextStyle(color: AppTheme.errorRed)),
                  onTap: _signOut,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== UI COMPONENTS ====================
  Widget _buildProfilePhoto() {
    return Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
          backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
          child: _photoUrl == null
              ? Icon(Icons.person, size: 60, color: AppTheme.primaryGreen)
              : null,
        ),
        if (_isUploadingImage)
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black54,
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        Positioned(
          bottom: 0,
          right: 0,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primaryGreen,
            child: IconButton(
              icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
              onPressed: _isUploadingImage ? null : _pickAndUploadImage,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppTheme.primaryGreen),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: AppTheme.headingLarge.copyWith(color: AppTheme.primaryGreen),
            ),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}