import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'establishment_details_page.dart';
import 'package:mambusao_food_hub/search_page.dart';
import 'package:mambusao_food_hub/shared_widgets.dart'; // New import for shared widgets

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Position? _currentPosition;
  final String _appTitle = 'MamFood Hub';

  static const Color primaryGreen = Color(0xFF1B5E20); // A dark forest green
  static const Color secondaryGreen = Color(0xFF4CAF50); // A lighter green for accents
  static const Color backgroundColor = Color(0xFFF0F0F0); // A light grey background

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  double _calculateDistance(GeoPoint geoPoint) {
    if (_currentPosition == null) {
      return -1; // Indicates distance cannot be calculated
    }
    double earthRadius = 6371e3; // metres
    double lat1 = _currentPosition!.latitude * pi / 180;
    double lat2 = geoPoint.latitude * pi / 180;
    double deltaLat = (geoPoint.latitude - _currentPosition!.latitude) * pi / 180;
    double deltaLon = (geoPoint.longitude - _currentPosition!.longitude) * pi / 180;

    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c / 1000; // Distance in km
  }

  Future<double> _getAverageRating(String establishmentId) async {
    final reviews = await FirebaseFirestore.instance
        .collection('establishments')
        .doc(establishmentId)
        .collection('reviews')
        .get();

    if (reviews.docs.isEmpty) {
      return 0.0;
    }

    double totalRating = 0.0;
    for (var doc in reviews.docs) {
      // Ensure safe casting to num before toDouble()
      final rating = doc.data()['rating'];
      if (rating is num) {
          totalRating += rating.toDouble();
      }
    }

    return totalRating / reviews.docs.length;
  }

  Future<int> _getReviewCount(String establishmentId) async {
    final reviews = await FirebaseFirestore.instance
        .collection('establishments')
        .doc(establishmentId)
        .collection('reviews')
        .get();
    return reviews.docs.length;
  }

  // Helper widget to build the modern rating chip
  Widget _buildRatingChip(double averageRating, int reviewCount) {
    if (reviewCount == 0) {
      return const Text('New establishment', style: TextStyle(fontSize: 12, color: primaryGreen, fontWeight: FontWeight.bold));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: primaryGreen, // Use primary color for rating background
        borderRadius: BorderRadius.circular(15.0),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            averageRating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($reviewCount)',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // --- New Logo Widget Implementation ---
  Widget _buildLogoWidget(String? logoUrl) {
    const double logoSize = 60.0;
    const double borderRadius = 10.0;

    if (logoUrl == null || logoUrl.isEmpty) {
      // Placeholder if no URL is provided
      return Container(
        width: logoSize,
        height: logoSize,
        decoration: BoxDecoration(
          color: secondaryGreen.withOpacity(0.2),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(Icons.store, color: primaryGreen, size: 30),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        logoUrl,
        width: logoSize,
        height: logoSize,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          // Loading state
          return Container(
            width: logoSize,
            height: logoSize,
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                color: primaryGreen,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Fallback on error
          return Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Icon(Icons.broken_image, color: Colors.red, size: 30),
          );
        },
      ),
    );
  }
  // ------------------------------------


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(_appTitle),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Search Bar area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SearchPage()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        'Search for food or restaurants...',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 16.0),
              child: Text(
                'Explore',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildCategoryList(),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Nearby Establishments',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildEstablishmentList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        children: <Widget>[
          _buildCategoryCard(icon: Icons.fastfood, label: 'Fast Food'),
          _buildCategoryCard(icon: Icons.local_dining, label: 'Carinderia'),
          _buildCategoryCard(icon: Icons.restaurant, label: 'Casual Dining'),
          _buildCategoryCard(icon: Icons.storefront, label: 'Food Stall'),
          _buildCategoryCard(icon: Icons.cake, label: 'Bakery'),
          _buildCategoryCard(icon: Icons.local_pizza, label: 'Pizzeria'),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({required IconData icon, required String label}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: secondaryGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEstablishmentList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('establishments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No establishments found.'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final establishment = snapshot.data!.docs[index];
            final data = establishment.data() as Map<String, dynamic>;
            final geoPoint = data['location'] as GeoPoint?;
            final establishmentName = data['name'] as String;
            final logoUrl = data['logoUrl'] as String?; // Retrieve the logo URL

            double distance = geoPoint != null ? _calculateDistance(geoPoint) : -1;

            return FutureBuilder<Map<String, dynamic>>(
              future: Future.wait([
                _getAverageRating(establishment.id),
                _getReviewCount(establishment.id),
              ]).then((results) => {
                    'averageRating': results[0] as double,
                    'reviewCount': results[1] as int,
                  }),
              builder: (context, ratingSnapshot) {
                if (ratingSnapshot.connectionState == ConnectionState.waiting) {
                  // Return an empty SizedBox to prevent jumpy layout while fetching ratings
                  return const SizedBox(); 
                }

                final averageRating = ratingSnapshot.data?['averageRating'] ?? 0.0;
                final reviewCount = ratingSnapshot.data?['reviewCount'] ?? 0;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EstablishmentDetailsPage(
                          establishmentId: establishment.id,
                          establishmentName: establishmentName,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      // Modern Card Styling
                      margin: const EdgeInsets.symmetric(vertical: 10.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0), // More rounded corners
                      ),
                      elevation: 8, // Higher elevation for a floating effect
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Establishment Logo
                            _buildLogoWidget(logoUrl),
                            
                            const SizedBox(width: 16),

                            // 2. Establishment Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Establishment Name
                                  Text(
                                    data['name'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 20, // Slightly larger title
                                      fontWeight: FontWeight.w800, // Bolder
                                      color: primaryGreen,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),

                                  // Category
                                  Text(
                                    data['category'] ?? 'N/A',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  // Rating Chip and Distance Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Rating (New Modern Chip)
                                      _buildRatingChip(averageRating, reviewCount),
                                      
                                      // Distance
                                      Row(
                                        children: [
                                          Icon(Icons.directions_walk, size: 18, color: secondaryGreen),
                                          const SizedBox(width: 4),
                                          Text(
                                            distance != -1
                                                ? '${distance.toStringAsFixed(2)} km'
                                                : 'Locating...',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
