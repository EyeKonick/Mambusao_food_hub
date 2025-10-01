import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'business_dashboard.dart';

// TODO: Ensure you have added the following dependencies to your pubspec.yaml file:
// dependencies:
//   flutter:
//     sdk: flutter
//   firebase_auth: ^4.15.3
//   cloud_firestore: ^4.13.6

class BusinessAuthPage extends StatefulWidget {
  const BusinessAuthPage({super.key});

  @override
  BusinessAuthPageState createState() => BusinessAuthPageState();
}

class BusinessAuthPageState extends State<BusinessAuthPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // All the new and updated controllers for the sign-up fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _restaurantNameController = TextEditingController();
  final TextEditingController _restaurantAddressController = TextEditingController();

  // Variables for the dropdown
  String? _businessType;

  // State variables for real-time password validation feedback
  bool _isLogin = true;
  bool _isLoading = false;
  String _errorMessage = '';
  String? _passwordStrengthMessage;
  
  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color accentGreen = Color(0xFF4CAF50);

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
  
  void _validatePasswordStrength() {
    if (_isLogin) return; // Only show validation for sign-up
    final password = _passwordController.text;
    if (password.length < 6) {
      setState(() {
        _passwordStrengthMessage = 'Password is too short (min 6 characters).';
      });
    } else {
      setState(() {
        _passwordStrengthMessage = 'Password is valid.';
      });
    }
  }

  Future<void> _handleAuth() async {
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    if (_formKey.currentState!.validate()) {
      try {
        if (_isLogin) {
          // Existing login logic
          await _auth.signInWithEmailAndPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );
        } else {
          // Sign-up logic without photo upload
          UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );

          // Save business details to Firestore, using a placeholder for the photo URL
          await _firestore.collection('businesses').doc(userCredential.user!.uid).set({
            'fullName': _fullNameController.text,
            'email': _emailController.text,
            'phoneNumber': _phoneNumberController.text,
            'restaurantName': _restaurantNameController.text,
            'restaurantAddress': _restaurantAddressController.text,
            'businessType': _businessType,
            'photoUrl': null, // Set the photoUrl to null for now
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BusinessDashboardPage()),
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = e.message ?? 'An unknown error occurred.';
        });
      } on FirebaseException catch (e) {
        setState(() {
          _errorMessage = e.message ?? 'A database error occurred.';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isLogin ? 'Business Login' : 'Create Account'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
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
                // Display logo only on the login screen
                if (_isLogin) ...[
                  Image.asset('assets/logo.png', height: 100),
                  const SizedBox(height: 24),
                ],

                // Use different header text for login and sign-up
                Text(
                  _isLogin ? 'Welcome Back!' : 'Create Business Account',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.red[400]!),
                    ),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red[700]),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Sign-up specific fields
                if (!_isLogin) ...[
                  // Static logo placeholder section
                  _buildLogoPlaceholderSection(),
                  const SizedBox(height: 24),
                  
                  _buildTextFormField(
                    controller: _fullNameController,
                    hintText: 'Full Name',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _emailController,
                    hintText: 'Business Email Address',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a valid email address';
                      }
                      // A more robust email validation using a regular expression
                      final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                      if (!emailRegExp.hasMatch(value)) {
                        return 'Please enter a valid email format';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _phoneNumberController,
                    hintText: 'Phone Number',
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _passwordController,
                    hintText: 'Password',
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      return null;
                    },
                  ),
                  // Real-time password strength indicator
                  if (_passwordStrengthMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _passwordStrengthMessage!,
                        style: TextStyle(
                          color: _passwordStrengthMessage == 'Password is valid.'
                              ? primaryGreen
                              : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirm Password',
                    obscureText: true,
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
                  const Text(
                    'Restaurant Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _restaurantNameController,
                    hintText: 'Restaurant Name',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the restaurant name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _restaurantAddressController,
                    hintText: 'Restaurant Address',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the restaurant address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownFormField(),
                  const SizedBox(height: 16),

                ] else ...[
                  // Login-specific fields (from the original app layout)
                  _buildTextFormField(
                    controller: _emailController,
                    hintText: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                      if (!emailRegExp.hasMatch(value)) {
                        return 'Please enter a valid email format';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _passwordController,
                    hintText: 'Password',
                    obscureText: true,
                    prefixIcon: const Icon(Icons.lock),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          _isLogin ? 'Login' : 'Sign Up',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _errorMessage = '';
                      _passwordStrengthMessage = null; // Reset password message on switch
                      _formKey.currentState?.reset();
                      _emailController.clear();
                      _passwordController.clear();
                      _fullNameController.clear();
                      _phoneNumberController.clear();
                      _confirmPasswordController.clear();
                      _restaurantNameController.clear();
                      _restaurantAddressController.clear();
                      _businessType = null;
                    });
                  },
                  child: Text(
                    _isLogin ? 'Don\'t have an account? Sign Up' : 'Already have an account? Login',
                    style: const TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method for consistent text field styling
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Icon? prefixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: _isLogin ? hintText : null, // Use label text for the old login design
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[200],
        prefixIcon: prefixIcon,
      ),
      validator: validator,
    );
  }

  // New method for the logo upload section
  Widget _buildLogoPlaceholderSection() {
    return const Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Color(0xFFF0F0F0),
            child: Icon(Icons.business, size: 40, color: Color(0xFFC0C0C0)),
          ),
          SizedBox(height: 8),
          Text(
            'Business Logo Placeholder',
            style: TextStyle(color: primaryGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFormField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: 'Business Type',
        ),
        items: const [
          DropdownMenuItem(value: 'Tea & coffee', child: Text('Tea & coffee')),
          DropdownMenuItem(value: 'Bakery', child: Text('Bakery')),
          DropdownMenuItem(value: 'Carenderia', child: Text('Carenderia')),
          DropdownMenuItem(value: 'Pizzeria', child: Text('Pizzeria')),
          DropdownMenuItem(value: 'Casual Dining', child: Text('Casual Dining')),
          DropdownMenuItem(value: 'Fast Food', child: Text('Fast Food')),
        ],
        onChanged: (String? newValue) {
          setState(() {
            _businessType = newValue;
          });
        },
        validator: (value) {
          if (value == null) {
            return 'Please select a business type';
          }
          return null;
        },
      ),
    );
  }
}
