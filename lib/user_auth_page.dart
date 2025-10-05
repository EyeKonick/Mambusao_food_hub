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

class _UserAuthPageState extends State<UserAuthPage> {
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

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswordStrength);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _confirmPasswordController.dispose();
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
          content: Text('Account created successfully! Welcome, ${_nameController.text}!'),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(true);

    } on FirebaseAuthException catch (e) {
      debugPrint('\n❌ FIREBASE AUTH ERROR');
      debugPrint('  Code: ${e.code}');
      debugPrint('  Message: ${e.message}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      setState(() {
        _errorMessage = _getFriendlyErrorMessage(e.code);
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      debugPrint('\n❌ FIRESTORE ERROR');
      debugPrint('  Code: ${e.code}');
      debugPrint('  Message: ${e.message}');
      debugPrint('  Plugin: ${e.plugin}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      setState(() {
        _errorMessage = 'Database error: ${e.message}\n\nCheck Firebase Security Rules.';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('\n❌ UNEXPECTED ERROR');
      debugPrint('  Error: $e');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      setState(() {
        _errorMessage = 'Unexpected error: $e';
        _isLoading = false;
      });
    }
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
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  // ==================== UI BUILD METHOD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_isLogin ? 'Sign In' : 'Create Account'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App logo or icon
                  Icon(
                    Icons.person_outline,
                    size: 80,
                    color: AppTheme.primaryGreen,
                  ),
                  const SizedBox(height: 16),

                  // Welcome text
                  Text(
                    _isLogin ? 'Welcome Back!' : 'Join MamFood Hub',
                    style: AppTheme.headingLarge.copyWith(
                      color: AppTheme.primaryGreen,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin
                        ? 'Sign in to continue exploring restaurants'
                        : 'Create an account to bookmark and review',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Error message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.errorRed),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: AppTheme.errorRed),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Name field (registration only)
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
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
                  const SizedBox(height: 16),

                  // Phone field (registration only)
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _passwordStrengthMessage!.contains('strong')
                              ? Icons.check_circle
                              : _passwordStrengthMessage!.contains('acceptable')
                                  ? Icons.warning
                                  : Icons.error,
                          size: 16,
                          color: _passwordStrengthMessage!.contains('strong')
                              ? AppTheme.successGreen
                              : _passwordStrengthMessage!.contains('acceptable')
                                  ? AppTheme.warningOrange
                                  : AppTheme.errorRed,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _passwordStrengthMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _passwordStrengthMessage!.contains('strong')
                                ? AppTheme.successGreen
                                : _passwordStrengthMessage!.contains('acceptable')
                                    ? AppTheme.warningOrange
                                    : AppTheme.errorRed,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Confirm password field (registration only)
                  if (!_isLogin) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                          },
                        ),
                      ),
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
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

                  const SizedBox(height: 24),

                  // Submit button
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_isLogin ? _performLogin : _performSignUp),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _isLogin ? 'Sign In' : 'Create Account',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Toggle between login and registration
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? "Don't have an account?" : 'Already have an account?',
                        style: AppTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _errorMessage = null;
                            _formKey.currentState?.reset();
                          });
                        },
                        child: Text(
                          _isLogin ? 'Sign Up' : 'Sign In',
                          style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Forgot password (login only)
                  if (_isLogin) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Forgot password feature coming soon!'),
                          ),
                        );
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}