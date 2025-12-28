// ====================================================================
// ENHANCED USER REVIEW FORM
// UI Enhancement Phase - Modern, Clean Design with Poppins Font
// 
// ENHANCEMENTS:
// - Modern card-based layout with shadows
// - Interactive star rating with animations
// - Enhanced visual feedback
// - Better form styling
// - Character counter display
// - Improved success/error states
// - Modern authentication prompts
// 
// BUSINESS LOGIC: 100% PRESERVED - NO CHANGES
// ====================================================================

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
  // NO CHANGES - Business logic preserved
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== FORM STATE ====================
  // NO CHANGES - All state management preserved
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
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
    _reviewController.dispose();
    super.dispose();
  }

  // ==================== LOAD USER DATA ====================
  // NO CHANGES - Complete logic preserved
  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    
    if (user != null && !user.isAnonymous) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection(AppConfig.usersCollection)
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _nameController.text = data['name'] ?? user.displayName ?? '';
          });
        } else {
          setState(() {
            _nameController.text = user.displayName ?? '';
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
  // NO CHANGES - Complete logic preserved
  Future<bool> _checkExistingReview() async {
    final user = _auth.currentUser;
    
    if (user == null || user.isAnonymous) {
      return false;
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

  // ==================== UPDATE BUSINESS RATING ====================
  // NO CHANGES - Complete logic preserved
  Future<void> _updateBusinessRating(String businessId) async {
    try {
      final reviewsSnapshot = await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(businessId)
          .collection(AppConfig.reviewsSubcollection)
          .get();

      if (reviewsSnapshot.docs.isEmpty) {
        await _firestore
            .collection(AppConfig.businessesCollection)
            .doc(businessId)
            .update({
          'avgRating': 0.0,
          'reviewCount': 0,
        });
        return;
      }

      double totalRating = 0;
      for (var doc in reviewsSnapshot.docs) {
        final data = doc.data();
        totalRating += (data['rating'] ?? 0).toDouble();
      }

      final avgRating = totalRating / reviewsSnapshot.docs.length;
      final reviewCount = reviewsSnapshot.docs.length;

      await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(businessId)
          .update({
        'avgRating': avgRating,
        'reviewCount': reviewCount,
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✓ Updated avgRating: ${avgRating.toStringAsFixed(2)}, reviewCount: $reviewCount');
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error updating business rating: $e');
      }
    }
  }

  // ==================== SUBMIT REVIEW ====================
  // NO CHANGES - Complete logic preserved
  Future<void> _submitReview() async {
    final user = _auth.currentUser;
    
    if (user == null || user.isAnonymous) {
      final shouldSignIn = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          title: Text('Sign In Required', style: AppTheme.headlineMedium),
          content: Text(
            'You need to create an account or sign in to write a review. This helps prevent spam and allows you to manage your reviews.',
            style: AppTheme.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: AppTheme.labelLarge.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
              child: Text(
                'Sign In',
                style: AppTheme.labelLarge.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );

      if (shouldSignIn == true) {
        if (!mounted) return;
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserAuthPage()),
        );
        
        if (result == true) {
          await _loadUserData();
          final hasReviewed = await _checkExistingReview();
          if (hasReviewed && mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('You have already reviewed this business.'),
                    ),
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
        }
      }
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.star_border, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Expanded(child: Text('Please select a rating')),
            ],
          ),
          backgroundColor: AppTheme.warningOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );
      return;
    }

    final hasReviewed = await _checkExistingReview();
    if (hasReviewed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('You have already reviewed this business. You can only review once.'),
              ),
            ],
          ),
          backgroundColor: AppTheme.warningOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String reviewerName = _nameController.text.trim();
      
      try {
        final userDoc = await _firestore
            .collection(AppConfig.usersCollection)
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          reviewerName = userData['name'] ?? reviewerName;
        }
      } catch (e) {
        if (AppConfig.enableDebugMode) {
          debugPrint('Warning: Could not fetch user data from Firestore: $e');
        }
      }

      await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(widget.establishmentId)
          .collection(AppConfig.reviewsSubcollection)
          .add({
        'userId': user.uid,
        'reviewerName': reviewerName,
        'rating': _rating,
        'comment': _reviewController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'isReported': false,
      });

      await _updateBusinessRating(widget.establishmentId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Expanded(child: Text('Thank you for your review!')),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Failed to submit review: $e')),
            ],
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );

      if (AppConfig.enableDebugMode) {
        debugPrint('Error submitting review: $e');
      }
    }
  }

  // ==================== BUILD RATING STARS (ENHANCED) ====================
  Widget _buildRatingStars() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space8),
                decoration: BoxDecoration(
                  color: AppTheme.accentYellow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: const Icon(
                  Icons.star,
                  color: AppTheme.accentYellow,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Text(
                'Your Rating',
                style: AppTheme.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space24),
          
          // Star rating buttons
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
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Icon(
                        i <= _rating ? Icons.star : Icons.star_border,
                        size: 48,
                        color: i <= _rating 
                            ? AppTheme.accentYellow 
                            : AppTheme.textHint,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          
          // Rating text feedback
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space20,
              vertical: AppTheme.space12,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getRatingIcon(_rating),
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.space8),
                Text(
                  _getRatingText(_rating),
                  style: AppTheme.titleMedium.copyWith(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== GET RATING TEXT ====================
  // NO CHANGES - Logic preserved
  String _getRatingText(double rating) {
    if (rating >= 5) return 'Excellent!';
    if (rating >= 4) return 'Very Good';
    if (rating >= 3) return 'Good';
    if (rating >= 2) return 'Fair';
    return 'Poor';
  }

  // ==================== GET RATING ICON (NEW - UI ONLY) ====================
  IconData _getRatingIcon(double rating) {
    if (rating >= 5) return Icons.sentiment_very_satisfied;
    if (rating >= 4) return Icons.sentiment_satisfied;
    if (rating >= 3) return Icons.sentiment_neutral;
    if (rating >= 2) return Icons.sentiment_dissatisfied;
    return Icons.sentiment_very_dissatisfied;
  }

  // ==================== BUILD METHOD (ENHANCED UI) ====================
  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isAuthenticated = user != null && !user.isAnonymous;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Write a Review',
          style: AppTheme.titleLarge.copyWith(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space20,
                AppTheme.space8,
                AppTheme.space20,
                AppTheme.space32,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryGreen,
                    AppTheme.backgroundLight,
                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.space20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  boxShadow: AppTheme.shadowCard,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: const Icon(
                        Icons.restaurant,
                        color: AppTheme.primaryGreen,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reviewing',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: AppTheme.space4),
                          Text(
                            widget.establishmentName,
                            style: AppTheme.titleLarge.copyWith(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Form content
            Padding(
              padding: const EdgeInsets.all(AppTheme.space20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Authentication status banner
                    if (!isAuthenticated) ...[
                      Container(
                        padding: const EdgeInsets.all(AppTheme.space16),
                        decoration: BoxDecoration(
                          color: AppTheme.warningOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                          border: Border.all(
                            color: AppTheme.warningOrange.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.space8),
                              decoration: BoxDecoration(
                                color: AppTheme.warningOrange,
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppTheme.space12),
                            Expanded(
                              child: Text(
                                'Sign in required to submit a review',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.warningOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.space24),
                    ],

                    // Rating Section
                    _buildRatingStars(),
                    const SizedBox(height: AppTheme.space32),

                    // Name Field
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        boxShadow: AppTheme.shadowCardLight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                color: AppTheme.primaryGreen,
                                size: 20,
                              ),
                              const SizedBox(width: AppTheme.space8),
                              Text(
                                'Your Name',
                                style: AppTheme.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.space12),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: 'Enter your name',
                              filled: true,
                              fillColor: isAuthenticated 
                                  ? AppTheme.backgroundLight 
                                  : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: BorderSide(
                                  color: AppTheme.borderLight,
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: BorderSide(
                                  color: AppTheme.borderLight,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: BorderSide(
                                  color: AppTheme.primaryGreen,
                                  width: 2,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: isAuthenticated 
                                    ? AppTheme.textHint 
                                    : AppTheme.primaryGreen,
                              ),
                            ),
                            readOnly: isAuthenticated,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          if (isAuthenticated) ...[
                            const SizedBox(height: AppTheme.space8),
                            Row(
                              children: [
                                Icon(
                                  Icons.lock,
                                  size: 14,
                                  color: AppTheme.textHint,
                                ),
                                const SizedBox(width: AppTheme.space4),
                                Text(
                                  'Automatically filled from your profile',
                                  style: AppTheme.caption.copyWith(
                                    color: AppTheme.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.space20),

                    // Review Field
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        boxShadow: AppTheme.shadowCardLight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.edit_note,
                                color: AppTheme.primaryGreen,
                                size: 20,
                              ),
                              const SizedBox(width: AppTheme.space8),
                              Text(
                                'Your Review',
                                style: AppTheme.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.space8,
                                  vertical: AppTheme.space4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                ),
                                child: Text(
                                  '${_reviewController.text.length}/500',
                                  style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.space12),
                          TextFormField(
                            controller: _reviewController,
                            maxLines: 6,
                            maxLength: 500,
                            onChanged: (value) => setState(() {}), // Update character count
                            decoration: InputDecoration(
                              hintText: 'Share your experience with this restaurant...',
                              hintStyle: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textHint,
                              ),
                              filled: true,
                              fillColor: AppTheme.backgroundLight,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: BorderSide(
                                  color: AppTheme.borderLight,
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: BorderSide(
                                  color: AppTheme.borderLight,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: BorderSide(
                                  color: AppTheme.primaryGreen,
                                  width: 2,
                                ),
                              ),
                              counterText: '', // Hide default counter
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please write your review';
                              }
                              if (value.trim().length < 5) {
                                return 'Review must be at least 5 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppTheme.space8),
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                size: 14,
                                color: AppTheme.textHint,
                              ),
                              const SizedBox(width: AppTheme.space4),
                              Expanded(
                                child: Text(
                                  'Be specific about food, service, and ambiance',
                                  style: AppTheme.caption.copyWith(
                                    color: AppTheme.textHint,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.space32),

                    // Submit Button
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        boxShadow: _isSubmitting ? [] : [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitReview,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppTheme.textHint,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            ),
                          ),
                          child: _isSubmitting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.space16),
                                    Text(
                                      'Submitting...',
                                      style: AppTheme.titleMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isAuthenticated ? Icons.send : Icons.login,
                                      size: 24,
                                    ),
                                    const SizedBox(width: AppTheme.space12),
                                    Text(
                                      isAuthenticated ? 'Submit Review' : 'Sign In to Submit',
                                      style: AppTheme.titleMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space20),

                    // Privacy Note
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space16),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(
                          color: AppTheme.accentBlue.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.public,
                            size: 20,
                            color: AppTheme.accentBlue,
                          ),
                          const SizedBox(width: AppTheme.space12),
                          Expanded(
                            child: Text(
                              'Your review will be publicly visible',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.accentBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.space32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// END OF ENHANCED USER REVIEW FORM
// ====================================================================