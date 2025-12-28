import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../config/app_theme.dart';
import 'map_location_picker_page.dart';

class BusinessProfileEditorPage extends StatefulWidget {
  const BusinessProfileEditorPage({super.key});

  @override
  State<BusinessProfileEditorPage> createState() => _BusinessProfileEditorPageState();
}

class _BusinessProfileEditorPageState extends State<BusinessProfileEditorPage> {
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
  String? _currentCoverImageUrl; // ← NEW
  File? _newCoverImageFile; // ← NEW
  double? _latitude;
  double? _longitude;
  bool _hasLocation = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _isCapturingLocation = false;

  // ==================== MAP LOCATION STATE VARIABLES ====================
  Map<String, dynamic>? _selectedMapLocation; // Stores selected location
  bool _locationSelectedFromMap = false; // Tracks if location was from map

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
          _currentCoverImageUrl = data['coverImageUrl']; // ← NEW: Load cover image
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
          const SnackBar(content: Text('Failed to load business data')),
        );
      }
    }
  }

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
              const SnackBar(content: Text('Image must be less than 5MB')),
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
          const SnackBar(content: Text('Failed to pick image')),
        );
      }
    }
  }

  /// Pick cover image from gallery
  Future<void> _pickCoverImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920, // Wider for banner
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();

        if (!AppConfig.isValidImageSize(fileSize)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image must be less than 5MB')),
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
          const SnackBar(content: Text('Failed to pick image')),
        );
      }
    }
  }

  Future<String?> _uploadLogoToCloudinary(File imageFile) async {
  setState(() {
    _isSaving = true;
  });

  try {
    // Validate file size
    final fileSize = await imageFile.length();
    
    if (AppConfig.enableDebugMode) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('📤 CLOUDINARY UPLOAD DEBUG');
      debugPrint('═══════════════════════════════════════');
      debugPrint('File path: ${imageFile.path}');
      debugPrint('File size: $fileSize bytes (${(fileSize / 1024).toStringAsFixed(2)} KB)');
      debugPrint('Max allowed: ${AppConfig.maxImageSizeBytes} bytes');
      debugPrint('Size valid: ${AppConfig.isValidImageSize(fileSize)}');
    }
    
    if (!AppConfig.isValidImageSize(fileSize)) {
      throw Exception(
        'Image too large. Max size: ${AppConfig.maxImageSizeBytes ~/ (1024 * 1024)}MB'
      );
    }

    // Prepare request
    final url = Uri.parse(AppConfig.cloudinaryApiUrl);
    
    if (AppConfig.enableDebugMode) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('🔧 REQUEST CONFIGURATION');
      debugPrint('═══════════════════════════════════════');
      debugPrint('API URL: ${AppConfig.cloudinaryApiUrl}');
      debugPrint('Cloud Name: ${AppConfig.cloudinaryCloudName}');
      debugPrint('Upload Preset: ${AppConfig.cloudinaryUploadPreset}');
      debugPrint('Folder: ${AppConfig.cloudinaryEstablishmentLogoFolder}');
    }
    
    var request = http.MultipartRequest('POST', url);

    // Add required fields
    request.fields['upload_preset'] = AppConfig.cloudinaryUploadPreset;
    request.fields['folder'] = AppConfig.cloudinaryEstablishmentLogoFolder;

    if (AppConfig.enableDebugMode) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('📦 REQUEST FIELDS');
      debugPrint('═══════════════════════════════════════');
      request.fields.forEach((key, value) {
        debugPrint('$key: $value');
      });
    }

    // Add file
    final multipartFile = await http.MultipartFile.fromPath('file', imageFile.path);
    request.files.add(multipartFile);
    
    if (AppConfig.enableDebugMode) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('🔎 FILE INFO');
      debugPrint('═══════════════════════════════════════');
      debugPrint('Field name: file');
      debugPrint('Filename: ${multipartFile.filename}');
      debugPrint('Content type: ${multipartFile.contentType}');
      debugPrint('Length: ${multipartFile.length} bytes');
      debugPrint('═══════════════════════════════════════');
      debugPrint('🚀 SENDING REQUEST...');
      debugPrint('═══════════════════════════════════════');
    }

    // Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (AppConfig.enableDebugMode) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('📥 RESPONSE RECEIVED');
      debugPrint('═══════════════════════════════════════');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Status: ${response.statusCode == 200 ? "✓ SUCCESS" : "✗ FAILED"}');
      debugPrint('Response Body:');
      debugPrint(response.body);
      debugPrint('═══════════════════════════════════════');
    }

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final imageUrl = responseData['secure_url'] as String;
      
      setState(() {
        _isSaving = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✓ Logo URL: $imageUrl');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo uploaded successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
      
      return imageUrl;
    } else {
      throw Exception('Upload failed with status ${response.statusCode}: ${response.body}');
    }
  } catch (e, stackTrace) {
    if (AppConfig.enableDebugMode) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('❌ ERROR OCCURRED');
      debugPrint('═══════════════════════════════════════');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('═══════════════════════════════════════');
    }

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload logo: $e'),
          backgroundColor: AppTheme.errorRed,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    return null;
  }
}

  /// Upload cover image to Cloudinary
  Future<String?> _uploadCoverImageToCloudinary(File imageFile) async {
    try {
      final fileSize = await imageFile.length();
      
      if (!AppConfig.isValidImageSize(fileSize)) {
        throw Exception('Image too large. Max size: 5MB');
      }

      final url = Uri.parse(AppConfig.cloudinaryApiUrl);
      var request = http.MultipartRequest('POST', url);

      request.fields['upload_preset'] = AppConfig.cloudinaryUploadPreset;
      request.fields['folder'] = AppConfig.cloudinaryCoverImageFolder; // Use cover folder

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
          const SnackBar(
            content: Text('Location updated successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _isCapturingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update location: $e')),
        );
      }
    }
  }

  /// Open map to manually select location
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

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location updated: ${result['address'] ?? "Mambusao, Capiz"}'),
              backgroundColor: AppTheme.successGreen,
              duration: const Duration(seconds: 2),
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
            content: Text('Error opening map: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Changes'),
        content: const Text('Are you sure you want to save these changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
            child: const Text('Save'),
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

      // Upload new logo if selected
      if (_newLogoFile != null) {
        final uploadedUrl = await _uploadLogoToCloudinary(_newLogoFile!);
        if (uploadedUrl != null) {
          logoUrl = uploadedUrl;
        } else {
          throw Exception('Failed to upload logo');
        }
      }

      // Upload cover image if selected
      String? coverImageUrl = _currentCoverImageUrl;
      if (_newCoverImageFile != null) {
        final uploadedCoverUrl = await _uploadCoverImageToCloudinary(_newCoverImageFile!);
        if (uploadedCoverUrl != null) {
          coverImageUrl = uploadedCoverUrl;
        }
      }

      // Use map-selected location if available, otherwise use current values
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

      // Prepare update data (REMOVED email field)
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
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppTheme.successGreen,
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
          SnackBar(content: Text('Failed to save changes: $e')),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Do you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

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
        backgroundColor: AppTheme.surfaceColor,
        appBar: AppBar(
          title: const Text('Edit Business Profile'),
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Logo Section
                    _buildLogoSection(),
                    const SizedBox(height: 24),

                    // Cover Image Section (NEW)
                    _buildCoverImageSection(),
                    const SizedBox(height: 24),

                    // Basic Information Section
                    _buildSectionHeader('Basic Information', Icons.business),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Business Name',
                      icon: Icons.store,
                      validator: (val) => val?.isEmpty ?? true 
                          ? 'Business name is required' 
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Business Address',
                      icon: Icons.location_on,
                      validator: (val) => val?.isEmpty ?? true 
                          ? 'Address is required' 
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildBusinessTypeDropdown(),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Business Description',
                      icon: Icons.description,
                      maxLines: 4,
                      maxLength: 500,
                    ),
                    const SizedBox(height: 24),

                    // Contact Information Section
                    _buildSectionHeader('Contact Information', Icons.contact_phone),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      enabled: false, // ← Email is read-only
                      validator: null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (val) => val?.isEmpty ?? true 
                          ? 'Phone number is required' 
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // Location Section
                    _buildSectionHeader('Location', Icons.my_location),
                    _buildLocationCard(),
                    const SizedBox(height: 24),

                    // Social Media Section
                    _buildSectionHeader('Social Media (Optional)', Icons.share),
                    _buildTextField(
                      controller: _facebookController,
                      label: 'Facebook URL',
                      icon: Icons.facebook,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _instagramController,
                      label: 'Instagram URL',
                      icon: Icons.camera_alt,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _websiteController,
                      label: 'Website URL',
                      icon: Icons.language,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    _buildSaveButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Business Logo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickLogo,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGreen, width: 2),
                ),
                child: _newLogoFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_newLogoFile!, fit: BoxFit.cover),
                      )
                    : _currentLogoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(_currentLogoUrl!, fit: BoxFit.cover),
                          )
                        : const Icon(
                            Icons.add_photo_alternate,
                            size: 48,
                            color: AppTheme.primaryGreen,
                          ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickLogo,
              icon: const Icon(Icons.edit),
              label: Text(_currentLogoUrl == null ? 'Add Logo' : 'Change Logo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImageSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: AppTheme.primaryGreen, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Cover Image',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Add a banner image to showcase your business',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            
            // Cover Image Preview
            GestureDetector(
              onTap: _pickCoverImage,
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGreen, width: 2),
                ),
                child: _newCoverImageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _newCoverImageFile!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : _currentCoverImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              _currentCoverImageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Failed to load image',
                                      style: TextStyle(color: Colors.grey[600]),
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
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 48,
                                  color: AppTheme.primaryGreen,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to add cover image',
                                  style: TextStyle(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 12),
            
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
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: BorderSide(color: AppTheme.errorRed),
                      ),
                    ),
                  ),
                if (_currentCoverImageUrl != null || _newCoverImageFile != null)
                  const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickCoverImage,
                    icon: Icon(
                      _currentCoverImageUrl != null || _newCoverImageFile != null
                          ? Icons.edit
                          : Icons.add_photo_alternate,
                    ),
                    label: Text(
                      _currentCoverImageUrl != null || _newCoverImageFile != null
                          ? 'Change'
                          : 'Add Cover',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    bool enabled = true, // ← NEW PARAMETER
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled, // ← NEW: Apply enabled state
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100], // ← Visual feedback when disabled
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.errorRed, width: 2),
        ),
        counterText: maxLength != null ? null : '',
      ),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
    );
  }

  Widget _buildBusinessTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedBusinessType,
      decoration: InputDecoration(
        labelText: 'Business Type',
        prefixIcon: const Icon(Icons.category, color: AppTheme.primaryGreen),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
      ),
      items: _businessTypes.map((type) {
        return DropdownMenuItem(value: type, child: Text(type));
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedBusinessType = value;
          _hasUnsavedChanges = true;
        });
      },
      validator: (val) => val == null ? 'Please select a business type' : null,
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Display
            if (_locationSelectedFromMap && _selectedMapLocation != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
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
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Location Updated',
                            style: TextStyle(
                              color: AppTheme.successGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedMapLocation!['address'] ?? 'Mambusao, Capiz',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lat: ${_latitude?.toStringAsFixed(6)}, Long: ${_longitude?.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            else if (_hasLocation && _latitude != null && _longitude != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location Captured via GPS',
                            style: TextStyle(
                              color: AppTheme.successGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lat: ${_latitude!.toStringAsFixed(6)}, Long: ${_longitude!.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
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
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No location set',
                        style: TextStyle(
                          color: Colors.orange[800],
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
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(_isCapturingLocation ? 'Getting...' : 'Use GPS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                      side: const BorderSide(color: AppTheme.primaryGreen),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Map Picker Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _chooseLocationOnMap,
                    icon: const Icon(Icons.map),
                    label: Text(
                      _locationSelectedFromMap ? 'Change Location' : 'Choose on Map',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
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

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.secondaryGreen],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
            : const Text(
                'Save Changes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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