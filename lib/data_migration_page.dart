// lib/admin/migrate_counters_page.dart
// One-time migration to initialize viewCount and bookmarkCount

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_config.dart';
import '../config/app_theme.dart';

class MigrateCountersPage extends StatefulWidget {
  const MigrateCountersPage({Key? key}) : super(key: key);

  @override
  State<MigrateCountersPage> createState() => _MigrateCountersPageState();
}

class _MigrateCountersPageState extends State<MigrateCountersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isProcessing = false;
  String _status = 'Ready to migrate';
  int _processedCount = 0;
  int _totalCount = 0;

  Future<void> _migrateCounters() async {
    setState(() {
      _isProcessing = true;
      _status = 'Starting migration...';
      _processedCount = 0;
      _totalCount = 0;
    });

    try {
      // Get all businesses
      final businessSnapshot = await _firestore
          .collection(AppConfig.businessesCollection)
          .get();

      _totalCount = businessSnapshot.docs.length;

      setState(() {
        _status = 'Found $_totalCount businesses to process...';
      });

      for (var businessDoc in businessSnapshot.docs) {
        final businessId = businessDoc.id;
        final data = businessDoc.data();

        // Count actual bookmarks for this business
        final bookmarksSnapshot = await _firestore
            .collectionGroup('bookmarks')
            .where('businessId', isEqualTo: businessId)
            .get();
        
        final actualBookmarkCount = bookmarksSnapshot.docs.length;

        // Count actual views for this business
        final viewsSnapshot = await _firestore
            .collection(AppConfig.businessesCollection)
            .doc(businessId)
            .collection('views')
            .get();
        
        final actualViewCount = viewsSnapshot.docs.length;

        // Get current values (if they exist)
        final currentViewCount = data['viewCount'] as int? ?? 0;
        final currentBookmarkCount = data['bookmarkCount'] as int? ?? 0;

        // Use the maximum of current count or actual count
        final finalViewCount = actualViewCount > currentViewCount 
            ? actualViewCount 
            : currentViewCount;
        
        final finalBookmarkCount = actualBookmarkCount > currentBookmarkCount
            ? actualBookmarkCount
            : currentBookmarkCount;

        // Update business document
        await _firestore
            .collection(AppConfig.businessesCollection)
            .doc(businessId)
            .set({
          'viewCount': finalViewCount,
          'bookmarkCount': finalBookmarkCount,
        }, SetOptions(merge: true));

        _processedCount++;
        
        setState(() {
          _status = 'Processing: $_processedCount/$_totalCount\n'
              'Business: ${data['businessName']}\n'
              'Views: $finalViewCount, Bookmarks: $finalBookmarkCount';
        });

        // Small delay to avoid overwhelming Firestore
        await Future.delayed(const Duration(milliseconds: 100));
      }

      setState(() {
        _status = '✓ Migration complete!\n'
            'Processed $_processedCount businesses\n'
            'All counters initialized successfully';
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration complete! Processed $_processedCount businesses'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = '✗ Migration failed: $e';
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration failed: $e'),
            backgroundColor: AppTheme.errorRed,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Migrate View & Bookmark Counters'),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Card
            Card(
              color: AppTheme.accentBlue.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: AppTheme.accentBlue),
                        const SizedBox(width: 12),
                        Text(
                          'What this does:',
                          style: AppTheme.titleMedium.copyWith(
                            color: AppTheme.accentBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Initializes viewCount for all businesses\n'
                      '• Initializes bookmarkCount for all businesses\n'
                      '• Counts existing views and bookmarks\n'
                      '• Updates business documents with correct counts',
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Status Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isProcessing
                              ? Icons.sync
                              : _status.startsWith('✓')
                                  ? Icons.check_circle
                                  : _status.startsWith('✗')
                                      ? Icons.error
                                      : Icons.pending,
                          color: _isProcessing
                              ? AppTheme.accentYellow
                              : _status.startsWith('✓')
                                  ? AppTheme.successGreen
                                  : _status.startsWith('✗')
                                      ? AppTheme.errorRed
                                      : AppTheme.primaryGreen,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Status',
                          style: AppTheme.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      style: AppTheme.bodyMedium.copyWith(
                        height: 1.5,
                      ),
                    ),
                    if (_totalCount > 0) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _totalCount > 0 ? _processedCount / _totalCount : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Start Button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _migrateCounters,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  _isProcessing ? 'Processing...' : 'Start Migration',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Warning
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning, color: AppTheme.warningOrange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This is a one-time operation. Run it only once to initialize counters for existing businesses.',
                      style: AppTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}