import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/app_config.dart';
import 'config/app_theme.dart';

class MenuItemsPage extends StatefulWidget {
  const MenuItemsPage({super.key});

  @override
  State<MenuItemsPage> createState() => _MenuItemsPageState();
}

class _MenuItemsPageState extends State<MenuItemsPage> with SingleTickerProviderStateMixin {
  // ==================== FIREBASE INSTANCES ====================
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== TAB CONTROLLER ====================
  late TabController _tabController;

  // ==================== STATE VARIABLES ====================
  String _businessId = '';
  String _businessName = 'Loading...';
  bool _isLoading = true;
  String? _errorMessage;

  // Category filter
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Appetizer',
    'Main Course',
    'Dessert',
    'Beverage',
    'Snack'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializePage();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==================== INITIALIZATION ====================
  Future<void> _initializePage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      _businessId = user.uid;

      // Fetch business data
      final businessDoc = await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(_businessId)
          .get();

      if (!businessDoc.exists) {
        throw Exception('Business not found');
      }

      final data = businessDoc.data() as Map<String, dynamic>;
      
      setState(() {
        _businessName = data['businessName'] ?? 'Unnamed Business';
        _isLoading = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✓ Menu page initialized for: $_businessName');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load business data: $e';
        _isLoading = false;
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error initializing menu page: $e');
      }
    }
  }

  // ==================== CLOUDINARY IMAGE UPLOAD ====================
  Future<String?> _uploadImageToCloudinary(
    File imageFile,
    Function(String, double) updateProgress,
  ) async {
    try {
      updateProgress('Preparing upload...', 0.1);

      // Validate file size
      final fileSize = await imageFile.length();
      if (!AppConfig.isValidImageSize(fileSize)) {
        throw Exception(
          'Image too large. Max size: ${AppConfig.maxImageSizeBytes ~/ (1024 * 1024)}MB'
        );
      }

      // Prepare request
      final url = Uri.parse(AppConfig.cloudinaryApiUrl);
      var request = http.MultipartRequest('POST', url);

      // Add required fields
      request.fields['upload_preset'] = AppConfig.cloudinaryUploadPreset;
      request.fields['folder'] = AppConfig.cloudinaryMenuItemFolder;

      updateProgress('Uploading image...', 0.3);

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path)
      );

      // Send request
      final streamedResponse = await request.send();
      updateProgress('Processing...', 0.7);

      // Get response
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final imageUrl = responseData['secure_url'] as String;
        
        updateProgress('Upload complete!', 1.0);
        
        if (AppConfig.enableDebugMode) {
          debugPrint('✓ Image uploaded: $imageUrl');
        }
        
        return imageUrl;
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Cloudinary upload error: $e');
      }
      return null;
    }
  }

  // ==================== ADD MENU ITEM DIALOG ====================
  Future<void> _showAddMenuItemDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    String selectedCategory = 'Main Course';
    File? selectedImage;
    bool isUploading = false;
    String uploadProgress = '';
    double uploadPercentage = 0.0;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.add_circle, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  const Text('Add Menu Item'),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Image Picker
                      GestureDetector(
                        onTap: isUploading
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final pickedFile = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1024,
                                  maxHeight: 1024,
                                );
                                if (pickedFile != null) {
                                  setDialogState(() {
                                    selectedImage = File(pickedFile.path);
                                  });
                                }
                              },
                        child: Container(
                          height: 150,
                          width: double.infinity, 
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryGreen.withOpacity(0.3),
                            ),
                          ),
                          child: selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate,
                                      size: 48,
                                      color: AppTheme.primaryGreen.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to add image',
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name Field
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Item Name',
                          hintText: 'e.g., Chicken Adobo',
                          prefixIcon: Icon(Icons.restaurant_menu),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter item name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description Field
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Describe the dish...',
                          prefixIcon: Icon(Icons.description),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: _categories
                            .where((cat) => cat != 'All')
                            .map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedCategory = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Price Field
                      TextFormField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          hintText: '0.00',
                          prefixIcon: Icon(Icons.attach_money),
                          prefixText: '₱ ',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter price';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price <= 0) {
                            return 'Please enter valid price';
                          }
                          return null;
                        },
                      ),

                      // Upload Progress
                      if (isUploading) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: uploadPercentage,
                          backgroundColor: AppTheme.surfaceColor,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          uploadProgress,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() {
                              isUploading = true;
                            });

                            try {
                              String? imageUrl;

                              // Upload image if selected
                              if (selectedImage != null) {
                                imageUrl = await _uploadImageToCloudinary(
                                  selectedImage!,
                                  (message, progress) {
                                    setDialogState(() {
                                      uploadProgress = message;
                                      uploadPercentage = progress;
                                    });
                                  },
                                );

                                if (imageUrl == null) {
                                  throw Exception('Failed to upload image');
                                }
                              }

                              // Add menu item to Firestore
                              await _firestore
                                  .collection(AppConfig.businessesCollection)
                                  .doc(_businessId)
                                  .collection(AppConfig.menuItemsSubcollection)
                                  .add({
                                'name': nameController.text.trim(),
                                'description': descriptionController.text.trim(),
                                'price': double.parse(priceController.text),
                                'category': selectedCategory,
                                'imageUrl': imageUrl,
                                'isAvailable': true,
                                'createdAt': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              if (!mounted) return;
                              Navigator.pop(dialogContext);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${nameController.text} added successfully!'
                                  ),
                                  backgroundColor: AppTheme.successGreen,
                                ),
                              );
                            } catch (e) {
                              if (AppConfig.enableDebugMode) {
                                debugPrint('✗ Error adding menu item: $e');
                              }

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.errorRed,
                                ),
                              );

                              setDialogState(() {
                                isUploading = false;
                              });
                            }
                          }
                        },
                  child: const Text('Add Item'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== EDIT MENU ITEM DIALOG ====================
  Future<void> _showEditMenuItemDialog(DocumentSnapshot menuItem) async {
    final data = menuItem.data() as Map<String, dynamic>;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: data['name']);
    final descriptionController = TextEditingController(text: data['description']);
    final priceController = TextEditingController(text: data['price'].toString());
    String selectedCategory = data['category'] ?? 'Main Course';
    File? selectedImage;
    String? existingImageUrl = data['imageUrl'];
    bool isUploading = false;
    String uploadProgress = '';
    double uploadPercentage = 0.0;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.edit, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  const Text('Edit Menu Item'),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Image Picker
                      GestureDetector(
                        onTap: isUploading
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final pickedFile = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1024,
                                  maxHeight: 1024,
                                );
                                if (pickedFile != null) {
                                  setDialogState(() {
                                    selectedImage = File(pickedFile.path);
                                  });
                                }
                              },
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryGreen.withOpacity(0.3),
                            ),
                          ),
                          child: selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : existingImageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        existingImageUrl!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate,
                                          size: 48,
                                          color: AppTheme.primaryGreen.withOpacity(0.5),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap to change image',
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name Field
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Item Name',
                          prefixIcon: Icon(Icons.restaurant_menu),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter item name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description Field
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: _categories
                            .where((cat) => cat != 'All')
                            .map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedCategory = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Price Field
                      TextFormField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          prefixIcon: Icon(Icons.attach_money),
                          prefixText: '₱ ',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter price';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price <= 0) {
                            return 'Please enter valid price';
                          }
                          return null;
                        },
                      ),

                      // Upload Progress
                      if (isUploading) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: uploadPercentage,
                          backgroundColor: AppTheme.surfaceColor,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          uploadProgress,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() {
                              isUploading = true;
                            });

                            try {
                              String? imageUrl = existingImageUrl;

                              // Upload new image if selected
                              if (selectedImage != null) {
                                imageUrl = await _uploadImageToCloudinary(
                                  selectedImage!,
                                  (message, progress) {
                                    setDialogState(() {
                                      uploadProgress = message;
                                      uploadPercentage = progress;
                                    });
                                  },
                                );

                                if (imageUrl == null) {
                                  throw Exception('Failed to upload image');
                                }
                              }

                              // Update menu item in Firestore
                              await _firestore
                                  .collection(AppConfig.businessesCollection)
                                  .doc(_businessId)
                                  .collection(AppConfig.menuItemsSubcollection)
                                  .doc(menuItem.id)
                                  .update({
                                'name': nameController.text.trim(),
                                'description': descriptionController.text.trim(),
                                'price': double.parse(priceController.text),
                                'category': selectedCategory,
                                'imageUrl': imageUrl,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              if (!mounted) return;
                              Navigator.pop(dialogContext);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Menu item updated!'),
                                  backgroundColor: AppTheme.successGreen,
                                ),
                              );
                            } catch (e) {
                              if (AppConfig.enableDebugMode) {
                                debugPrint('✗ Error updating menu item: $e');
                              }

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.errorRed,
                                ),
                              );

                              setDialogState(() {
                                isUploading = false;
                              });
                            }
                          }
                        },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== DELETE MENU ITEM ====================
  Future<void> _deleteMenuItem(DocumentSnapshot menuItem) async {
    final data = menuItem.data() as Map<String, dynamic>;
    final itemName = data['name'] ?? 'this item';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Menu Item'),
          content: Text('Are you sure you want to delete "$itemName"?'),
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
        );
      },
    );

    if (confirmed == true) {
      try {
        await _firestore
            .collection(AppConfig.businessesCollection)
            .doc(_businessId)
            .collection(AppConfig.menuItemsSubcollection)
            .doc(menuItem.id)
            .delete();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$itemName" deleted successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      } catch (e) {
        if (AppConfig.enableDebugMode) {
          debugPrint('✗ Error deleting menu item: $e');
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting item: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  // ==================== TOGGLE AVAILABILITY ====================
  Future<void> _toggleAvailability(DocumentSnapshot menuItem) async {
    final data = menuItem.data() as Map<String, dynamic>;
    final currentStatus = data['isAvailable'] ?? true;

    try {
      await _firestore
          .collection(AppConfig.businessesCollection)
          .doc(_businessId)
          .collection(AppConfig.menuItemsSubcollection)
          .doc(menuItem.id)
          .update({
        'isAvailable': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentStatus
                ? 'Item marked as unavailable'
                : 'Item marked as available',
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Error toggling availability: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  // ==================== BUILD MENU ITEM CARD ====================
  Widget _buildMenuItemCard(DocumentSnapshot menuItem) {
    final data = menuItem.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unnamed Item';
    final description = data['description'] ?? 'No description';
    final price = data['price'] ?? 0.0;
    final category = data['category'] ?? 'Uncategorized';
    final imageUrl = data['imageUrl'];
    final isAvailable = data['isAvailable'] ?? true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showEditMenuItemDialog(menuItem),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: AppTheme.surfaceColor,
                            child: Icon(
                              Icons.restaurant,
                              color: AppTheme.primaryGreen,
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: AppTheme.surfaceColor,
                        child: Icon(
                          Icons.restaurant,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: AppTheme.titleMedium.copyWith(
                              decoration: isAvailable
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        if (!isAvailable)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'UNAVAILABLE',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.errorRed,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₱${price.toStringAsFixed(2)}',
                              style: AppTheme.titleMedium.copyWith(
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              category,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isAvailable
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: isAvailable
                                    ? AppTheme.successGreen
                                    : AppTheme.textSecondary,
                              ),
                              onPressed: () => _toggleAvailability(menuItem),
                              tooltip: isAvailable
                                  ? 'Mark as unavailable'
                                  : 'Mark as available',
                            ),
                            IconButton(
                              icon: Icon(Icons.edit, color: AppTheme.primaryGreen),
                              onPressed: () => _showEditMenuItemDialog(menuItem),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: AppTheme.errorRed),
                              onPressed: () => _deleteMenuItem(menuItem),
                              tooltip: 'Delete',
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
    );
  }

  // ==================== BUILD MENU LIST ====================
  Widget _buildMenuList(String category) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(AppConfig.businessesCollection)
          .doc(_businessId)
          .collection(AppConfig.menuItemsSubcollection)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
                const SizedBox(height: 16),
                Text(
                  'Error loading menu items',
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.primaryGreen),
                const SizedBox(height: 16),
                Text(
                  'Loading menu items...',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        // Filter items by category
        var items = snapshot.data!.docs;
        if (category != 'All') {
          items = items.where((item) {
            final data = item.data() as Map<String, dynamic>;
            return data['category'] == category;
          }).toList();
        }

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 64,
                  color: AppTheme.primaryGreen.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  category == 'All'
                      ? 'No menu items yet'
                      : 'No items in $category',
                  style: AppTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the + button to add your first item',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildMenuItemCard(items[index]);
          },
        );
      },
    );
  }

  // ==================== BUILD STATISTICS TAB ====================
  Widget _buildStatisticsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(AppConfig.businessesCollection)
          .doc(_businessId)
          .collection(AppConfig.menuItemsSubcollection)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          );
        }

        final items = snapshot.data!.docs;
        final totalItems = items.length;
        final availableItems = items.where((item) {
          final data = item.data() as Map<String, dynamic>;
          return data['isAvailable'] ?? true;
        }).length;

        // Calculate average price
        double totalPrice = 0;
        for (var item in items) {
          final data = item.data() as Map<String, dynamic>;
          totalPrice += (data['price'] ?? 0.0);
        }
        final averagePrice = totalItems > 0 ? totalPrice / totalItems : 0.0;

        // Count by category
        final Map<String, int> categoryCount = {};
        for (var item in items) {
          final data = item.data() as Map<String, dynamic>;
          final category = data['category'] ?? 'Uncategorized';
          categoryCount[category] = (categoryCount[category] ?? 0) + 1;
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Trigger a rebuild
            setState(() {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview Cards
                Text(
                  'Menu Overview',
                  style: AppTheme.headingMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Items',
                        totalItems.toString(),
                        Icons.restaurant_menu,
                        AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Available',
                        availableItems.toString(),
                        Icons.check_circle,
                        AppTheme.successGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Unavailable',
                        (totalItems - availableItems).toString(),
                        Icons.cancel,
                        AppTheme.errorRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Avg. Price',
                        '₱${averagePrice.toStringAsFixed(2)}',
                        Icons.attach_money,
                        AppTheme.accentYellow,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Category Breakdown
                Text(
                  'Items by Category',
                  style: AppTheme.headingMedium,
                ),
                const SizedBox(height: 16),
                if (categoryCount.isEmpty)
                  Center(
                    child: Text(
                      'No items to display',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  )
                else
                  ...categoryCount.entries.map((entry) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                          child: Icon(
                            _getCategoryIcon(entry.key),
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        title: Text(entry.key),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            entry.value.toString(),
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== BUILD STAT CARD ====================
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTheme.headingMedium.copyWith(
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
      ),
    );
  }

  // ==================== GET CATEGORY ICON ====================
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Appetizer':
        return Icons.soup_kitchen;
      case 'Main Course':
        return Icons.dinner_dining;
      case 'Dessert':
        return Icons.cake;
      case 'Beverage':
        return Icons.local_cafe;
      case 'Snack':
        return Icons.fastfood;
      default:
        return Icons.restaurant;
    }
  }

  // ==================== BUILD METHOD ====================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Menu Items'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryGreen),
              const SizedBox(height: 16),
              Text(
                'Loading menu...',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Menu Items'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: AppTheme.headingMedium,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializePage,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Menu Items'),
            Text(
              _businessName,
              style: AppTheme.bodySmall.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: const [
            Tab(text: 'Menu', icon: Icon(Icons.restaurant_menu)),
            Tab(text: 'Statistics', icon: Icon(Icons.bar_chart)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Category Filter (only show on Menu tab)
          if (_tabController.index == 0)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                      backgroundColor: AppTheme.surfaceColor,
                      selectedColor: AppTheme.primaryGreen,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  );
                },
              ),
            ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMenuList(_selectedCategory),
                _buildStatisticsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddMenuItemDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              backgroundColor: AppTheme.primaryGreen,
            )
          : null,
    );
  }
}