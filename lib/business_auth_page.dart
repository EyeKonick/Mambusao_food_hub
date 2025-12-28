// lib/business_auth_page.dart
// ====================================================================
// ENHANCED BUSINESS AUTH PAGE
// UI Enhancement Phase - Modern, Clean Design with Poppins Font
// 
// ENHANCEMENTS:
// - Modern gradient header with logo
// - Enhanced card-based form layout
// - Better section headers with icons
// - Improved location capture section
// - Modern logo upload design
// - Enhanced text fields and buttons
// - Better error states and loading indicators
// 
// BUSINESS LOGIC: 100% PRESERVED - NO CHANGES
// ====================================================================

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'map_location_picker_page.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'business_dashboard.dart';

/// Business Owner Authentication Page
/// 
/// BUSINESS LOGIC PRESERVED:
/// - Firebase authentication (login/signup)
/// - One account = One business
/// - Logo upload to Cloudinary
/// - GPS location capture
/// - Map location picker
/// - Form validation
/// - Social media links

class BusinessAuthPage extends StatefulWidget {
  const BusinessAuthPage({super.key});

  @override
  BusinessAuthPageState createState() => BusinessAuthPageState();
}

class BusinessAuthPageState extends State<BusinessAuthPage> {
  // ==================== FIREBASE INSTANCES ====================
  // NO CHANGES - Business logic preserved
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // ==================== TEXT CONTROLLERS ====================
  // NO CHANGES - All controllers preserved
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _restaurantNameController = TextEditingController();
  final TextEditingController _restaurantAddressController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();

  // ==================== STATE VARIABLES ====================
  // NO CHANGES - All state preserved
  bool _isLogin = true;
  bool _isLoading = false;
  String _errorMessage = '';
  String? _passwordStrengthMessage;
  String? _businessType;
  Position? _businessLocation;
  bool _isGettingLocation = false;
  String? _locationError;
  File? _selectedLogo;
  bool _isUploadingLogo = false;
  String? _uploadedLogoUrl;
  Map<String, dynamic>? _selectedMapLocation;
  bool _locationSelectedFromMap = false;

  static const List<String> _businessCategories = [
    'Tea & Coffee Shop',
    'Bakery',
    'Carinderia',
    'Pizzeria',
    'Casual Dining',
    'Fast Food',
    'Noodle & Soup Spot',
    'Food Stall',
  ];

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswordStrength);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePasswordStrength);
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _restaurantNameController.dispose();
    _restaurantAddressController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  // ==================== PASSWORD VALIDATION ====================
  // NO CHANGES - Logic preserved
  void _validatePasswordStrength() {
    if (_isLogin) return;
    
    final password = _passwordController.text;
    
    setState(() {
      if (password.isEmpty) {
        _passwordStrengthMessage = null;
      } else if (password.length < 6) {
        _passwordStrengthMessage = 'Password is too short (minimum 6 characters)';
      } else if (password.length < 8) {
        _passwordStrengthMessage = 'Password is acceptable (8+ characters recommended)';
      } else {
        _passwordStrengthMessage = 'Password is strong';
      }
    });
  }

  // ==================== LOGO UPLOAD ====================
  // NO CHANGES - Complete logic preserved
  Future<void> _pickLogoImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedLogo = File(pickedFile.path);
          _uploadedLogoUrl = null;
        });

        if (AppConfig.enableDebugMode) {
          debugPrint('✓ Logo selected: ${pickedFile.path}');
        }
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error picking logo: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    }
  }

  Future<String?> _uploadLogoToCloudinary(File imageFile) async {
    setState(() {
      _isUploadingLogo = true;
    });

    try {
      final fileSize = await imageFile.length();
      
      if (AppConfig.enableDebugMode) {
        debugPrint('📤 Uploading logo to Cloudinary...');
        debugPrint('File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
      }
      
      if (!AppConfig.isValidImageSize(fileSize)) {
        throw Exception(
          'Image too large. Max size: ${AppConfig.maxImageSizeBytes ~/ (1024 * 1024)}MB'
        );
      }

      final url = Uri.parse(AppConfig.cloudinaryApiUrl);
      var request = http.MultipartRequest('POST', url);

      request.fields['upload_preset'] = AppConfig.cloudinaryUploadPreset;
      request.fields['folder'] = AppConfig.cloudinaryEstablishmentLogoFolder;

      final multipartFile = await http.MultipartFile.fromPath('file', imageFile.path);
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final imageUrl = responseData['secure_url'] as String;
        
        setState(() {
          _uploadedLogoUrl = imageUrl;
          _isUploadingLogo = false;
        });

        if (AppConfig.enableDebugMode) {
          debugPrint('✓ Logo uploaded: $imageUrl');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text('Logo uploaded successfully!'),
                ],
              ),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
          );
        }
        
        return imageUrl;
      } else {
        throw Exception('Upload failed with status ${response.statusCode}');
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Upload error: $e');
      }

      setState(() {
        _isUploadingLogo = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload logo: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }

      return null;
    }
  }

  // ==================== LOCATION CAPTURE ====================
  // NO CHANGES - Complete logic preserved
  Future<void> _captureLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _businessLocation = position;
        _locationSelectedFromMap = false;
        _selectedMapLocation = null;
        _isGettingLocation = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✓ Location captured: ${position.latitude}, ${position.longitude}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('Location captured successfully!'),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _locationError = e.toString();
        _isGettingLocation = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Location error: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _chooseLocationOnMap() async {
    try {
      LatLng? initialLocation;
      
      if (_selectedMapLocation != null) {
        initialLocation = LatLng(
          _selectedMapLocation!['latitude'],
          _selectedMapLocation!['longitude'],
        );
      } else if (_businessLocation != null) {
        initialLocation = LatLng(
          _businessLocation!.latitude,
          _businessLocation!.longitude,
        );
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapLocationPickerPage(
            initialLocation: initialLocation,
          ),
        ),
      );

      if (result != null && result is Map<String, dynamic>) {
        setState(() {
          _selectedMapLocation = result;
          _locationSelectedFromMap = true;
          
          _businessLocation = Position(
            latitude: result['latitude'],
            longitude: result['longitude'],
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
          _locationError = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Location selected: ${result['address'] ?? "Mambusao, Capiz"}'),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening map: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    }
  }

  // ==================== AUTHENTICATION LOGIC ====================
  // NO CHANGES - Complete logic preserved
  Future<void> _handleAuth() async {
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      if (_isLogin) {
        await _performLogin();
      } else {
        await _performSignUp();
      }

      if (!mounted) return;
      
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BusinessDashboardPage()),
      );
      
      if (mounted) {
        Navigator.of(context).pop();
      }
      
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFriendlyErrorMessage(e.code);
      });
    } on FirebaseException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'A database error occurred.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performLogin() async {
    await _auth.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  Future<void> _performSignUp() async {
    String? logoUrl;
    if (_selectedLogo != null && _uploadedLogoUrl == null) {
      logoUrl = await _uploadLogoToCloudinary(_selectedLogo!);
      if (logoUrl == null) {
        throw Exception('Failed to upload logo. Please try again.');
      }
    } else {
      logoUrl = _uploadedLogoUrl;
    }

    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    await userCredential.user!.updateDisplayName(_fullNameController.text.trim());

    await _firestore
        .collection(AppConfig.businessesCollection)
        .doc(userCredential.user!.uid)
        .set({
      'ownerName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phoneNumber': _phoneNumberController.text.trim(),
      'businessName': _restaurantNameController.text.trim(),
      'businessAddress': _restaurantAddressController.text.trim(),
      'businessType': _businessType,
      'logoUrl': logoUrl,
      'coverImageUrl': null,
      'latitude': _businessLocation?.latitude,
      'longitude': _businessLocation?.longitude,
      'hasLocation': _businessLocation != null,
      'facebookUrl': _facebookController.text.trim().isNotEmpty
          ? _facebookController.text.trim()
          : null,
      'instagramUrl': _instagramController.text.trim().isNotEmpty
          ? _instagramController.text.trim()
          : null,
      'websiteUrl': _websiteController.text.trim().isNotEmpty
          ? _websiteController.text.trim()
          : null,
      'approvalStatus': AppConfig.requireBusinessApproval ? 'pending' : 'approved',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _getFriendlyErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  // ==================== BUILD METHOD (ENHANCED UI) ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppTheme.space24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildModernHeader(),
                  SizedBox(height: AppTheme.space32),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                      boxShadow: AppTheme.shadowCard,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.space24),
                      child: Column(
                        children: [
                          if (_errorMessage.isNotEmpty) ...[
                            _buildErrorMessage(),
                            SizedBox(height: AppTheme.space16),
                          ],

                          if (!_isLogin) ...[
                            _buildLogoUploadSection(),
                            SizedBox(height: AppTheme.space24),
                            _buildSignUpFields(),
                          ] else ...[
                            _buildLoginFields(),
                          ],

                          SizedBox(height: AppTheme.space24),
                          _buildSubmitButton(),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: AppTheme.space24),
                  _buildToggleButton(),
                  
                  if (_isLogin) ...[
                    SizedBox(height: AppTheme.space12),
                    _buildBackToBrowseButton(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== UI COMPONENTS (ENHANCED) ====================

  Widget _buildModernHeader() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(AppTheme.space20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryGreen, AppTheme.secondaryGreen],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.restaurant_menu,
            size: 48,
            color: Colors.white,
          ),
        ),
        SizedBox(height: AppTheme.space24),
        
        Text(
          _isLogin ? 'Welcome Back!' : 'Join MamFood Hub',
          style: AppTheme.displayMedium.copyWith(
            color: AppTheme.primaryGreen,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppTheme.space8),
        
        Text(
          _isLogin 
              ? 'Sign in to manage your business' 
              : 'Register your restaurant today',
          style: AppTheme.bodyLarge.copyWith(
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.errorRed.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: AppTheme.errorRed,
            size: 24,
          ),
          SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(
              _errorMessage,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.errorRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoUploadSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _isUploadingLogo ? null : _pickLogoImage,
          child: Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.lightGreen,
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    width: 3,
                  ),
                  boxShadow: AppTheme.shadowCard,
                  image: _selectedLogo != null
                      ? DecorationImage(
                          image: FileImage(_selectedLogo!),
                          fit: BoxFit.cover,
                        )
                      : _uploadedLogoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_uploadedLogoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                ),
                child: (_selectedLogo == null && _uploadedLogoUrl == null)
                    ? Icon(
                        Icons.restaurant,
                        size: 48,
                        color: AppTheme.primaryGreen,
                      )
                    : null,
              ),
              if (_isUploadingLogo)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.6),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(AppTheme.space8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.shadowButton,
                  ),
                  child: Icon(
                    _selectedLogo != null || _uploadedLogoUrl != null
                        ? Icons.edit
                        : Icons.add_photo_alternate,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppTheme.space16),
        Text(
          _uploadedLogoUrl != null
              ? '✓ Logo Uploaded'
              : _selectedLogo != null
                  ? 'Tap to upload'
                  : 'Tap to add logo',
          style: AppTheme.titleMedium.copyWith(
            color: _uploadedLogoUrl != null
                ? AppTheme.successGreen
                : AppTheme.textPrimary,
            fontWeight: _uploadedLogoUrl != null
                ? FontWeight.bold
                : FontWeight.w600,
          ),
        ),
        if (_selectedLogo != null && _uploadedLogoUrl == null) ...[
          SizedBox(height: AppTheme.space12),
          ElevatedButton.icon(
            onPressed: _isUploadingLogo
                ? null
                : () async {
                    await _uploadLogoToCloudinary(_selectedLogo!);
                  },
            icon: _isUploadingLogo
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.cloud_upload, size: 20),
            label: Text(_isUploadingLogo ? 'Uploading...' : 'Upload Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryGreen,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.space24,
                vertical: AppTheme.space12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
          ),
        ],
        SizedBox(height: AppTheme.space8),
        Text(
          'Optional: Add logo now or later from dashboard',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textHint,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSignUpFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Account Information', Icons.person_outline),
        SizedBox(height: AppTheme.space16),

        _buildTextField(
          controller: _fullNameController,
          label: 'Full Name',
          hint: 'Juan Dela Cruz',
          icon: Icons.person,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your full name';
            }
            return null;
          },
        ),
        SizedBox(height: AppTheme.space16),

        _buildTextField(
          controller: _emailController,
          label: 'Business Email',
          hint: 'business@example.com',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email';
            }
            final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
            if (!emailRegex.hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        SizedBox(height: AppTheme.space16),

        _buildTextField(
          controller: _phoneNumberController,
          label: 'Phone Number',
          hint: '09XX XXX XXXX',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your phone number';
            }
            return null;
          },
        ),
        SizedBox(height: AppTheme.space16),

        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Minimum 6 characters',
          icon: Icons.lock,
          isPassword: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),

        if (_passwordStrengthMessage != null)
          Padding(
            padding: EdgeInsets.only(top: AppTheme.space8, left: AppTheme.space12),
            child: Row(
              children: [
                Icon(
                  _passwordStrengthMessage == 'Password is strong'
                      ? Icons.check_circle
                      : Icons.info_outline,
                  size: 16,
                  color: _passwordStrengthMessage == 'Password is strong'
                      ? AppTheme.successGreen
                      : AppTheme.accentYellow,
                ),
                SizedBox(width: AppTheme.space4),
                Text(
                  _passwordStrengthMessage!,
                  style: AppTheme.bodySmall.copyWith(
                    color: _passwordStrengthMessage == 'Password is strong'
                        ? AppTheme.successGreen
                        : AppTheme.accentYellow,
                  ),
                ),
              ],
            ),
          ),

        SizedBox(height: AppTheme.space16),

        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          hint: 'Re-enter password',
          icon: Icons.lock_outline,
          isPassword: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),

        SizedBox(height: AppTheme.space32),
        const Divider(),
        SizedBox(height: AppTheme.space24),

        _buildSectionHeader('Business Details', Icons.restaurant),
        SizedBox(height: AppTheme.space16),

        _buildTextField(
          controller: _restaurantNameController,
          label: 'Business/Restaurant Name',
          hint: 'e.g., Juan\'s Eatery',
          icon: Icons.storefront,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your business name';
            }
            return null;
          },
        ),
        SizedBox(height: AppTheme.space16),

        _buildTextField(
          controller: _restaurantAddressController,
          label: 'Business Address',
          hint: 'Street, Barangay, Mambusao',
          icon: Icons.location_on,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your business address';
            }
            return null;
          },
        ),
        SizedBox(height: AppTheme.space16),

        _buildBusinessTypeDropdown(),
        SizedBox(height: AppTheme.space24),

        _buildLocationCaptureSection(),

        SizedBox(height: AppTheme.space24),
        const Divider(),
        SizedBox(height: AppTheme.space24),

        _buildSectionHeader('Social Media (Optional)', Icons.share),
        SizedBox(height: AppTheme.space8),
        Text(
          'Add your social media links to help customers find you',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
        SizedBox(height: AppTheme.space16),

        _buildTextField(
          controller: _facebookController,
          label: 'Facebook Page',
          hint: 'https://facebook.com/yourpage',
          icon: Icons.facebook,
          keyboardType: TextInputType.url,
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!value.startsWith('http://') && !value.startsWith('https://')) {
                return 'URL must start with http:// or https://';
              }
            }
            return null;
          },
        ),
        SizedBox(height: AppTheme.space16),

        _buildTextField(
          controller: _instagramController,
          label: 'Instagram Profile',
          hint: 'https://instagram.com/yourprofile',
          icon: Icons.camera_alt,
          keyboardType: TextInputType.url,
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!value.startsWith('http://') && !value.startsWith('https://')) {
                return 'URL must start with http:// or https://';
              }
            }
            return null;
          },
        ),
        SizedBox(height: AppTheme.space16),

        _buildTextField(
          controller: _websiteController,
          label: 'Website',
          hint: 'https://yourwebsite.com',
          icon: Icons.language,
          keyboardType: TextInputType.url,
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!value.startsWith('http://') && !value.startsWith('https://')) {
                return 'URL must start with http:// or https://';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildLoginFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'your@email.com',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email';
            }
            return null;
          },
        ),
        SizedBox(height: AppTheme.space16),

        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter password',
          icon: Icons.lock,
          isPassword: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(AppTheme.space8),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryGreen,
            size: 20,
          ),
        ),
        SizedBox(width: AppTheme.space12),
        Text(
          title,
          style: AppTheme.titleLarge.copyWith(
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword,
      style: AppTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textSecondary,
        ),
        hintStyle: AppTheme.bodySmall.copyWith(
          color: AppTheme.textHint,
        ),
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen, size: 22),
        filled: true,
        fillColor: AppTheme.backgroundLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: AppTheme.borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: AppTheme.errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: AppTheme.errorRed, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space16,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildBusinessTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _businessType,
      style: AppTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: 'Business Type',
        hintText: 'Select category',
        labelStyle: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textSecondary,
        ),
        prefixIcon: Icon(Icons.category, color: AppTheme.primaryGreen),
        filled: true,
        fillColor: AppTheme.backgroundLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: AppTheme.borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: AppTheme.errorRed, width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space16,
        ),
      ),
      items: _businessCategories.map((String category) {
        return DropdownMenuItem<String>(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _businessType = newValue;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Please select your business type';
        }
        return null;
      },
    );
  }

  Widget _buildLocationCaptureSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppTheme.borderLight,
          width: 1,
        ),
        boxShadow: AppTheme.shadowCardLight,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppTheme.space8),
                  decoration: BoxDecoration(
                    color: _businessLocation != null
                        ? AppTheme.successGreen.withOpacity(0.1)
                        : AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    _businessLocation != null ? Icons.location_on : Icons.location_off,
                    color: _businessLocation != null
                        ? AppTheme.successGreen
                        : AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Business Location',
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: AppTheme.space4),
                      Text(
                        'Optional: Show distance to customers',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.space16),

            if (_locationSelectedFromMap && _selectedMapLocation != null)
              Container(
                padding: EdgeInsets.all(AppTheme.space12),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.successGreen,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.successGreen,
                          size: 20,
                        ),
                        SizedBox(width: AppTheme.space8),
                        Text(
                          'Location Selected',
                          style: AppTheme.titleSmall.copyWith(
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.space8),
                    Text(
                      _selectedMapLocation!['address'] ?? 'Mambusao, Capiz',
                      style: AppTheme.bodyMedium,
                    ),
                    SizedBox(height: AppTheme.space4),
                    Text(
                      'Lat: ${_businessLocation!.latitude.toStringAsFixed(6)}, Long: ${_businessLocation!.longitude.toStringAsFixed(6)}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else if (_businessLocation != null)
              Container(
                padding: EdgeInsets.all(AppTheme.space12),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successGreen,
                      size: 20,
                    ),
                    SizedBox(width: AppTheme.space8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location Captured via GPS',
                            style: AppTheme.titleSmall.copyWith(
                              color: AppTheme.successGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: AppTheme.space4),
                          Text(
                            'Lat: ${_businessLocation!.latitude.toStringAsFixed(6)}, Long: ${_businessLocation!.longitude.toStringAsFixed(6)}',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(AppTheme.space12),
                decoration: BoxDecoration(
                  color: AppTheme.accentYellow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.accentYellow,
                      size: 20,
                    ),
                    SizedBox(width: AppTheme.space8),
                    Expanded(
                      child: Text(
                        'Please select your business location',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: AppTheme.space16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isGettingLocation ? null : _captureLocation,
                    icon: _isGettingLocation
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryGreen,
                            ),
                          )
                        : const Icon(Icons.my_location, size: 20),
                    label: Text(_isGettingLocation ? 'Getting...' : 'Use GPS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                      side: BorderSide(color: AppTheme.primaryGreen, width: 1.5),
                      padding: EdgeInsets.symmetric(vertical: AppTheme.space12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppTheme.space12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _chooseLocationOnMap,
                    icon: const Icon(Icons.map, size: 20),
                    label: Text(
                      _locationSelectedFromMap ? 'Change' : 'Choose on Map',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: AppTheme.space12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.secondaryGreen],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleAuth,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                _isLogin ? 'Sign In' : 'Create Account',
                style: AppTheme.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildToggleButton() {
    return Center(
      child: TextButton(
        onPressed: _isLoading
            ? null
            : () {
                setState(() {
                  _isLogin = !_isLogin;
                  _errorMessage = '';
                  _passwordStrengthMessage = null;
                  _formKey.currentState?.reset();
                  _emailController.clear();
                  _passwordController.clear();
                  _fullNameController.clear();
                  _phoneNumberController.clear();
                  _confirmPasswordController.clear();
                  _restaurantNameController.clear();
                  _restaurantAddressController.clear();
                  _facebookController.clear();
                  _instagramController.clear();
                  _websiteController.clear();
                  _businessType = null;
                  _businessLocation = null;
                  _locationError = null;
                  _selectedLogo = null;
                  _uploadedLogoUrl = null;
                  _selectedMapLocation = null;
                  _locationSelectedFromMap = false;
                });
              },
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.space16,
            vertical: AppTheme.space12,
          ),
        ),
        child: RichText(
          text: TextSpan(
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            children: [
              TextSpan(
                text: _isLogin 
                    ? 'Don\'t have an account? ' 
                    : 'Already have an account? ',
              ),
              TextSpan(
                text: _isLogin ? 'Sign Up' : 'Sign In',
                style: AppTheme.labelLarge.copyWith(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackToBrowseButton() {
    return Center(
      child: TextButton.icon(
        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        icon: Icon(
          Icons.arrow_back,
          size: 18,
          color: AppTheme.textSecondary,
        ),
        label: Text(
          'Back to Browse',
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
