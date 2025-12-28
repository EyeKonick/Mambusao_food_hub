// ====================================================================
// ENHANCED USER AUTHENTICATION PAGE
// UI Enhancement Phase - Modern, Clean Design with Poppins Font
// 
// ENHANCEMENTS APPLIED:
// - Modern gradient background
// - Enhanced card design with larger radius
// - Better form field styling
// - Improved button design
// - Enhanced password strength indicator
// - Better error message display
// - Modern illustrations/icons
// - Smooth animations
// ====================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';

/// User authentication page for regular customers
class UserAuthPage extends StatefulWidget {
  const UserAuthPage({super.key});

  @override
  State<UserAuthPage> createState() => _UserAuthPageState();
}

class _UserAuthPageState extends State<UserAuthPage> with SingleTickerProviderStateMixin {
  // ==================== FIREBASE INSTANCES ====================
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== FORM CONTROLLERS ====================
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // ==================== STATE VARIABLES ====================
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _passwordStrengthMessage;
  
  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswordStrength);
    
    // Initialize animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ==================== PASSWORD VALIDATION ====================
  void _validatePasswordStrength() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _passwordStrengthMessage = null);
      return;
    }

    if (password.length < 6) {
      setState(() => _passwordStrengthMessage = 'Password is too short (min 6 characters)');
    } else if (password.length < 8) {
      setState(() => _passwordStrengthMessage = 'Password is acceptable');
    } else {
      setState(() => _passwordStrengthMessage = 'Password is strong');
    }
  }

  // ==================== AUTHENTICATION LOGIC ====================
  Future<void> _performLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Check if this is a regular user
      final userDoc = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        await _auth.signOut();
        setState(() {
          _errorMessage = 'This account is not registered as a regular user. Please use the business owner login.';
          _isLoading = false;
        });
        return;
      }

      if (AppConfig.enableDebugMode) {
        debugPrint('✓ User logged in: ${userCredential.user!.email}');
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFriendlyErrorMessage(e.code);
        _isLoading = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Login error: ${e.code}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _performSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('STEP 1: Creating Firebase Auth account');
      debugPrint('Email: ${_emailController.text.trim()}');
      
      // Create authentication account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      debugPrint('✓ Auth account created successfully');
      debugPrint('  UID: ${userCredential.user!.uid}');
      debugPrint('  Email: ${userCredential.user!.email}');
      debugPrint('  Is Anonymous: ${userCredential.user!.isAnonymous}');
      
      // Update display name
      debugPrint('\nSTEP 2: Updating display name');
      await userCredential.user!.updateDisplayName(_nameController.text.trim());
      debugPrint('✓ Display name updated');
      
      // Force token refresh and reload user
      debugPrint('\nSTEP 3: Refreshing auth token');
      await userCredential.user!.reload();
      final freshUser = _auth.currentUser!;
      await freshUser.getIdToken(true);
      debugPrint('✓ Token refreshed');
      
      // Wait for token to propagate
      debugPrint('\nSTEP 4: Waiting for token propagation (800ms)');
      await Future.delayed(const Duration(milliseconds: 800));
      debugPrint('✓ Wait complete');
      
      // Verify auth state before Firestore write
      debugPrint('\nSTEP 5: Verifying auth state');
      debugPrint('  Current User UID: ${freshUser.uid}');
      debugPrint('  Is Anonymous: ${freshUser.isAnonymous}');
      debugPrint('  Email Verified: ${freshUser.emailVerified}');
      
      // Create user document in Firestore
      debugPrint('\nSTEP 6: Creating Firestore document');
      debugPrint('  Collection: ${AppConfig.usersCollection}');
      debugPrint('  Document ID: ${freshUser.uid}');
      
      final userData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };
      
      debugPrint('  Data: ${userData.keys.toList()}');
      
      await _firestore
        .collection(AppConfig.usersCollection)
        .doc(freshUser.uid)
        .set(userData);

      debugPrint('✓ Firestore document created successfully');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('SUCCESS: User account created and saved!');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Account created successfully!',
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white),
                ),
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

      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFriendlyErrorMessage(e.code);
        _isLoading = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Sign up error: ${e.code}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Unexpected error: $e');
      }
    }
  }

  // ==================== ERROR MESSAGES ====================
  String _getFriendlyErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication error. Please try again.';
    }
  }

  // ==================== MAIN BUILD (ENHANCED) ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          _isLogin ? 'Sign In' : 'Create Account',
          style: AppTheme.titleLarge.copyWith(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.space24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Icon Section
                  Container(
                    padding: const EdgeInsets.all(AppTheme.space24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isLogin ? Icons.login : Icons.person_add,
                      size: 80,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.space32),
                  
                  // Welcome Text
                  Text(
                    _isLogin ? 'Welcome Back!' : 'Join MamFood Hub',
                    style: AppTheme.displayMedium.copyWith(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: AppTheme.space8),
                  
                  Text(
                    _isLogin 
                        ? 'Sign in to discover and bookmark restaurants'
                        : 'Create your account to start exploring',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: AppTheme.space32),
                  
                  // Form Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      boxShadow: AppTheme.shadowCard,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.space24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Error Message Display
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(AppTheme.space12),
                              margin: const EdgeInsets.only(bottom: AppTheme.space16),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                border: Border.all(
                                  color: AppTheme.errorRed.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: AppTheme.errorRed,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppTheme.space12),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.errorRed,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Name field (registration only)
                          if (!_isLogin) ...[
                            _buildTextField(
                              controller: _nameController,
                              label: 'Full Name',
                              icon: Icons.person_outline,
                              keyboardType: TextInputType.name,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your full name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppTheme.space16),
                          ],

                          // Email field
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppTheme.space16),

                          // Phone field (registration only)
                          if (!_isLogin) ...[
                            _buildTextField(
                              controller: _phoneController,
                              label: 'Phone Number',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppTheme.space16),
                          ],

                          // Password field
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: AppTheme.textSecondary,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (!_isLogin && value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),

                          // Password strength indicator (registration only)
                          if (!_isLogin && _passwordStrengthMessage != null) ...[
                            const SizedBox(height: AppTheme.space8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.space12,
                                vertical: AppTheme.space8,
                              ),
                              decoration: BoxDecoration(
                                color: _getStrengthColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _getStrengthIcon(),
                                    size: 16,
                                    color: _getStrengthColor(),
                                  ),
                                  const SizedBox(width: AppTheme.space8),
                                  Text(
                                    _passwordStrengthMessage!,
                                    style: AppTheme.bodySmall.copyWith(
                                      color: _getStrengthColor(),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Confirm password field (registration only)
                          if (!_isLogin) ...[
                            const SizedBox(height: AppTheme.space16),
                            _buildTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              icon: Icons.lock_outline,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppTheme.textSecondary,
                                ),
                                onPressed: () {
                                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                                },
                              ),
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
                          ],

                          const SizedBox(height: AppTheme.space32),

                          // Submit button
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : (_isLogin ? _performLogin : _performSignUp),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                ),
                                elevation: 0,
                                shadowColor: AppTheme.primaryGreen.withOpacity(0.4),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      _isLogin ? 'Sign In' : 'Create Account',
                                      style: AppTheme.titleMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.space24),

                  // Toggle between login and registration
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? "Don't have an account?" : 'Already have an account?',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _errorMessage = null;
                            _formKey.currentState?.reset();
                            _emailController.clear();
                            _passwordController.clear();
                            _nameController.clear();
                            _phoneController.clear();
                            _confirmPasswordController.clear();
                          });
                          // Reset animation
                          _animationController.reset();
                          _animationController.forward();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.space12,
                            vertical: AppTheme.space8,
                          ),
                        ),
                        child: Text(
                          _isLogin ? 'Sign Up' : 'Sign In',
                          style: AppTheme.labelLarge.copyWith(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Forgot password (login only)
                  if (_isLogin) ...[
                    const SizedBox(height: AppTheme.space8),
                    TextButton(
                      onPressed: _isLoading ? null : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Forgot password feature coming soon!',
                              style: AppTheme.bodyMedium.copyWith(color: Colors.white),
                            ),
                            backgroundColor: AppTheme.accentBlue,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'Forgot Password?',
                        style: AppTheme.labelLarge.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: AppTheme.space24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== ENHANCED TEXT FIELD BUILDER ====================
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: AppTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textSecondary,
        ),
        prefixIcon: Icon(
          icon,
          color: AppTheme.primaryGreen,
          size: 22,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppTheme.backgroundLight,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(
            color: AppTheme.errorRed,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space16,
        ),
      ),
      validator: validator,
    );
  }

  // ==================== HELPER METHODS ====================
  
  Color _getStrengthColor() {
    if (_passwordStrengthMessage == null) return AppTheme.textSecondary;
    if (_passwordStrengthMessage!.contains('strong')) return AppTheme.successGreen;
    if (_passwordStrengthMessage!.contains('acceptable')) return AppTheme.warningOrange;
    return AppTheme.errorRed;
  }

  IconData _getStrengthIcon() {
    if (_passwordStrengthMessage == null) return Icons.info_outline;
    if (_passwordStrengthMessage!.contains('strong')) return Icons.check_circle;
    if (_passwordStrengthMessage!.contains('acceptable')) return Icons.warning;
    return Icons.error;
  }
}