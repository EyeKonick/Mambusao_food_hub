import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

// This is a placeholder for the details page, ensure you have the actual file.
import 'package:mambusao_food_hub/establishment_details_page.dart';

// The EstablishmentCard widget, moved here to be shared by both pages.
class EstablishmentCard extends StatelessWidget {
  final QueryDocumentSnapshot establishment;
  final Position? currentPosition;

  const EstablishmentCard({super.key, required this.establishment, this.currentPosition});

  // Function to calculate distance (replicated for self-containment)
  double _calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    if (currentPosition == null) {
      return double.infinity;
    }
    const double p = 0.017453292519943295;
    final a = 0.5 - cos((endLat - startLat) * p) / 2 +
        cos(startLat * p) * cos(endLat * p) *
            (1 - cos((endLng - startLng) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // A simple widget to get average rating
  Widget _getAverageRating(String establishmentId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('establishments')
          .doc(establishmentId)
          .collection('reviews')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('No ratings yet.');
        }

        double totalRating = 0;
        int reviewCount = 0;
        for (var doc in snapshot.data!.docs) {
          var rating = doc['rating'];
          if (rating != null) {
            totalRating += (rating as num).toDouble();
            reviewCount++;
          }
        }
        
        if (reviewCount == 0) {
          return const Text('No ratings yet.');
        }

        double averageRating = totalRating / reviewCount;

        return Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 4),
            Text(
              averageRating.toStringAsFixed(1),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($reviewCount reviews)',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String establishmentId = establishment.id;
    Map<String, dynamic> data = establishment.data() as Map<String, dynamic>;
    
    double lat = (data['latitude'] is num) ? data['latitude'].toDouble() : 0.0;
    double lng = (data['longitude'] is num) ? data['longitude'].toDouble() : 0.0;
    
    String distanceText = 'Distance unknown';
    if (currentPosition != null) {
      double distanceInKm = _calculateDistance(currentPosition!.latitude, currentPosition!.longitude, lat, lng);
      distanceText = '${distanceInKm.toStringAsFixed(2)} km away';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EstablishmentDetailsPage(
                establishmentId: establishmentId,
                establishmentName: data['name'] ?? 'No Name',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['name'] ?? 'No Name',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data['address'] ?? 'No Address',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                distanceText,
                style: const TextStyle(color: Colors.blueAccent),
              ),
              const SizedBox(height: 8),
              _getAverageRating(establishmentId),
            ],
          ),
        ),
      ),
    );
  }
}


// The CategoryCard widget, moved here to be shared.
class CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;

  const CategoryCard({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF0D47A1),
            radius: 30,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
