// ====================================================================
// ENHANCED BUSINESS PROFILE EDITOR PAGE
// UI Enhancement Phase - Modern, Clean Design with Poppins Font
// 
// ENHANCEMENTS APPLIED:
// - Modern card-based layout with enhanced shadows
// - Improved section headers with icons and backgrounds
// - Enhanced image upload UI with better previews
// - Modern form fields with better visual hierarchy
// - Enhanced location card with better status indicators
// - Improved button designs with gradients
// - Better spacing and typography using Poppins
// 
// FUNCTIONALITY: 100% PRESERVED - NO CHANGES TO BUSINESS LOGIC
// ====================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'map_location_picker_page.dart';

class BusinessProfileEditorPage extends StatefulWidget {
  const BusinessProfileEditorPage({super.key});

  @override
  State<BusinessProfileEditorPage> createState() => _BusinessProfileEditorPageState();
}

class _BusinessProfileEditorPageState extends State<BusinessProfileEditorPage> {
  // ==================== STATE VARIABLES ====================
  // NO CHANGES - All state management preserved
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _websiteController = TextEditingController();

  String? _selectedBusinessType;
  String? _currentLogoUrl;
  File? _newLogoFile;
  String? _currentCoverImageUrl;
  File? _newCoverImageFile;
  double? _latitude;
  double? _longitude;
  bool _hasLocation = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _isCapturingLocation = false;

  Map<String, dynamic>? _selectedMapLocation;
  bool _locationSelectedFromMap = false;

  final List<String> _businessTypes = AppConfig.businessTypes;

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
    _addTextFieldListeners();
  }

  void _addTextFieldListeners() {
    _nameController.addListener(() => _hasUnsavedChanges = true);
    _addressController.addListener(() => _hasUnsavedChanges = true);
    _emailController.addListener(() => _hasUnsavedChanges = true);
    _phoneController.addListener(() => _hasUnsavedChanges = true);
    _descriptionController.addListener(() => _hasUnsavedChanges = true);
    _facebookController.addListener(() => _hasUnsavedChanges = true);
    _instagramController.addListener(() => _hasUnsavedChanges = true);
    _websiteController.addListener(() => _hasUnsavedChanges = true);
  }

  // ==================== DATA LOADING ====================
  // NO CHANGES - Business logic preserved
  Future<void> _loadBusinessData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection(AppConfig.businessesCollection)
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['businessName'] ?? '';
          _addressController.text = data['businessAddress'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _descriptionController.text = data['businessDescription'] ?? '';
          _facebookController.text = data['facebookUrl'] ?? '';
          _instagramController.text = data['instagramUrl'] ?? '';
          _websiteController.text = data['websiteUrl'] ?? '';
          _selectedBusinessType = data['businessType'];
          _currentLogoUrl = data['logoUrl'];
          _currentCoverImageUrl = data['coverImageUrl'];
          _latitude = data['latitude'];
          _longitude = data['longitude'];
          _hasLocation = data['hasLocation'] ?? false;
          _isLoading = false;
          _hasUnsavedChanges = false;
        });
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error loading business data: $e');
      }
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: AppTheme.space8),
                const Expanded(child: Text('Failed to load business data')),
              ],
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
  }

  // ==================== IMAGE PICKERS ====================
  // NO CHANGES - Logic preserved
  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();

        if (!AppConfig.isValidImageSize(fileSize)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text('Image must be less than 5MB')),
                  ],
                ),
                backgroundColor: AppTheme.warningOrange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            );
          }
          return;
        }

        setState(() {
          _newLogoFile = file;
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error picking logo: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to pick image')),
              ],
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
  }

  Future<void> _pickCoverImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();

        if (!AppConfig.isValidImageSize(fileSize)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text('Image must be less than 5MB')),
                  ],
                ),
                backgroundColor: AppTheme.warningOrange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            );
          }
          return;
        }

        setState(() {
          _newCoverImageFile = file;
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error picking cover image: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to pick image')),
              ],
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
  }

  // ==================== CLOUDINARY UPLOAD ====================
  // NO CHANGES - Complete logic preserved (MultipartRequest method)
  Future<String?> _uploadLogoToCloudinary(File imageFile) async {
    setState(() => _isSaving = true);

    try {
      final fileSize = await imageFile.length();
      
      if (AppConfig.enableDebugMode) {
        debugPrint('═══════════════════════════════════════════');
        debugPrint('📤 CLOUDINARY UPLOAD DEBUG');
        debugPrint('═══════════════════════════════════════════');
        debugPrint('File path: ${imageFile.path}');
        debugPrint('File size: $fileSize bytes (${(fileSize / 1024).toStringAsFixed(2)} KB)');
        debugPrint('Max allowed: ${AppConfig.maxImageSizeBytes} bytes');
        debugPrint('Size valid: ${AppConfig.isValidImageSize(fileSize)}');
      }
      
      if (!AppConfig.isValidImageSize(fileSize)) {
        throw Exception('Image too large. Max size: ${AppConfig.maxImageSizeBytes ~/ (1024 * 1024)}MB');
      }

      final url = Uri.parse(AppConfig.cloudinaryApiUrl);
      
      if (AppConfig.enableDebugMode) {
        debugPrint('═══════════════════════════════════════════');
        debugPrint('🔧 REQUEST CONFIGURATION');
        debugPrint('═══════════════════════════════════════════');
        debugPrint('API URL: ${AppConfig.cloudinaryApiUrl}');
        debugPrint('Cloud Name: ${AppConfig.cloudinaryCloudName}');
        debugPrint('Upload Preset: ${AppConfig.cloudinaryUploadPreset}');
        debugPrint('Folder: ${AppConfig.cloudinaryEstablishmentLogoFolder}');
      }
      
      var request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = AppConfig.cloudinaryUploadPreset;
      request.fields['folder'] = AppConfig.cloudinaryEstablishmentLogoFolder;

      if (AppConfig.enableDebugMode) {
        debugPrint('═══════════════════════════════════════════');
        debugPrint('📦 REQUEST FIELDS');
        debugPrint('═══════════════════════════════════════════');
        request.fields.forEach((key, value) {
          debugPrint('$key: $value');
        });
      }

      final multipartFile = await http.MultipartFile.fromPath('file', imageFile.path);
      request.files.add(multipartFile);
      
      if (AppConfig.enableDebugMode) {
        debugPrint('═══════════════════════════════════════════');
        debugPrint('🔎 FILE INFO');
        debugPrint('═══════════════════════════════════════════');
        debugPrint('Field name: file');
        debugPrint('Filename: ${multipartFile.filename}');
        debugPrint('Content type: ${multipartFile.contentType}');
        debugPrint('Length: ${multipartFile.length} bytes');
        debugPrint('═══════════════════════════════════════════');
        debugPrint('🚀 SENDING REQUEST...');
        debugPrint('═══════════════════════════════════════════');
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (AppConfig.enableDebugMode) {
        debugPrint('═══════════════════════════════════════════');
        debugPrint('📥 RESPONSE RECEIVED');
        debugPrint('═══════════════════════════════════════════');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Status: ${response.statusCode == 200 ? "✓ SUCCESS" : "✗ FAILED"}');
        debugPrint('Response Body:');
        debugPrint(response.body);
        debugPrint('═══════════════════════════════════════════');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final imageUrl = responseData['secure_url'] as String;
        
        setState(() => _isSaving = false);

        if (AppConfig.enableDebugMode) {
          debugPrint('✓ Logo URL: $imageUrl');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: AppTheme.space8),
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
        throw Exception('Upload failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      if (AppConfig.enableDebugMode) {
        debugPrint('═══════════════════════════════════════════');
        debugPrint('❌ ERROR OCCURRED');
        debugPrint('═══════════════════════════════════════════');
        debugPrint('Error: $e');
        debugPrint('Stack trace: $stackTrace');
        debugPrint('═══════════════════════════════════════════');
      }

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: AppTheme.space8),
                Expanded(child: Text('Failed to upload logo: $e')),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }

      return null;
    }
  }

  Future<String?> _uploadCoverImageToCloudinary(File imageFile) async {
    try {
      final fileSize = await imageFile.length();
      
      if (!AppConfig.isValidImageSize(fileSize)) {
        throw Exception('Image too large. Max size: 5MB');
      }

      final url = Uri.parse(AppConfig.cloudinaryApiUrl);
      var request = http.MultipartRequest('POST', url);

      request.fields['upload_preset'] = AppConfig.cloudinaryUploadPreset;
      request.fields['folder'] = AppConfig.cloudinaryCoverImageFolder;

      final multipartFile = await http.MultipartFile.fromPath('file', imageFile.path);
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final imageUrl = responseData['secure_url'] as String;

        if (AppConfig.enableDebugMode) {
          debugPrint('✓ Cover image URL: $imageUrl');
        }

        return imageUrl;
      } else {
        throw Exception('Upload failed with status ${response.statusCode}');
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error uploading cover image: $e');
      }
      return null;
    }
  }

  // ==================== LOCATION SERVICES ====================
  // NO CHANGES - Complete logic preserved
  Future<void> _updateLocation() async {
    try {
      setState(() => _isCapturingLocation = true);

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _hasLocation = true;
        _hasUnsavedChanges = true;
        _isCapturingLocation = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: AppTheme.space8),
                const Text('Location updated successfully'),
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
    } catch (e) {
      setState(() => _isCapturingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: AppTheme.space8),
                Expanded(child: Text('Failed to update location: $e')),
              ],
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
  }

  Future<void> _chooseLocationOnMap() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MapLocationPickerPage(),
        ),
      );

      if (result != null && result is Map<String, dynamic>) {
        setState(() {
          _selectedMapLocation = result;
          _locationSelectedFromMap = true;
          _hasUnsavedChanges = true;
          
          _latitude = result['latitude'] as double?;
          _longitude = result['longitude'] as double?;
          _hasLocation = result['hasLocation'] as bool? ?? true;

          if (AppConfig.enableDebugMode) {
            debugPrint('✓ Location updated from map:');
            debugPrint('  Latitude: $_latitude');
            debugPrint('  Longitude: $_longitude');
            debugPrint('  Address: ${result['address']}');
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text('Location updated: ${result['address'] ?? "Mambusao, Capiz"}'),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successGreen,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error opening map picker: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: AppTheme.space8),
                Expanded(child: Text('Error opening map: $e')),
              ],
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
  }

  // ==================== SAVE CHANGES ====================
  // NO CHANGES - Complete logic preserved (email excluded from update)
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text('Save Changes', style: AppTheme.headlineMedium),
        content: Text(
          'Are you sure you want to save these changes?',
          style: AppTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTheme.labelLarge.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.space24,
                vertical: AppTheme.space12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: Text('Save', style: AppTheme.labelLarge.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      String logoUrl = _currentLogoUrl ?? '';

      if (_newLogoFile != null) {
        final uploadedUrl = await _uploadLogoToCloudinary(_newLogoFile!);
        if (uploadedUrl != null) {
          logoUrl = uploadedUrl;
        } else {
          throw Exception('Failed to upload logo');
        }
      }

      String? coverImageUrl = _currentCoverImageUrl;
      if (_newCoverImageFile != null) {
        final uploadedCoverUrl = await _uploadCoverImageToCloudinary(_newCoverImageFile!);
        if (uploadedCoverUrl != null) {
          coverImageUrl = uploadedCoverUrl;
        }
      }

      double? saveLatitude = _latitude;
      double? saveLongitude = _longitude;
      bool saveHasLocation = _hasLocation;

      if (_selectedMapLocation != null) {
        saveLatitude = _selectedMapLocation!['latitude'];
        saveLongitude = _selectedMapLocation!['longitude'];
        saveHasLocation = _selectedMapLocation!['hasLocation'] ?? true;

        if (AppConfig.enableDebugMode) {
          debugPrint('✓ Saving map-selected location:');
          debugPrint('  Lat: $saveLatitude, Long: $saveLongitude');
        }
      }

      final updateData = {
        'businessName': _nameController.text.trim(),
        'businessAddress': _addressController.text.trim(),
        'businessType': _selectedBusinessType,
        'phoneNumber': _phoneController.text.trim(),
        'businessDescription': _descriptionController.text.trim(),
        'logoUrl': logoUrl,
        'coverImageUrl': coverImageUrl,
        'latitude': saveLatitude,
        'longitude': saveLongitude,
        'hasLocation': saveHasLocation,
        'facebookUrl': _facebookController.text.trim().isEmpty 
            ? null 
            : _facebookController.text.trim(),
        'instagramUrl': _instagramController.text.trim().isEmpty 
            ? null 
            : _instagramController.text.trim(),
        'websiteUrl': _websiteController.text.trim().isEmpty 
            ? null 
            : _websiteController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection(AppConfig.businessesCollection)
          .doc(user.uid)
          .update(updateData);

      setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false;
        _currentLogoUrl = logoUrl;
        _newLogoFile = null;
        _currentCoverImageUrl = coverImageUrl;
        _newCoverImageFile = null;
        _selectedMapLocation = null;
        _locationSelectedFromMap = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: AppTheme.space8),
                const Text('Profile updated successfully!'),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error saving profile: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: AppTheme.space8),
                Expanded(child: Text('Failed to save changes: $e')),
              ],
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
  }

  // ==================== UNSAVED CHANGES WARNING ====================
  // NO CHANGES
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text('Unsaved Changes', style: AppTheme.headlineMedium),
        content: Text(
          'You have unsaved changes. Do you want to discard them?',
          style: AppTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTheme.labelLarge.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.space24,
                vertical: AppTheme.space12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: Text('Discard', style: AppTheme.labelLarge.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // ==================== BUILD METHOD (ENHANCED UI) ====================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (!didPop && _hasUnsavedChanges) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          title: Text(
            'Edit Business Profile',
            style: AppTheme.titleLarge.copyWith(color: Colors.white),
          ),
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                        strokeWidth: 4,
                      ),
                    ),
                    SizedBox(height: AppTheme.space24),
                    Text(
                      'Loading profile...',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.all(AppTheme.space16),
                  children: [
                    // Logo Section (Enhanced)
                    _buildLogoSection(),
                    SizedBox(height: AppTheme.space24),

                    // Cover Image Section (Enhanced)
                    _buildCoverImageSection(),
                    SizedBox(height: AppTheme.space24),

                    // Basic Information Section (Enhanced)
                    _buildSectionHeader('Basic Information', Icons.business),
                    SizedBox(height: AppTheme.space12),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Business Name',
                      icon: Icons.store,
                      validator: (val) => val?.isEmpty ?? true 
                          ? 'Business name is required' 
                          : null,
                    ),
                    SizedBox(height: AppTheme.space16),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Business Address',
                      icon: Icons.location_on,
                      validator: (val) => val?.isEmpty ?? true 
                          ? 'Address is required' 
                          : null,
                    ),
                    SizedBox(height: AppTheme.space16),
                    _buildBusinessTypeDropdown(),
                    SizedBox(height: AppTheme.space16),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Business Description',
                      icon: Icons.description,
                      maxLines: 4,
                      maxLength: 500,
                    ),
                    SizedBox(height: AppTheme.space24),

                    // Contact Information Section (Enhanced)
                    _buildSectionHeader('Contact Information', Icons.contact_phone),
                    SizedBox(height: AppTheme.space12),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      enabled: false,
                      validator: null,
                    ),
                    SizedBox(height: AppTheme.space16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (val) => val?.isEmpty ?? true 
                          ? 'Phone number is required' 
                          : null,
                    ),
                    SizedBox(height: AppTheme.space24),

                    // Location Section (Enhanced)
                    _buildSectionHeader('Location', Icons.my_location),
                    SizedBox(height: AppTheme.space12),
                    _buildLocationCard(),
                    SizedBox(height: AppTheme.space24),

                    // Social Media Section (Enhanced)
                    _buildSectionHeader('Social Media (Optional)', Icons.share),
                    SizedBox(height: AppTheme.space12),
                    _buildTextField(
                      controller: _facebookController,
                      label: 'Facebook URL',
                      icon: Icons.facebook,
                      keyboardType: TextInputType.url,
                    ),
                    SizedBox(height: AppTheme.space16),
                    _buildTextField(
                      controller: _instagramController,
                      label: 'Instagram URL',
                      icon: Icons.camera_alt,
                      keyboardType: TextInputType.url,
                    ),
                    SizedBox(height: AppTheme.space16),
                    _buildTextField(
                      controller: _websiteController,
                      label: 'Website URL',
                      icon: Icons.language,
                      keyboardType: TextInputType.url,
                    ),
                    SizedBox(height: AppTheme.space32),

                    // Save Button (Enhanced)
                    _buildSaveButton(),
                    SizedBox(height: AppTheme.space16),
                  ],
                ),
              ),
      ),
    );
  }

  // ==================== UI COMPONENTS (ENHANCED) ====================

  /// Enhanced logo section with modern card design
  Widget _buildLogoSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.space20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppTheme.space8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(
                    Icons.account_circle,
                    color: AppTheme.primaryGreen,
                    size: 24,
                  ),
                ),
                SizedBox(width: AppTheme.space12),
                Text(
                  'Business Logo',
                  style: AppTheme.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.space16),
            GestureDetector(
              onTap: _pickLogo,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(
                    color: AppTheme.primaryGreen,
                    width: 2,
                  ),
                  boxShadow: AppTheme.shadowCardLight,
                ),
                child: _newLogoFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge - 2),
                        child: Image.file(
                          _newLogoFile!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : _currentLogoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge - 2),
                            child: Image.network(
                              _currentLogoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.broken_image,
                                  size: 56,
                                  color: AppTheme.textHint,
                                );
                              },
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate,
                                size: 56,
                                color: AppTheme.primaryGreen,
                              ),
                              SizedBox(height: AppTheme.space8),
                              Text(
                                'Tap to add logo',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
              ),
            ),
            SizedBox(height: AppTheme.space16),
            OutlinedButton.icon(
              onPressed: _pickLogo,
              icon: Icon(
                _currentLogoUrl == null ? Icons.add_photo_alternate : Icons.edit,
                size: 20,
              ),
              label: Text(_currentLogoUrl == null ? 'Add Logo' : 'Change Logo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryGreen,
                side: const BorderSide(color: AppTheme.primaryGreen, width: 2),
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
        ),
      ),
    );
  }

  /// Enhanced cover image section
  Widget _buildCoverImageSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppTheme.space8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(
                    Icons.image,
                    color: AppTheme.primaryGreen,
                    size: 24,
                  ),
                ),
                SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cover Image',
                        style: AppTheme.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: AppTheme.space4),
                      Text(
                        'Add a banner to showcase your business',
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
            
            // Cover Image Preview
            GestureDetector(
              onTap: _pickCoverImage,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(
                    color: AppTheme.primaryGreen,
                    width: 2,
                  ),
                  boxShadow: AppTheme.shadowCardLight,
                ),
                child: _newCoverImageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge - 2),
                        child: Image.file(
                          _newCoverImageFile!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : _currentCoverImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge - 2),
                            child: Image.network(
                              _currentCoverImageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.broken_image,
                                      size: 56,
                                      color: AppTheme.textHint,
                                    ),
                                    SizedBox(height: AppTheme.space8),
                                    Text(
                                      'Failed to load image',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_photo_alternate,
                                  size: 56,
                                  color: AppTheme.primaryGreen,
                                ),
                                SizedBox(height: AppTheme.space12),
                                Text(
                                  'Tap to add cover image',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: AppTheme.space4),
                                Text(
                                  'Recommended: 1920x1080px',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
            SizedBox(height: AppTheme.space16),
            
            // Action Buttons
            Row(
              children: [
                if (_currentCoverImageUrl != null || _newCoverImageFile != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _newCoverImageFile = null;
                          _currentCoverImageUrl = null;
                          _hasUnsavedChanges = true;
                        });
                      },
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: const BorderSide(color: AppTheme.errorRed, width: 2),
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.space16,
                          vertical: AppTheme.space12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                      ),
                    ),
                  ),
                if (_currentCoverImageUrl != null || _newCoverImageFile != null)
                  SizedBox(width: AppTheme.space12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickCoverImage,
                    icon: Icon(
                      _currentCoverImageUrl != null || _newCoverImageFile != null
                          ? Icons.edit
                          : Icons.add_photo_alternate,
                      size: 20,
                    ),
                    label: Text(
                      _currentCoverImageUrl != null || _newCoverImageFile != null
                          ? 'Change'
                          : 'Add Cover',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.space16,
                        vertical: AppTheme.space12,
                      ),
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

  /// Enhanced section header
  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen.withOpacity(0.1),
            AppTheme.secondaryGreen.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 24),
          SizedBox(width: AppTheme.space12),
          Text(
            title,
            style: AppTheme.titleLarge.copyWith(
              color: AppTheme.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Enhanced text field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: enabled ? AppTheme.shadowCardLight : [],
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTheme.bodyMedium.copyWith(
            color: enabled ? AppTheme.textSecondary : AppTheme.textHint,
          ),
          prefixIcon: Icon(
            icon,
            color: enabled ? AppTheme.primaryGreen : AppTheme.textHint,
          ),
          filled: true,
          fillColor: enabled ? Colors.white : AppTheme.backgroundLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: const BorderSide(color: AppTheme.borderLight, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: const BorderSide(color: AppTheme.errorRed, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: const BorderSide(color: AppTheme.errorRed, width: 2),
          ),
          counterText: maxLength != null ? null : '',
        ),
        style: AppTheme.bodyMedium,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
      ),
    );
  }

  /// Enhanced business type dropdown
  Widget _buildBusinessTypeDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.shadowCardLight,
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedBusinessType,
        decoration: InputDecoration(
          labelText: 'Business Type',
          labelStyle: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondary,
          ),
          prefixIcon: const Icon(
            Icons.category,
            color: AppTheme.primaryGreen,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: const BorderSide(color: AppTheme.borderLight, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
          ),
        ),
        style: AppTheme.bodyMedium,
        items: _businessTypes.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(type),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedBusinessType = value;
            _hasUnsavedChanges = true;
          });
        },
        validator: (val) => val == null ? 'Please select a business type' : null,
      ),
    );
  }

  /// Enhanced location card
  Widget _buildLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Display
            if (_locationSelectedFromMap && _selectedMapLocation != null)
              Container(
                padding: EdgeInsets.all(AppTheme.space16),
                margin: EdgeInsets.only(bottom: AppTheme.space16),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.successGreen,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppTheme.successGreen,
                          size: 24,
                        ),
                        SizedBox(width: AppTheme.space12),
                        Expanded(
                          child: Text(
                            'Location Updated',
                            style: AppTheme.titleMedium.copyWith(
                              color: AppTheme.successGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.space12),
                    Text(
                      _selectedMapLocation!['address'] ?? 'Mambusao, Capiz',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: AppTheme.space4),
                    Text(
                      'Lat: ${_latitude?.toStringAsFixed(6)}, Long: ${_longitude?.toStringAsFixed(6)}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
              )
            else if (_hasLocation && _latitude != null && _longitude != null)
              Container(
                padding: EdgeInsets.all(AppTheme.space16),
                margin: EdgeInsets.only(bottom: AppTheme.space16),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.successGreen,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.successGreen,
                      size: 24,
                    ),
                    SizedBox(width: AppTheme.space12),
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
                            'Lat: ${_latitude!.toStringAsFixed(6)}, Long: ${_longitude!.toStringAsFixed(6)}',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textHint,
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
                padding: EdgeInsets.all(AppTheme.space16),
                margin: EdgeInsets.only(bottom: AppTheme.space16),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.warningOrange,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.warningOrange,
                      size: 24,
                    ),
                    SizedBox(width: AppTheme.space12),
                    Expanded(
                      child: Text(
                        'No location set',
                        style: AppTheme.titleSmall.copyWith(
                          color: AppTheme.warningOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Action Buttons
            Row(
              children: [
                // GPS Capture Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isCapturingLocation ? null : _updateLocation,
                    icon: _isCapturingLocation
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryGreen.withOpacity(0.5),
                              ),
                            ),
                          )
                        : const Icon(Icons.my_location, size: 20),
                    label: Text(_isCapturingLocation ? 'Getting...' : 'Use GPS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                      side: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.space16,
                        vertical: AppTheme.space16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppTheme.space12),
                // Map Picker Button
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
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.space16,
                        vertical: AppTheme.space16,
                      ),
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

  /// Enhanced save button with gradient
  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen,
            AppTheme.secondaryGreen,
          ],
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
        onPressed: _isSaving ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: AppTheme.space16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save, size: 20),
                  SizedBox(width: AppTheme.space12),
                  Text(
                    'Save Changes',
                    style: AppTheme.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _websiteController.dispose();
    super.dispose();
  }
}
