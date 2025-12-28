import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'services/promotion_service.dart';
import 'models/promotion_model.dart';

class BusinessPromotionsPage extends StatefulWidget {
  const BusinessPromotionsPage({super.key});

  @override
  State<BusinessPromotionsPage> createState() => _BusinessPromotionsPageState();
}

class _BusinessPromotionsPageState extends State<BusinessPromotionsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PromotionService _promotionService = PromotionService();

  // State variables
  String _businessId = '';
  String _businessName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBusinessInfo();
  }

  Future<void> _loadBusinessInfo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      final businessDoc = await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(user.uid)
          .get();

      if (businessDoc.exists) {
        final data = businessDoc.data() as Map<String, dynamic>;
        setState(() {
          _businessId = user.uid;
          _businessName = data['businessName'] ?? 'My Business';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error loading business info: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showCreatePromotionDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreatePromotionDialog(
        businessId: _businessId,
        businessName: _businessName,
        onPromotionCreated: () {
          // Refresh handled by StreamBuilder
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text('Promotion created successfully!'),
                  ],
                ),
                backgroundColor: AppTheme.successGreen,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _showEditPromotionDialog(Promotion promotion) {
    showDialog(
      context: context,
      builder: (context) => _EditPromotionDialog(
        promotion: promotion,
        onPromotionUpdated: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text('Promotion updated successfully!'),
                  ],
                ),
                backgroundColor: AppTheme.successGreen,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _togglePromotionStatus(Promotion promotion) async {
    final newStatus = !promotion.isActive;
    final success = await _promotionService.togglePromotionStatus(
      promotion.id,
      newStatus,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                newStatus ? Icons.check_circle : Icons.info_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(
                newStatus
                    ? 'Promotion activated'
                    : 'Promotion deactivated',
              ),
            ],
          ),
          backgroundColor: newStatus ? AppTheme.successGreen : AppTheme.warningOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      );
    }
  }

  Future<void> _deletePromotion(Promotion promotion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: AppTheme.errorRed,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Delete Promotion'),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${promotion.title}"? This action cannot be undone.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _promotionService.deletePromotion(promotion.id);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Promotion deleted'),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    }
  }

  Widget _buildPromotionCard(Promotion promotion) {
    final now = DateTime.now();
    final isScheduled = now.isBefore(promotion.startDate);
    final isExpired = now.isAfter(promotion.endDate);
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (isExpired) {
      statusColor = AppTheme.textSecondary;
      statusText = 'EXPIRED';
      statusIcon = Icons.event_busy;
    } else if (isScheduled) {
      statusColor = AppTheme.accentBlue;
      statusText = 'SCHEDULED';
      statusIcon = Icons.schedule;
    } else if (!promotion.isActive) {
      statusColor = AppTheme.warningOrange;
      statusText = 'INACTIVE';
      statusIcon = Icons.pause_circle_outline;
    } else {
      statusColor = AppTheme.successGreen;
      statusText = 'ACTIVE';
      statusIcon = Icons.check_circle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.shadowCard,
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header with promotion image or icon
          if (promotion.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusLarge),
                topRight: Radius.circular(AppTheme.radiusLarge),
              ),
              child: Image.network(
                promotion.imageUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 160,
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    child: const Icon(
                      Icons.local_offer,
                      size: 64,
                      color: AppTheme.primaryGreen,
                    ),
                  );
                },
              ),
            ),

          // Content
          Padding(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        promotion.title,
                        style: AppTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space12,
                        vertical: AppTheme.space4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: AppTheme.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppTheme.space12),

                // Description
                Text(
                  promotion.description,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: AppTheme.space16),

                // Date Information
                Container(
                  padding: const EdgeInsets.all(AppTheme.space12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      // Start Date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Start Date',
                                  style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${promotion.startDate.day}/${promotion.startDate.month}/${promotion.startDate.year}',
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Divider
                      Container(
                        height: 40,
                        width: 1,
                        color: AppTheme.dividerColor,
                      ),
                      
                      // End Date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const SizedBox(width: AppTheme.space12),
                                Icon(
                                  Icons.event,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'End Date',
                                  style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: AppTheme.space12),
                              child: Text(
                                '${promotion.endDate.day}/${promotion.endDate.month}/${promotion.endDate.year}',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.space12),

                // Time Status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space12,
                    vertical: AppTheme.space8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isScheduled
                            ? 'Starts in ${promotion.startDate.difference(now).inDays} days'
                            : isExpired
                                ? 'Ended ${now.difference(promotion.endDate).inDays} days ago'
                                : '${promotion.daysRemaining} days remaining',
                        style: AppTheme.bodySmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.space16),

                // Action Buttons
                Row(
                  children: [
                    // Toggle Active/Inactive
                    if (!isExpired)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _togglePromotionStatus(promotion),
                          icon: Icon(
                            promotion.isActive
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            size: 18,
                          ),
                          label: Text(
                            promotion.isActive ? 'Pause' : 'Activate',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: promotion.isActive 
                                ? AppTheme.warningOrange 
                                : AppTheme.successGreen,
                            side: BorderSide(
                              color: promotion.isActive 
                                  ? AppTheme.warningOrange 
                                  : AppTheme.successGreen,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            ),
                          ),
                        ),
                      ),
                    
                    if (!isExpired) const SizedBox(width: AppTheme.space8),
                    
                    // Edit
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditPromotionDialog(promotion),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGreen,
                          side: const BorderSide(
                            color: AppTheme.primaryGreen,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: AppTheme.space8),
                    
                    // Delete
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(
                          color: AppTheme.errorRed.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () => _deletePromotion(promotion),
                        icon: const Icon(Icons.delete_outline),
                        color: AppTheme.errorRed,
                        tooltip: 'Delete promotion',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Promotions'),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppTheme.primaryGreen,
                strokeWidth: 3,
              ),
              const SizedBox(height: AppTheme.space16),
              Text(
                'Loading promotions...',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Promotions'),
        elevation: 0,
      ),
      body: StreamBuilder<List<Promotion>>(
        stream: _promotionService.getBusinessPromotions(_businessId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(AppTheme.space32),
                padding: const EdgeInsets.all(AppTheme.space24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  boxShadow: AppTheme.shadowCardLight,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space16),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppTheme.errorRed,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space16),
                    Text(
                      'Error loading promotions',
                      style: AppTheme.titleLarge,
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      snapshot.error.toString(),
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
                strokeWidth: 3,
              ),
            );
          }

          final promotions = snapshot.data ?? [];

          if (promotions.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(AppTheme.space32),
                padding: const EdgeInsets.all(AppTheme.space32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  boxShadow: AppTheme.shadowCardLight,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space24),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.local_offer,
                        size: 80,
                        color: AppTheme.primaryGreen.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space24),
                    Text(
                      'No promotions yet',
                      style: AppTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Create your first promotion to attract customers\nand boost your business!',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.space24),
                    ElevatedButton.icon(
                      onPressed: _showCreatePromotionDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Promotion'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space24,
                          vertical: AppTheme.space16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Separate promotions by status
          final activePromotions = promotions.where((p) {
            final now = DateTime.now();
            return p.isActive &&
                   now.isAfter(p.startDate) &&
                   now.isBefore(p.endDate);
          }).toList();

          final scheduledPromotions = promotions.where((p) {
            final now = DateTime.now();
            return now.isBefore(p.startDate);
          }).toList();

          final inactivePromotions = promotions.where((p) {
            final now = DateTime.now();
            return !p.isActive &&
                   now.isAfter(p.startDate) &&
                   now.isBefore(p.endDate);
          }).toList();

          final expiredPromotions = promotions.where((p) {
            final now = DateTime.now();
            return now.isAfter(p.endDate);
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(AppTheme.space16),
            children: [
              // Stats Card
              Container(
                padding: const EdgeInsets.all(AppTheme.space20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  boxShadow: AppTheme.shadowCard,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppTheme.space8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: const Icon(
                            Icons.bar_chart,
                            color: AppTheme.primaryGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppTheme.space12),
                        Text(
                          'Overview',
                          style: AppTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space20),
                    Row(
                      children: [
                        _buildStatItem(
                          'Active',
                          activePromotions.length.toString(),
                          AppTheme.successGreen,
                          Icons.check_circle,
                        ),
                        _buildStatItem(
                          'Scheduled',
                          scheduledPromotions.length.toString(),
                          AppTheme.accentBlue,
                          Icons.schedule,
                        ),
                        _buildStatItem(
                          'Inactive',
                          inactivePromotions.length.toString(),
                          AppTheme.warningOrange,
                          Icons.pause_circle,
                        ),
                        _buildStatItem(
                          'Expired',
                          expiredPromotions.length.toString(),
                          AppTheme.textSecondary,
                          Icons.event_busy,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space24),

              // Active Promotions
              if (activePromotions.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space8),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: AppTheme.successGreen,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space8),
                    Text(
                      'Active',
                      style: AppTheme.titleLarge.copyWith(
                        color: AppTheme.successGreen,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space8,
                        vertical: AppTheme.space4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        activePromotions.length.toString(),
                        style: AppTheme.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space12),
                ...activePromotions.map(_buildPromotionCard),
                const SizedBox(height: AppTheme.space24),
              ],

              // Scheduled Promotions
              if (scheduledPromotions.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: const Icon(
                        Icons.schedule,
                        color: AppTheme.accentBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space8),
                    Text(
                      'Scheduled',
                      style: AppTheme.titleLarge.copyWith(
                        color: AppTheme.accentBlue,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space8,
                        vertical: AppTheme.space4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        scheduledPromotions.length.toString(),
                        style: AppTheme.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space12),
                ...scheduledPromotions.map(_buildPromotionCard),
                const SizedBox(height: AppTheme.space24),
              ],

              // Inactive Promotions
              if (inactivePromotions.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space8),
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: const Icon(
                        Icons.pause_circle,
                        color: AppTheme.warningOrange,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space8),
                    Text(
                      'Inactive',
                      style: AppTheme.titleLarge.copyWith(
                        color: AppTheme.warningOrange,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space8,
                        vertical: AppTheme.space4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        inactivePromotions.length.toString(),
                        style: AppTheme.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space12),
                ...inactivePromotions.map(_buildPromotionCard),
                const SizedBox(height: AppTheme.space24),
              ],

              // Expired Promotions
              if (expiredPromotions.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space8),
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Icon(
                        Icons.event_busy,
                        color: AppTheme.textSecondary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space8),
                    Text(
                      'Expired',
                      style: AppTheme.titleLarge.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space8,
                        vertical: AppTheme.space4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        expiredPromotions.length.toString(),
                        style: AppTheme.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space12),
                ...expiredPromotions.map(_buildPromotionCard),
              ],
              
              // Bottom padding
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePromotionDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Promotion'),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 4,
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            value,
            style: AppTheme.headlineMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            label,
            style: AppTheme.labelSmall.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ==================== CREATE PROMOTION DIALOG ====================
class _CreatePromotionDialog extends StatefulWidget {
  final String businessId;
  final String businessName;
  final VoidCallback onPromotionCreated;

  const _CreatePromotionDialog({
    required this.businessId,
    required this.businessName,
    required this.onPromotionCreated,
  });

  @override
  State<_CreatePromotionDialog> createState() => _CreatePromotionDialogState();
}

class _CreatePromotionDialogState extends State<_CreatePromotionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final PromotionService _promotionService = PromotionService();

  DateTime? _startDate;
  DateTime? _endDate;
  File? _selectedImage;
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // FIXED: Image picker doesn't clear text fields
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        // Store the file but DON'T call setState yet
        final file = File(image.path);
        
        // Use a delayed setState to prevent clearing text fields
        Future.microtask(() {
          if (mounted) {
            setState(() {
              _selectedImage = file;
            });
          }
        });
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error picking image: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    try {
      final url = Uri.parse(AppConfig.cloudinaryApiUrl);
      final request = http.MultipartRequest('POST', url);

      request.fields['upload_preset'] = AppConfig.cloudinaryUploadPreset;
      request.fields['folder'] = 'promotions';

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonData = jsonDecode(responseString);

      if (response.statusCode == 200) {
        return jsonData['secure_url'];
      } else {
        throw Exception('Upload failed: ${jsonData['error']['message']}');
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Cloudinary upload error: $e');
      }
      return null;
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        // Reset end date if it's before new start date
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()).add(const Duration(days: 7)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _createPromotion() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 12),
              Text('Please select start and end dates'),
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

    setState(() {
      _isUploading = true;
    });

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImageToCloudinary(_selectedImage!);
        if (imageUrl == null) {
          throw Exception('Image upload failed');
        }
      }

      final success = await _promotionService.createPromotion(
        businessId: widget.businessId,
        businessName: widget.businessName,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: imageUrl,
        startDate: _startDate!,
        endDate: _endDate!,
      );

      if (success && mounted) {
        widget.onPromotionCreated();
        Navigator.pop(context);
      } else {
        throw Exception('Failed to create promotion');
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error creating promotion: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Icon(
              Icons.add_circle_outline,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          const Text('Create Promotion'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Promotion Title *',
                  hintText: 'e.g., Buy 1 Take 1',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.space16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Describe your promotion',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.space16),

              // Dates Section
              Container(
                padding: const EdgeInsets.all(AppTheme.space12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.borderLight,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Start Date
                    InkWell(
                      onTap: _selectStartDate,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.space8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.space8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: const Icon(
                                Icons.calendar_today,
                                color: AppTheme.primaryGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppTheme.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Start Date',
                                    style: AppTheme.labelSmall.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _startDate != null
                                        ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                        : 'Not selected',
                                    style: AppTheme.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _startDate != null 
                                          ? AppTheme.textPrimary 
                                          : AppTheme.textHint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 1),

                    // End Date
                    InkWell(
                      onTap: _selectEndDate,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.space8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.space8),
                              decoration: BoxDecoration(
                                color: AppTheme.accentBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: const Icon(
                                Icons.event,
                                color: AppTheme.accentBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppTheme.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'End Date',
                                    style: AppTheme.labelSmall.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _endDate != null
                                        ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                        : 'Not selected',
                                    style: AppTheme.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _endDate != null 
                                          ? AppTheme.textPrimary 
                                          : AppTheme.textHint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.space16),

              // Image Picker
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _pickImage,
                icon: Icon(_selectedImage != null ? Icons.check_circle : Icons.image),
                label: Text(_selectedImage != null ? 'Image Selected' : 'Add Image (Optional)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _selectedImage != null 
                      ? AppTheme.successGreen 
                      : AppTheme.primaryGreen,
                  side: BorderSide(
                    color: _selectedImage != null 
                        ? AppTheme.successGreen 
                        : AppTheme.primaryGreen,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.space12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
              ),

              if (_selectedImage != null) ...[
                const SizedBox(height: AppTheme.space12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: Image.file(
                    _selectedImage!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _createPromotion,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space24,
              vertical: AppTheme.space12,
            ),
          ),
          child: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

// ==================== EDIT PROMOTION DIALOG ====================
class _EditPromotionDialog extends StatefulWidget {
  final Promotion promotion;
  final VoidCallback onPromotionUpdated;

  const _EditPromotionDialog({
    required this.promotion,
    required this.onPromotionUpdated,
  });

  @override
  State<_EditPromotionDialog> createState() => _EditPromotionDialogState();
}

class _EditPromotionDialogState extends State<_EditPromotionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  final PromotionService _promotionService = PromotionService();

  late DateTime _startDate;
  late DateTime _endDate;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.promotion.title);
    _descriptionController = TextEditingController(text: widget.promotion.description);
    _startDate = widget.promotion.startDate;
    _endDate = widget.promotion.endDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(picked)) {
          _endDate = picked.add(const Duration(days: 7));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _updatePromotion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final success = await _promotionService.updatePromotion(
        promotionId: widget.promotion.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
      );

      if (success && mounted) {
        widget.onPromotionUpdated();
        Navigator.pop(context);
      } else {
        throw Exception('Failed to update promotion');
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error updating promotion: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Icon(
              Icons.edit,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          const Text('Edit Promotion'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Promotion Title *',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.space16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description *',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.space16),

              // Dates Section
              Container(
                padding: const EdgeInsets.all(AppTheme.space12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppTheme.borderLight,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Start Date
                    InkWell(
                      onTap: _selectStartDate,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.space8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.space8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: const Icon(
                                Icons.calendar_today,
                                color: AppTheme.primaryGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppTheme.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Start Date',
                                    style: AppTheme.labelSmall.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                                    style: AppTheme.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 1),

                    // End Date
                    InkWell(
                      onTap: _selectEndDate,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.space8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.space8),
                              decoration: BoxDecoration(
                                color: AppTheme.accentBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: const Icon(
                                Icons.event,
                                color: AppTheme.accentBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppTheme.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'End Date',
                                    style: AppTheme.labelSmall.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                                    style: AppTheme.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _updatePromotion,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space24,
              vertical: AppTheme.space12,
            ),
          ),
          child: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}