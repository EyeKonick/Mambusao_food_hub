// lib/admin/migrate_ratings_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_config.dart';
import '../config/app_theme.dart';

class MigrateRatingsPage extends StatefulWidget {
  const MigrateRatingsPage({super.key});

  @override
  State<MigrateRatingsPage> createState() => _MigrateRatingsPageState();
}

class _MigrateRatingsPageState extends State<MigrateRatingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isMigrating = false;
  String _status = '';
  int _totalBusinesses = 0;
  int _processedBusinesses = 0;
  List<String> _migrationLog = [];

  Future<void> _migrateRatings() async {
    setState(() {
      _isMigrating = true;
      _status = 'Starting migration...';
      _migrationLog.clear();
      _processedBusinesses = 0;
    });

    try {
      // Get all businesses
      final businesses = await _firestore
          .collection(AppConfig.businessesCollection)
          .get();

      _totalBusinesses = businesses.docs.length;

      setState(() {
        _status = 'Found $_totalBusinesses businesses to process...';
        _migrationLog.add('✓ Found $_totalBusinesses businesses');
      });

      // Wait a moment to show the message
      await Future.delayed(const Duration(seconds: 1));

      for (var businessDoc in businesses.docs) {
        final businessId = businessDoc.id;
        final businessData = businessDoc.data();
        final businessName = businessData['businessName'] ?? 'Unknown';
        
        setState(() {
          _processedBusinesses++;
          _status = 'Processing: $businessName ($_processedBusinesses/$_totalBusinesses)';
        });

        try {
          // Get all reviews for this business
          final reviews = await _firestore
              .collection(AppConfig.businessesCollection)
              .doc(businessId)
              .collection(AppConfig.reviewsSubcollection)
              .get();

          // Calculate average rating
          double avgRating = 0.0;
          int reviewCount = reviews.docs.length;

          if (reviewCount > 0) {
            double totalRating = 0;
            for (var review in reviews.docs) {
              final data = review.data();
              totalRating += (data['rating'] as num).toDouble();
            }
            avgRating = totalRating / reviewCount;
          }

          // Update business document
          await _firestore
              .collection(AppConfig.businessesCollection)
              .doc(businessId)
              .update({
            'avgRating': avgRating,
            'reviewCount': reviewCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          setState(() {
            _migrationLog.add(
              '✓ $businessName: ${avgRating.toStringAsFixed(1)}⭐ ($reviewCount reviews)'
            );
          });

          // Small delay to avoid overwhelming Firestore
          await Future.delayed(const Duration(milliseconds: 100));

        } catch (e) {
          setState(() {
            _migrationLog.add('✗ Error with $businessName: $e');
          });
        }
      }

      setState(() {
        _status = '✓ Migration complete! Processed $_processedBusinesses businesses.';
        _isMigrating = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Migration completed successfully!'),
          backgroundColor: AppTheme.successGreen,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() {
        _status = '✗ Migration failed: $e';
        _isMigrating = false;
        _migrationLog.add('✗ Fatal error: $e');
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorRed,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Migrate Ratings'),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rate,
                  size: 60,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Rating Migration',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'This will calculate and store average ratings for all existing businesses.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Progress indicator
              if (_isMigrating) ...[
                LinearProgressIndicator(
                  value: _totalBusinesses > 0 
                      ? _processedBusinesses / _totalBusinesses 
                      : null,
                  backgroundColor: AppTheme.surfaceColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Status message
              if (_status.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isMigrating 
                        ? AppTheme.accentBlue.withOpacity(0.1)
                        : _status.startsWith('✓')
                            ? AppTheme.successGreen.withOpacity(0.1)
                            : AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isMigrating 
                          ? AppTheme.accentBlue.withOpacity(0.3)
                          : _status.startsWith('✓')
                              ? AppTheme.successGreen.withOpacity(0.3)
                              : AppTheme.errorRed.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isMigrating)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryGreen,
                            ),
                          ),
                        )
                      else
                        Icon(
                          _status.startsWith('✓') 
                              ? Icons.check_circle 
                              : Icons.error,
                          color: _status.startsWith('✓')
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                          size: 20,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _status,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Migration log
              if (_migrationLog.isNotEmpty) ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.list_alt,
                              size: 20,
                              color: AppTheme.primaryGreen,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Migration Log',
                              style: AppTheme.titleMedium.copyWith(
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _migrationLog.length,
                            itemBuilder: (context, index) {
                              final log = _migrationLog[index];
                              final isError = log.startsWith('✗');
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isError ? '✗' : '✓',
                                      style: TextStyle(
                                        color: isError 
                                            ? AppTheme.errorRed 
                                            : AppTheme.successGreen,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        log.substring(2),
                                        style: AppTheme.bodySmall.copyWith(
                                          color: isError 
                                              ? AppTheme.errorRed 
                                              : AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Action buttons
              if (!_isMigrating) ...[
                if (_status.isEmpty || !_status.startsWith('✓'))
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _migrateRatings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Start Migration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (_status.startsWith('✓')) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle),
                      label: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],

              // Warning message
              if (!_isMigrating && _status.isEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.warningOrange.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.warningOrange,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This operation will update all business documents. Run this only once.',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.warningOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}