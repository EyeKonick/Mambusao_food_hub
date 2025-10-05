// lib/business_auth_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

// Import our config and theme
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'business_dashboard.dart';

/// Business Owner Authentication Page
/// 
/// This page handles:
/// - Business owner login
/// - Business registration (sign up)
/// - One account = One business/restaurant
/// - Location capture for distance calculations
class BusinessAuthPage extends StatefulWidget {
  const BusinessAuthPage({super.key});

  @override
  BusinessAuthPageState createState() => BusinessAuthPageState();
}

class BusinessAuthPageState extends State<BusinessAuthPage> {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // ==================== TEXT CONTROLLERS ====================
  
  // Account Information
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  
  // Business/Restaurant Information
  final TextEditingController _restaurantNameController = TextEditingController();
  final TextEditingController _restaurantAddressController = TextEditingController();

  // ==================== STATE VARIABLES ====================
  
  /// Are we showing login or sign-up form?
  bool _isLogin = true;
  
  /// Is a request in progress?
  bool _isLoading = false;
  
  /// Error message to show user
  String _errorMessage = '';
  
  /// Password strength feedback
  String? _passwordStrengthMessage;
  
  /// Selected business type
  String? _businessType;
  
  /// Location state
  Position? _businessLocation;
  bool _isGettingLocation = false;
  String? _locationError;
  
  /// List of available business categories
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
    super.dispose();
  }

  // ==================== PASSWORD VALIDATION ====================
  
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

  // ==================== LOCATION CAPTURE ====================
  
  /// Capture business location using GPS
  Future<void> _captureLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS in your device settings.');
      }

      // 2. Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied. Please grant location access.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable in app settings.');
      }

      // 3. Get current position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _businessLocation = position;
        _isGettingLocation = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✓ Location captured: ${position.latitude}, ${position.longitude}');
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location captured successfully!'),
            backgroundColor: AppTheme.secondaryGreen,
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

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: ${e.toString()}'),
            backgroundColor: AppTheme.accentRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ==================== AUTHENTICATION LOGIC ====================
  
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BusinessDashboardPage()),
      );
      
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFriendlyErrorMessage(e.code);
      });
    } on FirebaseException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'A database error occurred.';
      });
      if (AppConfig.enableDebugMode) {
       debugPrint('Firebase Error Details:');
       debugPrint('Code: ${e.code}');
       debugPrint('Message: ${e.message}');
       debugPrint('Plugin: ${e.plugin}');
     }
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
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    await userCredential.user!.updateDisplayName(_fullNameController.text.trim());

    // Create business profile with location data
    await _firestore
        .collection(AppConfig.businessesCollection)
        .doc(userCredential.user!.uid)
        .set({
      // Owner Information
      'ownerName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phoneNumber': _phoneNumberController.text.trim(),
      
      // Business Information
      'businessName': _restaurantNameController.text.trim(),
      'businessAddress': _restaurantAddressController.text.trim(),
      'businessType': _businessType,
      'logoUrl': null,
      
      // Location Data (NEW)
      'latitude': _businessLocation?.latitude,
      'longitude': _businessLocation?.longitude,
      'hasLocation': _businessLocation != null,
      
      // Status and Timestamps
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

  // ==================== UI BUILD METHOD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isLogin ? 'Business Login' : 'Create Business Account'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_isLogin) ...[
                  Image.asset('assets/logo.png', height: 100),
                  const SizedBox(height: 24),
                ],

                Text(
                  _isLogin ? 'Welcome Back!' : 'Create Business Account',
                  style: AppTheme.headingLarge.copyWith(
                    color: AppTheme.primaryGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                if (_errorMessage.isNotEmpty) _buildErrorMessage(),

                if (!_isLogin) ...[
                  _buildLogoPlaceholder(),
                  const SizedBox(height: 24),
                  _buildSignUpFields(),
                ] else ...[
                  _buildLoginFields(),
                ],

                const SizedBox(height: 24),
                _buildSubmitButton(),
                const SizedBox(height: 16),
                _buildToggleButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== UI COMPONENTS ====================

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: AppTheme.accentRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppTheme.accentRed),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.accentRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(color: AppTheme.accentRed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: AppTheme.lightGreen,
            child: Icon(
              Icons.business,
              size: 40,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Business Logo (Add Later)',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Account Information',
          style: AppTheme.headingSmall.copyWith(
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(height: 16),

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
        const SizedBox(height: 16),

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
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

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
        const SizedBox(height: 16),

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
            padding: const EdgeInsets.only(top: 8.0, left: 12.0),
            child: Text(
              _passwordStrengthMessage!,
              style: AppTheme.bodySmall.copyWith(
                color: _passwordStrengthMessage == 'Password is strong'
                    ? AppTheme.secondaryGreen
                    : AppTheme.accentYellow,
              ),
            ),
          ),

        const SizedBox(height: 16),

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

        const SizedBox(height: 32),

        Text(
          'Business Details',
          style: AppTheme.headingSmall.copyWith(
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(height: 16),

        _buildTextField(
          controller: _restaurantNameController,
          label: 'Business/Restaurant Name',
          hint: 'e.g., Juan\'s Eatery',
          icon: Icons.restaurant,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your business name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

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
        const SizedBox(height: 16),

        _buildBusinessTypeDropdown(),
        const SizedBox(height: 24),

        // NEW: Location Capture Section
        _buildLocationCaptureSection(),
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
        const SizedBox(height: 16),

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
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
      ),
      validator: validator,
    );
  }

  Widget _buildBusinessTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _businessType,
      decoration: InputDecoration(
        labelText: 'Business Type',
        hintText: 'Select category',
        prefixIcon: Icon(Icons.category, color: AppTheme.primaryGreen),
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

  // NEW: Location Capture UI
  Widget _buildLocationCaptureSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: AppTheme.primaryGreen,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Business Location',
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Optional: Capture your business location to show distance to customers',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Location status
            if (_businessLocation != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.secondaryGreen),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.secondaryGreen),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location Captured',
                            style: TextStyle(
                              color: AppTheme.secondaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Lat: ${_businessLocation!.latitude.toStringAsFixed(6)}\nLon: ${_businessLocation!.longitude.toStringAsFixed(6)}',
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
            else if (_locationError != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentYellow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentYellow),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: AppTheme.accentYellow),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _locationError!,
                        style: TextStyle(
                          color: AppTheme.accentYellow,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Location not captured yet',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Capture button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGettingLocation ? null : _captureLocation,
                icon: _isGettingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        _businessLocation != null
                            ? Icons.refresh
                            : Icons.my_location,
                      ),
                label: Text(
                  _isGettingLocation
                      ? 'Getting Location...'
                      : _businessLocation != null
                          ? 'Recapture Location'
                          : 'Capture Location',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _businessLocation != null
                      ? AppTheme.secondaryGreen
                      : AppTheme.primaryGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleAuth,
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              _isLogin ? 'Login' : 'Create Account',
              style: const TextStyle(fontSize: 16),
            ),
    );
  }

  Widget _buildToggleButton() {
    return TextButton(
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
                _businessType = null;
                _businessLocation = null;
                _locationError = null;
              });
            },
      child: Text(
        _isLogin
            ? 'Don\'t have an account? Sign Up'
            : 'Already have an account? Login',
      ),
    );
  }
}