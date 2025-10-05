import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'user_auth_page.dart';

class UserReviewForm extends StatefulWidget {
  final String establishmentId;
  final String establishmentName;

  const UserReviewForm({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
  });

  @override
  State<UserReviewForm> createState() => _UserReviewFormState();
}

class _UserReviewFormState extends State<UserReviewForm> {
  // ==================== FIREBASE INSTANCES ====================
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== FORM STATE ====================
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _reviewController = TextEditingController();
  
  double _rating = 3.0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  // ==================== LOAD USER DATA ====================
  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    
    // Check if user is authenticated (not anonymous)
    if (user != null && !user.isAnonymous) {
      // Load user data from Firestore
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection(AppConfig.usersCollection)
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _nameController.text = data['name'] ?? user.displayName ?? '';
            _emailController.text = data['email'] ?? user.email ?? '';
          });
        } else {
          // Fallback to Firebase Auth data
          setState(() {
            _nameController.text = user.displayName ?? '';
            _emailController.text = user.email ?? '';
          });
        }
        
        if (AppConfig.enableDebugMode) {
          debugPrint('✓ User data loaded for review form');
        }
      } catch (e) {
        if (AppConfig.enableDebugMode) {
          debugPrint('Error loading user data: $e');
        }
      }
    }
  }

  // ==================== CHECK FOR EXISTING REVIEW ====================
  Future<bool> _checkExistingReview() async {
    final user = _auth.currentUser;
    
    // Only check for authenticated users (not anonymous)
    if (user == null || user.isAnonymous) {
      return false; // Allow anonymous users to submit (for now)
    }

    try {
      final existingReview = await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(widget.establishmentId)
          .collection(AppConfig.reviewsSubcollection)
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      return existingReview.docs.isNotEmpty;
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('Error checking existing review: $e');
      }
      return false;
    }
  }

  // ==================== SUBMIT REVIEW ====================
  Future<void> _submitReview() async {
    final user = _auth.currentUser;
    
    // CRITICAL: Require authentication for reviews
    if (user == null || user.isAnonymous) {
      // Show dialog prompting user to sign in
      final shouldSignIn = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign In Required'),
          content: const Text(
            'You need to create an account or sign in to write a review. This helps prevent spam and allows you to manage your reviews.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign In'),
            ),
          ],
        ),
      );

      if (shouldSignIn == true) {
        if (!mounted) return;
        // Navigate to sign in page
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserAuthPage()),
        );
        
        // If user successfully signed in, reload user data
        if (result == true) {
          await _loadUserData();
          // Check if they already reviewed this business
          final hasReviewed = await _checkExistingReview();
          if (hasReviewed && mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You have already reviewed this business.'),
              ),
            );
          }
        }
      }
      return;
    }

    // Validate form
    if (!_formKey.currentState!.validate()) return;
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    // Check for existing review
    final hasReviewed = await _checkExistingReview();
    if (hasReviewed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already reviewed this business. You can only review once.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(widget.establishmentId)
          .collection(AppConfig.reviewsSubcollection)
          .add({
        'userId': user.uid,
        'reviewerName': _nameController.text.trim(),
        'reviewerEmail': _emailController.text.trim(),
        'rating': _rating,
        'comment': _reviewController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'isReported': false,
      });

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your review!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );

      // Go back
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit review: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );

      if (AppConfig.enableDebugMode) {
        debugPrint('Error submitting review: $e');
      }
    }
  }

  // ==================== BUILD RATING STARS ====================
  Widget _buildRatingStars() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Rating',
          style: AppTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _rating = i.toDouble();
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i <= _rating ? Icons.star : Icons.star_border,
                    size: 48,
                    color: AppTheme.accentYellow,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _getRatingText(_rating),
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.primaryGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== GET RATING TEXT ====================
  String _getRatingText(double rating) {
    if (rating >= 5) return 'Excellent!';
    if (rating >= 4) return 'Very Good';
    if (rating >= 3) return 'Good';
    if (rating >= 2) return 'Fair';
    return 'Poor';
  }

  // ==================== BUILD METHOD ====================
  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isAuthenticated = user != null && !user.isAnonymous;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Write a Review'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Business Name
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.restaurant,
                        color: AppTheme.primaryGreen,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reviewing',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.establishmentName,
                              style: AppTheme.titleMedium.copyWith(
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Authentication status banner
              if (!isAuthenticated) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.warningOrange),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.warningOrange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sign in required to submit a review',
                          style: TextStyle(color: AppTheme.warningOrange),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Rating Section
              _buildRatingStars(),
              const SizedBox(height: 32),

              // Name Field
              Text(
                'Your Name',
                style: AppTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Enter your name',
                  prefixIcon: Icon(Icons.person),
                ),
                enabled: isAuthenticated,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Email Field
              Text(
                'Your Email',
                style: AppTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Enter your email',
                  prefixIcon: Icon(Icons.email),
                ),
                enabled: isAuthenticated,
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
              const SizedBox(height: 20),

              // Review Field
              Text(
                'Your Review',
                style: AppTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reviewController,
                maxLines: 6,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Share your experience...',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please write your review';
                  }
                  if (value.trim().length < 10) {
                    return 'Review must be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  child: _isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Submitting...'),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isAuthenticated ? Icons.send : Icons.login),
                            const SizedBox(width: 8),
                            Text(
                              isAuthenticated ? 'Submit Review' : 'Sign In to Submit',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Privacy Note
              Center(
                child: Text(
                  'Your review will be publicly visible',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}