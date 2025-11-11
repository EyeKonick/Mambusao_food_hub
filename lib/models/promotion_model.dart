import 'package:cloud_firestore/cloud_firestore.dart';

class Promotion {
  final String id;
  final String businessId;
  final String businessName;
  final String title;
  final String description;
  final String? imageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Promotion({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  // Create from Firestore document
  factory Promotion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Promotion(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      businessName: data['businessName'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'businessName': businessName,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Check if promotion is currently valid
  bool get isValid {
    final now = DateTime.now();
    return isActive && 
           now.isAfter(startDate) && 
           now.isBefore(endDate);
  }

  // Get days remaining
  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return 0;
    return endDate.difference(now).inDays;
  }

  // Get status text
  String get statusText {
    if (!isActive) return 'Inactive';
    final now = DateTime.now();
    if (now.isBefore(startDate)) return 'Scheduled';
    if (now.isAfter(endDate)) return 'Expired';
    return 'Active';
  }
}