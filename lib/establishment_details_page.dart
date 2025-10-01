import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_review_form.dart'; // Assuming this file exists and is correct

class EstablishmentDetailsPage extends StatefulWidget {
  final String establishmentId;
  final String establishmentName;

  const EstablishmentDetailsPage({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
  });

  @override
  State<EstablishmentDetailsPage> createState() =>
      _EstablishmentDetailsPageState();
}

class _EstablishmentDetailsPageState extends State<EstablishmentDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Color primaryGreen = Color(0xFF1B5E20); // Dark Green
  static const Color lightGreen = Color(0xFF4CAF50); // Light Green
  static const Color accentYellow = Color(0xFFFFC107); // Amber
  static const Color backgroundColor = Color(0xFFFAFAFA); // Very light grey

  // Helper to display the establishment's logo
  Widget _buildLogo(String? establishmentLogoUrl) {
    final String? logoToDisplay = establishmentLogoUrl;
    const double logoSize = 100.0;

    return Container(
      height: logoSize,
      width: logoSize,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: logoToDisplay != null && logoToDisplay.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    logoToDisplay,
                    height: logoSize,
                    width: logoSize,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Icon(Icons.storefront_rounded,
                          color: lightGreen, size: 50),
                    ),
                  ),
                )
              : Center(
                  child:
                      Icon(Icons.storefront_rounded, color: lightGreen, size: 50),
                ),
    );
  }

  // NEW HELPER: Build widget for menu item image or placeholder
  Widget _buildMenuItemImage(String? imageUrl) {
    const double size = 70.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        height: size,
        width: size,
        color: lightGreen.withOpacity(0.2), // Light background for placeholder
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(Icons.fastfood, color: primaryGreen, size: 30),
                ),
              )
            : Center(
                child: Icon(Icons.fastfood, color: primaryGreen, size: 30),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('establishments')
          .doc(widget.establishmentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Loading Details'),
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            body: const Center(
                child: CircularProgressIndicator(color: primaryGreen)),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Error'),
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            body: const Center(
                child: Text('Establishment not found.',
                    style: TextStyle(fontSize: 16))),
          );
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        final String? establishmentLogoUrl = data['logoUrl'];

        return Scaffold(
          backgroundColor: backgroundColor,
          body: CustomScrollView(
            slivers: [
              // Simple app bar
              SliverAppBar(
                pinned: true,
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                title: Text(
                  data['name'] ?? 'Details',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),

              SliverList(
                delegate: SliverChildListDelegate(
                  [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // Logo + Name
                          Align(
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                _buildLogo(establishmentLogoUrl),
                                const SizedBox(height: 10),
                                Text(
                                  data['name'] ?? 'Unnamed Establishment',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          _buildRatingAndReviewInfo(),
                          const SizedBox(height: 24),

                          Text(
                            data['description'] ??
                                'No description available.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),

                          _buildSectionTitle('Information', Icons.info_outline),
                          const SizedBox(height: 16),
                          _buildDetailsCard(data),
                          const SizedBox(height: 32),

                          _buildSectionTitle('Menu Items', Icons.menu_book),
                          const SizedBox(height: 16),
                          _buildMenuItemsList(), // This is where the menu loads
                          const SizedBox(height: 32),

                          _buildSectionTitle(
                              'Customer Reviews', Icons.rate_review),
                          const SizedBox(height: 16),
                          _buildReviewsList(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _navigateToReviewForm,
            label: const Text(
              'Write a Review',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            icon: const Icon(Icons.edit_note, color: Colors.white, size: 28),
            backgroundColor: primaryGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
            elevation: 10,
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryGreen, size: 28),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard(Map<String, dynamic> data) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildDetailRow(Icons.location_on_outlined, 'Address',
                data['address'] ?? 'N/A'),
            const Divider(height: 20),
            _buildDetailRow(Icons.phone_outlined, 'Contact',
                data['contactNumber'] ?? 'N/A'),
            const Divider(height: 20),
            _buildDetailRow(
                Icons.category_outlined, 'Category', data['category'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: lightGreen, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingAndReviewInfo() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('establishments')
          .doc(widget.establishmentId)
          .collection('reviews')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        double averageRating = 0.0;
        final reviews = snapshot.data!.docs;

        if (reviews.isNotEmpty) {
          double totalRating = 0;
          for (var doc in reviews) {
            totalRating +=
                (doc.data() as Map<String, dynamic>)['rating'] as num? ?? 0.0;
          }
          averageRating = totalRating / reviews.length;
        }
        int reviewCount = reviews.length;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.star_rounded, color: accentYellow, size: 36),
            const SizedBox(width: 8),
            Text(
              averageRating > 0 ? averageRating.toStringAsFixed(1) : '—',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '($reviewCount ratings)',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuItemsList() {
    return StreamBuilder<QuerySnapshot>(
      // 🚨 Ensure the Establishment ID (widget.establishmentId) is correct here! 🚨
      stream: _firestore
          .collection('establishments')
          .doc(widget.establishmentId)
          .collection('menuItems')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: primaryGreen));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text('No menu items available.',
                  style: TextStyle(color: Colors.grey[600])));
        }

        final menuItems = snapshot.data!.docs;
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            var item = menuItems[index].data() as Map<String, dynamic>;
            final String? imageUrl = item['imageUrl'];
            
            // Updated Card and ListTile to include the image
            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 4,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 8.0, horizontal: 16.0),
                
                // ADDED: Display the menu item image here
                leading: _buildMenuItemImage(imageUrl), 

                title: Text(
                  item['name'] ?? 'No Name',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: primaryGreen),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    item['description'] ?? 'No Description',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: Text(
                  '₱${(item['price'] as num?)?.toStringAsFixed(2) ?? 'N/A'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: primaryGreen,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReviewsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('establishments')
          .doc(widget.establishmentId)
          .collection('reviews')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: primaryGreen));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text('No reviews yet. Be the first to share your experience!',
                  style: TextStyle(color: Colors.grey[600])));
        }

        final reviews = snapshot.data!.docs;
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            var review = reviews[index].data() as Map<String, dynamic>;

            String formattedDate = '';
            Timestamp? timestamp = review['timestamp'] as Timestamp?;
            if (timestamp != null) {
              // Simple date formatting
              formattedDate = timestamp.toDate().toString().split(' ')[0];
            } else {
              formattedDate = 'Unknown Date';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review['reviewerName'] ?? 'Anonymous User',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: primaryGreen),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${(review['rating'] as num?)?.toStringAsFixed(1) ?? 'N/A'}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.star_rounded,
                                color: accentYellow, size: 24),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20, thickness: 1),
                    Text(
                      review['comment'] ?? 'No comment provided.',
                      style: TextStyle(
                          fontSize: 15, color: Colors.grey[800], height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToReviewForm() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserReviewForm(
          establishmentId: widget.establishmentId,
          establishmentName: widget.establishmentName,
        ),
      ),
    );
  }
}
