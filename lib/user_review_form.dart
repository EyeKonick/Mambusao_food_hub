import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _reviewController = TextEditingController();
  double _rating = 0.0;
  bool _isLoading = false;

  // --- Aesthetic Colors ---
  static const Color primaryDarkGreen = Color(0xFF1B5E20);
  static const Color accentLightGreen = Color(0xFF66BB6A); // Lighter accent
  static const Color starGold = Colors.amber;
  static const Color fieldBackground = Color(0xFFF0F4F8); // Very light grey-blue for fields

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  // A helper function to get a descriptive text for the rating
  String _getRatingDescription(double rating) {
    if (rating == 0.0) {
      return 'Tap a star to rate!';
    } else if (rating >= 4.5) {
      return 'Excellent!';
    } else if (rating >= 3.5) {
      return 'Very Good';
    } else if (rating >= 2.5) {
      return 'Good';
    } else if (rating >= 1.5) {
      return 'Fair';
    } else {
      return 'Poor';
    }
  }

  Future<void> _submitReview() async {
    // Add validation for rating being selected
    if (_rating == 0.0) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a rating before submitting.')),
        );
        return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await FirebaseFirestore.instance
            .collection('establishments')
            .doc(widget.establishmentId)
            .collection('reviews')
            .add({
          'establishmentId': widget.establishmentId,
          'name': _nameController.text,
          'email': _emailController.text,
          'rating': _rating,
          'comment': _reviewController.text,
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        Navigator.pop(context); // Close the review form
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );
      } catch (e) {
        print('Error submitting review: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit review. Please try again.')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for contrast
      appBar: AppBar(
        title: Text(
          'Review ${widget.establishmentName}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryDarkGreen,
        foregroundColor: Colors.white,
        elevation: 4, // Subtle shadow for AppBar
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 8, // Prominent card shadow
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- 1. Rating Section (The focal point) ---
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: fieldBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _rating == 0.0 ? 'Your Rating' : _rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              color: primaryDarkGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getRatingDescription(_rating),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: primaryDarkGreen.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          RatingBar.builder(
                            initialRating: _rating,
                            minRating: 0.5, // Start rating at 0.5 minimum
                            direction: Axis.horizontal,
                            allowHalfRating: true,
                            itemCount: 5,
                            itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                            itemBuilder: (context, _) => const Icon(
                              Icons.star_rounded,
                              color: starGold,
                              size: 38,
                            ),
                            onRatingUpdate: (rating) {
                              setState(() {
                                _rating = rating;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- 2. Form Fields ---
                    _buildTextField(
                      controller: _nameController,
                      label: 'Your Name',
                      hint: 'e.g. Alex Johnson',
                      icon: Icons.person_outline_rounded,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Your Email',
                      hint: 'e.g. alex.j@example.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email.';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Please enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _reviewController,
                      label: 'Your Review',
                      hint: 'Share your detailed experience...',
                      icon: Icons.rate_review_outlined,
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please write a review.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // --- 3. Submission Button ---
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: primaryDarkGreen))
                        : SizedBox(
                            height: 60,
                            child: ElevatedButton.icon(
                              onPressed: _submitReview,
                              icon: const Icon(Icons.send_rounded),
                              label: const Text(
                                'Submit Review',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryDarkGreen,
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30), // Pill shape
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method for consistent TextFormField styling
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: fieldBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none, // Hide the default border
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentLightGreen, width: 2), // Highlight focus
        ),
        prefixIcon: Icon(icon, color: primaryDarkGreen.withOpacity(0.7)),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      ),
      validator: validator,
    );
  }
}
