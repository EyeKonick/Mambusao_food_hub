import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

// Data model to hold establishment dropdown data
class EstablishmentDropdownItem {
  final String id;
  final String name;

  EstablishmentDropdownItem({required this.id, required this.name});
}

class MenuItemsPage extends StatefulWidget {
  const MenuItemsPage({super.key});

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuItemsPage> {
  final _formKey = GlobalKey<FormState>();
  final _menuNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // --- Cloudinary Configuration ---
  static const String CLOUDINARY_CLOUD_NAME = 'dxjamzv0t';
  static const String CLOUDINARY_UPLOAD_PRESET = 'mamfoodhub_unsigned';
  // --------------------------------

  // State for Image Handling
  File? _selectedImage;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  // State for Form Data
  String? _selectedEstablishmentId;
  List<EstablishmentDropdownItem> _establishments = [];

  // Refined Color Palette for a Modern Look
  static const Color primaryGreen = Color(0xFF2E7D32); // Slightly lighter dark green
  static const Color secondaryGreen = Color(0xFF66BB6A); // Soft, prominent green
  static const Color accentYellow = Color(0xFFFFC107); // Accent for price/highlight
  static const Color backgroundColor = Color(0xFFF5F5F5); // Very light background

  @override
  void initState() {
    super.initState();
    _fetchEstablishments();
  }

  @override
  void dispose() {
    _menuNameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- Image Handling Logic ---

  /// Allows the user to pick an image from the gallery.
  Future<void> _pickImage(void Function(void Function())? setStateCallback, {required Function(File?) onImageSelected}) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // Use the provided setState for local dialog state, or default to widget setState
      (setStateCallback ?? setState)(() {
        onImageSelected(File(pickedFile.path));
      });
    }
  }

  /// Uploads the selected image file to Cloudinary.
  Future<String?> _uploadImageToCloudinary(File imageFile, void Function(void Function())? setStateCallback) async {
    // Set the uploading flag
    (setStateCallback ?? setState)(() {
      _isUploading = true;
    });

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/image/upload');

    try {
      var request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = CLOUDINARY_UPLOAD_PRESET;
      request.fields['folder'] = 'menu_items'; // Dedicated folder for menu images

      request.files.add(
        await http.MultipartFile.fromPath(
          'file', // Required field name for Cloudinary
          imageFile.path,
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        final secureUrl = jsonResponse['secure_url'];

        return secureUrl as String;
      } else {
        throw Exception('Cloudinary upload failed: ${response.statusCode}. Response: $responseBody');
      }
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e')),
      );
      print('Cloudinary Error: $e');
      return null;
    } finally {
      // Reset the uploading flag
      (setStateCallback ?? setState)(() {
        _isUploading = false;
      });
    }
  }

  // --- Establishment Fetching Logic ---

  /// Fetches the user's list of establishments to populate the dropdown for linking menu items.
  void _fetchEstablishments() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await _firestore.collection('establishments')
          .where('userId', isEqualTo: userId)
          .get();

      final establishments = snapshot.docs.map((doc) {
        return EstablishmentDropdownItem(
          id: doc.id,
          name: doc.data()['name'] ?? 'Untitled Establishment',
        );
      }).toList();

      setState(() {
        _establishments = establishments;
        // Pre-select the first establishment if available
        if (_establishments.isNotEmpty && _selectedEstablishmentId == null) {
          _selectedEstablishmentId = _establishments.first.id;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load establishments: $e')),
        );
      }
    }
  }

  // --- Form Submission Logic (Add) ---

  void _addMenuItem() async {
    if (_formKey.currentState!.validate() && _selectedEstablishmentId != null) {
      String? finalImageUrl;

      // 1. Upload image if selected
      if (_selectedImage != null) {
        finalImageUrl = await _uploadImageToCloudinary(_selectedImage!, null);
        if (finalImageUrl == null) {
          return;
        }
      }

      // 2. Add data to Firestore in the SUBCOLLECTION
      try {
        final userId = _auth.currentUser!.uid;

        // Path: establishments/{establishmentId}/menuItems
        await _firestore
            .collection('establishments')
            .doc(_selectedEstablishmentId)
            .collection('menuItems') // <-- Now a SUBCOLLECTION
            .add({
          'userId': userId, // Retaining userId for Collection Group query
          'establishmentId': _selectedEstablishmentId,
          'name': _menuNameController.text,
          'price': double.tryParse(_priceController.text) ?? 0.0,
          'description': _descriptionController.text,
          'imageUrl': finalImageUrl, // Store the uploaded URL
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu item added successfully to establishment!')),
        );

        // 3. Clear form and state
        _menuNameController.clear();
        _priceController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedImage = null; // Clear selected image file
        });
      } catch (e) {
        print('!!! FIREBASE WRITE ERROR: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add menu item. Check console for details: $e')),
        );
      }
    } else if (_selectedEstablishmentId == null && _establishments.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an establishment.')),
        );
    } else if (_establishments.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please create an establishment first in the Establishments tab.')),
        );
    }
  }

  // --- Deletion Logic ---

  /// Handles the deletion of a menu item document from Firestore.
  /// Now takes the full DocumentSnapshot to use its reference.
  void _deleteMenuItem(DocumentSnapshot item) async {
    final bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion', style: TextStyle(color: primaryGreen)),
        content: const Text('Are you sure you want to delete this menu item permanently? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: primaryGreen)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmDelete) {
      try {
        // Use the document's direct reference to delete it (full path is known)
        await item.reference.delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu item deleted successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete menu item: $e')),
        );
      }
    }
  }

  // --- Editing Logic ---

  Future<void> _editMenuItem(DocumentSnapshot menuItemDoc) async {
    // Extract existing data
    final data = menuItemDoc.data() as Map<String, dynamic>? ?? {};

    // Controllers for dialog fields
    final nameController = TextEditingController(text: data['name'] as String? ?? '');
    final descriptionController = TextEditingController(text: data['description'] as String? ?? '');
    final priceController = TextEditingController(text: (data['price'] as num? ?? 0.0).toString());

    // State for image handling within the dialog
    File? dialogSelectedImage;
    String? dialogImageUrl = data['imageUrl'] as String?;
    String? dialogEstablishmentId = data['establishmentId'] as String?;
    bool dialogIsUploading = false;
    final dialogFormKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateCallback) {
            return AlertDialog(
              title: const Text('Edit Menu Item', style: TextStyle(color: primaryGreen)),
              content: Form(
                key: dialogFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Establishment Selector
                      DropdownButtonFormField<String>(
                        value: dialogEstablishmentId,
                        decoration: InputDecoration(
                          labelText: 'Select Establishment',
                          labelStyle: TextStyle(color: primaryGreen.withOpacity(0.8), fontWeight: FontWeight.w500),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        ),
                        items: _establishments.map((EstablishmentDropdownItem item) {
                          return DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.name),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setStateCallback(() {
                            dialogEstablishmentId = newValue;
                          });
                        },
                        validator: (value) => value == null ? 'Please select the establishment' : null,
                      ),
                      const SizedBox(height: 16),

                      // Item Name Field
                      _buildTextFormField(
                        controller: nameController,
                        label: 'Item Name',
                        validator: (value) => value!.isEmpty ? 'Enter name' : null,
                      ),
                      const SizedBox(height: 16),

                      // Price Field
                      _buildTextFormField(
                        controller: priceController,
                        label: 'Price',
                        keyboardType: TextInputType.number,
                        validator: (value) => value!.isEmpty || double.tryParse(value) == null ? 'Enter valid price' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Description Field
                      _buildTextFormField(
                        controller: descriptionController,
                        label: 'Description',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),

                      // Image Picker in Dialog
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Item Image',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Preview/Placeholder
                              Container(
                                width: 60, height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: backgroundColor,
                                ),
                                child: dialogSelectedImage != null
                                    ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(dialogSelectedImage!, fit: BoxFit.cover))
                                    : (dialogImageUrl != null && dialogImageUrl!.isNotEmpty
                                        ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(dialogImageUrl!, fit: BoxFit.cover))
                                        : Icon(Icons.photo_library, color: primaryGreen.withOpacity(0.6), size: 30)),
                              ),
                              const SizedBox(width: 10),

                              // Pick/Change Button
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: dialogIsUploading ? null : () => _pickImage(setStateCallback, onImageSelected: (file) {
                                    setStateCallback(() {
                                      dialogSelectedImage = file;
                                      // Clear network URL if a new file is picked
                                      if (file != null) dialogImageUrl = null;
                                    });
                                  }),
                                  icon: const Icon(Icons.edit, size: 20),
                                  label: Text(dialogImageUrl != null || dialogSelectedImage != null ? 'Change' : 'Add Photo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: secondaryGreen,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Remove Button
                              if (dialogImageUrl != null || dialogSelectedImage != null)
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () {
                                    setStateCallback(() {
                                      dialogSelectedImage = null;
                                      dialogImageUrl = null; // Remove the existing image URL
                                    });
                                  },
                                  tooltip: 'Remove Image',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(color: primaryGreen)),
                ),
                ElevatedButton(
                  onPressed: dialogIsUploading ? null : () {
                    if (dialogFormKey.currentState!.validate()) {
                      Navigator.pop(context, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
                  child: dialogIsUploading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      try {
        // 1. Re-upload image if a new one was selected in the dialog
        if (dialogSelectedImage != null) {
          // Use the StatefulWidget's setState for the main progress indicator
          dialogImageUrl = await _uploadImageToCloudinary(dialogSelectedImage!, null);
          if (dialogImageUrl == null) {
            // Upload failed, stop update.
            return;
          }
        }
        
        // Check if the establishment changed
        if (dialogEstablishmentId != data['establishmentId']) {
          // 1. Delete the old document in the old subcollection
          await menuItemDoc.reference.delete();

          // 2. Create a new document in the new establishment's subcollection
          final userId = _auth.currentUser!.uid;
          await _firestore
              .collection('establishments')
              .doc(dialogEstablishmentId)
              .collection('menuItems')
              .add({
                // Copy necessary fields from original/updated data
                'userId': userId,
                'establishmentId': dialogEstablishmentId, // The new ID
                'name': nameController.text,
                'description': descriptionController.text,
                'price': double.parse(priceController.text),
                'imageUrl': dialogImageUrl,
                'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(), // Preserve timestamp if available
              });
              
        } else {
           // 2. Update data in the current subcollection location using the document's reference
            await menuItemDoc.reference.update({
              'establishmentId': dialogEstablishmentId,
              'name': nameController.text,
              'description': descriptionController.text,
              'price': double.parse(priceController.text),
              'imageUrl': dialogImageUrl, // Update with new/existing/null URL
            });
        }
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu item updated successfully!')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update menu item: $e')),
        );
      }
    }
  }


  // --- UI Helper Widgets (Refined for Modern Look) ---

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Menu Item Image (Optional)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Preview/Placeholder - Larger, prominent placeholder
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15.0),
                border: Border.all(color: primaryGreen.withOpacity(0.3), width: 2),
                color: backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(13.0),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  : Icon(Icons.restaurant_menu_rounded, color: primaryGreen.withOpacity(0.6), size: 40),
            ),
            const SizedBox(width: 16),

            // 2. Pick/Change Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : () => _pickImage(null, onImageSelected: (file) {
                  setState(() {
                    _selectedImage = file;
                  });
                }),
                icon: Icon(_selectedImage == null ? Icons.add_photo_alternate_rounded : Icons.photo_library_rounded, size: 20),
                label: Text(_selectedImage == null ? 'Select Image' : 'Change Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: secondaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),

            // 3. Clear/Remove Button (Styled as a small action button)
            if (_selectedImage != null && !_isUploading)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedImage = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.red, size: 20),
                  ),
                ),
              ),

            // 4. Loading Indicator
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: primaryGreen, strokeWidth: 3),
                ),
              ),
          ],
        ),
        if (_selectedImage != null && !_isUploading)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 8.0),
            child: Text(
              '${_selectedImage!.path.split('/').last} selected.',
              style: TextStyle(fontSize: 12, color: primaryGreen.withOpacity(0.8)),
            ),
          )
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      // Input formatter for price field to allow only numbers and up to 2 decimals
      inputFormatters: keyboardType == TextInputType.number ? [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ] : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: primaryGreen.withOpacity(0.8), fontWeight: FontWeight.w500),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none, // Hide border when not focused for a cleaner look
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: secondaryGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      ),
      maxLines: maxLines,
      validator: validator,
    );
  }

  /// Custom card widget for displaying a single menu item in the list.
  Widget _buildMenuItemCard({
    required DocumentSnapshot item,
    required String establishmentName,
  }) {
    // Ensure data is correctly interpreted as a Map<String, dynamic>
    final data = item.data() as Map<String, dynamic>? ?? {};
    final imageUrl = data['imageUrl'] as String?;
    final name = data['name'] as String? ?? 'N/A';
    final price = (data['price'] as num? ?? 0.0).toDouble();
    final description = data['description'] as String? ?? 'No description provided.';

    // Modern Card Design with more visual hierarchy
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 6, // Higher elevation for a modern 'pop'
      shadowColor: primaryGreen.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / Placeholder (80x80)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: secondaryGreen.withOpacity(0.1),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              color: primaryGreen,
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image_rounded, color: Colors.red.withOpacity(0.7), size: 30),
                      ),
                    )
                  : Icon(Icons.fastfood_rounded, color: primaryGreen.withOpacity(0.5), size: 40),
            ),

            const SizedBox(width: 16),

            // Item Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '📍 $establishmentName',
                    style: TextStyle(fontSize: 12, color: primaryGreen.withOpacity(0.8), fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

            // Price and Action Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentYellow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₱${price.toStringAsFixed(2)}', // Changed to Peso sign
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit Button
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: primaryGreen, size: 24),
                      onPressed: () => _editMenuItem(item),
                      tooltip: 'Edit Menu Item',
                    ),
                    // Delete Button
                    IconButton(
                      icon: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
                      onPressed: () => _deleteMenuItem(item), // <-- Pass the DocumentSnapshot
                      tooltip: 'Delete Menu Item',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    // Check if user is logged in
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text(
              'You must be signed in to manage menu items.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: primaryGreen),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Manage Menu Items'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // --- Add Menu Item Form (Modern Card) ---
            Card(
              elevation: 8,
              shadowColor: primaryGreen.withOpacity(0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Add a New Menu Item',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryGreen),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Establishment Selector
                      DropdownButtonFormField<String>(
                        value: _selectedEstablishmentId,
                        decoration: InputDecoration(
                          labelText: _establishments.isEmpty ? 'No Establishments Found' : 'Select Establishment',
                          labelStyle: TextStyle(color: primaryGreen.withOpacity(0.8), fontWeight: FontWeight.w500),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: secondaryGreen, width: 2)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        ),
                        items: _establishments.map((EstablishmentDropdownItem item) {
                          return DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.name),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedEstablishmentId = newValue;
                          });
                        },
                        validator: (value) => value == null ? 'Please select the parent establishment' : null,
                        hint: const Text('Select Establishment'),
                        disabledHint: const Text('Loading establishments...'),
                      ),
                      const SizedBox(height: 16),

                      _buildTextFormField(
                        controller: _menuNameController,
                        label: 'Menu Item Name',
                        validator: (value) => value!.isEmpty ? 'Please enter the item name' : null,
                      ),
                      const SizedBox(height: 16),

                      _buildTextFormField(
                        controller: _priceController,
                        label: 'Price (e.g., ₱9.99)', // Changed label text to use Peso sign
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value!.isEmpty) return 'Please enter a price';
                          if (double.tryParse(value) == null) return 'Invalid price format';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildTextFormField(
                        controller: _descriptionController,
                        label: 'Description',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),

                      // Image Picker Widget
                      _buildImagePicker(),

                      const SizedBox(height: 30),

                      ElevatedButton(
                        onPressed: _isUploading || _establishments.isEmpty ? null : _addMenuItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 6,
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        child: _isUploading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_establishments.isEmpty ? 'No Establishments to Add To' : 'Add Menu Item'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            Text(
              'Current Menu Items',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: primaryGreen),
              textAlign: TextAlign.center,
            ),
            const Divider(color: secondaryGreen, thickness: 2, height: 20),
            const SizedBox(height: 10),

            // --- Menu Items List (Using Custom Cards) ---
            StreamBuilder<QuerySnapshot>(
              // *** COLLECTION GROUP QUERY: Fetches all documents named 'menuItems'
              //     across the entire database, then filters by the current user's ID.
              // NOTE: This requires a Firestore Collection Group Index for 'menuItems' 
              //       queried on 'userId' to be created in your Firebase console.
              stream: _auth.currentUser != null
                  ? _firestore.collectionGroup('menuItems')
                      .where('userId', isEqualTo: _auth.currentUser!.uid)
                      .snapshots()
                  : const Stream.empty(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.only(top: 30.0),
                    child: CircularProgressIndicator(color: primaryGreen),
                  ));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading items: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 30.0),
                      child: Text('You haven\'t added any menu items yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    )
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final item = snapshot.data!.docs[index];
                    // Explicitly cast data for safety
                    final data = item.data() as Map<String, dynamic>? ?? {};

                    // Try to find the establishment name using the establishmentId stored in the item
                    final establishmentName = _establishments.firstWhere(
                      (est) => est.id == data['establishmentId'],
                      orElse: () => EstablishmentDropdownItem(id: '', name: 'Unknown Establishment'),
                    ).name;

                    return _buildMenuItemCard(
                      item: item,
                      establishmentName: establishmentName,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
