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
              const SnackBar(
                content: Text('✓ Promotion created successfully!'),
                backgroundColor: AppTheme.successGreen,
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
              const SnackBar(
                content: Text('✓ Promotion updated successfully!'),
                backgroundColor: AppTheme.successGreen,
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
          content: Text(
            newStatus
                ? '✓ Promotion activated'
                : 'Promotion deactivated',
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _deletePromotion(Promotion promotion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Promotion'),
        content: Text(
          'Are you sure you want to delete "${promotion.title}"? This action cannot be undone.',
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
          const SnackBar(
            content: Text('✓ Promotion deleted'),
            backgroundColor: AppTheme.successGreen,
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
    
    if (isExpired) {
      statusColor = AppTheme.textSecondary;
      statusText = 'EXPIRED';
    } else if (isScheduled) {
      statusColor = AppTheme.accentBlue;
      statusText = 'SCHEDULED';
    } else if (!promotion.isActive) {
      statusColor = AppTheme.warningOrange;
      statusText = 'INACTIVE';
    } else {
      statusColor = AppTheme.successGreen;
      statusText = 'ACTIVE';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.local_offer,
            color: statusColor,
          ),
        ),
        title: Text(
          promotion.title,
          style: AppTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusText,
                style: AppTheme.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isScheduled
                  ? 'Starts in ${promotion.startDate.difference(now).inDays} days'
                  : isExpired
                      ? 'Ended ${now.difference(promotion.endDate).inDays} days ago'
                      : '${promotion.daysRemaining} days remaining',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Text(
                  'Description',
                  style: AppTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  promotion.description,
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: 16),

                // Dates
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Date',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End Date',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${promotion.endDate.day}/${promotion.endDate.month}/${promotion.endDate.year}',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

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
                          ),
                          label: Text(
                            promotion.isActive ? 'Deactivate' : 'Activate',
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    
                    // Edit
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditPromotionDialog(promotion),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Delete
                    IconButton(
                      onPressed: () => _deletePromotion(promotion),
                      icon: const Icon(Icons.delete),
                      color: AppTheme.errorRed,
                      tooltip: 'Delete promotion',
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
        appBar: AppBar(
          title: const Text('Promotions'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryGreen),
              const SizedBox(height: 16),
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
      appBar: AppBar(
        title: const Text('Promotions'),
      ),
      body: StreamBuilder<List<Promotion>>(
        stream: _promotionService.getBusinessPromotions(_businessId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.errorRed,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading promotions',
                    style: AppTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            );
          }

          final promotions = snapshot.data ?? [];

          if (promotions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_offer,
                    size: 80,
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No promotions yet',
                    style: AppTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first promotion to attract customers',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showCreatePromotionDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Promotion'),
                  ),
                ],
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
            padding: const EdgeInsets.all(16),
            children: [
              // Stats Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overview',
                        style: AppTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatItem(
                            'Active',
                            activePromotions.length.toString(),
                            AppTheme.successGreen,
                          ),
                          _buildStatItem(
                            'Scheduled',
                            scheduledPromotions.length.toString(),
                            AppTheme.accentBlue,
                          ),
                          _buildStatItem(
                            'Inactive',
                            inactivePromotions.length.toString(),
                            AppTheme.warningOrange,
                          ),
                          _buildStatItem(
                            'Expired',
                            expiredPromotions.length.toString(),
                            AppTheme.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Active Promotions
              if (activePromotions.isNotEmpty) ...[
                Text(
                  'Active (${activePromotions.length})',
                  style: AppTheme.titleMedium.copyWith(
                    color: AppTheme.successGreen,
                  ),
                ),
                const SizedBox(height: 8),
                ...activePromotions.map(_buildPromotionCard),
                const SizedBox(height: 16),
              ],

              // Scheduled Promotions
              if (scheduledPromotions.isNotEmpty) ...[
                Text(
                  'Scheduled (${scheduledPromotions.length})',
                  style: AppTheme.titleMedium.copyWith(
                    color: AppTheme.accentBlue,
                  ),
                ),
                const SizedBox(height: 8),
                ...scheduledPromotions.map(_buildPromotionCard),
                const SizedBox(height: 16),
              ],

              // Inactive Promotions
              if (inactivePromotions.isNotEmpty) ...[
                Text(
                  'Inactive (${inactivePromotions.length})',
                  style: AppTheme.titleMedium.copyWith(
                    color: AppTheme.warningOrange,
                  ),
                ),
                const SizedBox(height: 8),
                ...inactivePromotions.map(_buildPromotionCard),
                const SizedBox(height: 16),
              ],

              // Expired Promotions
              if (expiredPromotions.isNotEmpty) ...[
                Text(
                  'Expired (${expiredPromotions.length})',
                  style: AppTheme.titleMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ...expiredPromotions.map(_buildPromotionCard),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePromotionDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Promotion'),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.headingLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
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
        const SnackBar(
          content: Text('Please select start and end dates'),
          backgroundColor: AppTheme.warningOrange,
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
      title: const Text('Create Promotion'),
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
                decoration: const InputDecoration(
                  labelText: 'Promotion Title *',
                  hintText: 'e.g., Buy 1 Take 1',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Describe your promotion',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Start Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Start Date'),
                subtitle: Text(
                  _startDate != null
                      ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                      : 'Not selected',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectStartDate,
              ),

              // End Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('End Date'),
                subtitle: Text(
                  _endDate != null
                      ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                      : 'Not selected',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectEndDate,
              ),

              const SizedBox(height: 16),

              // Image Picker
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _pickImage,
                icon: Icon(_selectedImage != null ? Icons.check_circle : Icons.image),
                label: Text(_selectedImage != null ? 'Image Selected' : 'Add Image (Optional)'),
              ),

              if (_selectedImage != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImage!,
                    height: 150,
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
      title: const Text('Edit Promotion'),
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
                decoration: const InputDecoration(
                  labelText: 'Promotion Title *',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Start Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Start Date'),
                subtitle: Text(
                  '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectStartDate,
              ),

              // End Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('End Date'),
                subtitle: Text(
                  '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectEndDate,
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