import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class EstablishmentsPage extends StatefulWidget {
  const EstablishmentsPage({super.key});

  @override
  _EstablishmentsPageState createState() => _EstablishmentsPageState();
}

class _EstablishmentsPageState extends State<EstablishmentsPage> {
  final _formKey = GlobalKey<FormState>();
  final _establishmentNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // --- Cloudinary Configuration (MUST BE REPLACED) ---
  // IMPORTANT: Replace these placeholders with your actual Cloudinary credentials
  static const String CLOUDINARY_CLOUD_NAME = 'dxjamzv0t'; 
  static const String CLOUDINARY_UPLOAD_PRESET = 'mamfoodhub_unsigned';
  // ---------------------------------------------------

  // State for Image Handling
  File? _selectedImage;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color secondaryGreen = Color(0xFF4CAF50);
  static const Color backgroundColor = Color(0xFFF0F0F0);

  static const List<String> _categories = [
    'Tea & coffee',
    'bakery',
    'Carinderia',
    'Pizzeria',
    'Casual Dining',
    'Fast Food'
  ];

  String? _selectedCategory;

  @override
  void dispose() {
    _establishmentNameController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    _descriptionController.dispose();
    // No need to dispose _selectedImage as it's not a framework resource
    super.dispose();
  }

  // --- IMAGE PICKING & UPLOAD LOGIC ---

  Future<void> _pickImage(void Function(void Function())? setStateCallback, {required Function(File?) onImageSelected}) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // Use the provided setState for local dialog state, or default to widget setState
      (setStateCallback ?? setState)(() {
        onImageSelected(File(pickedFile.path));
      });
    }
  }

  Future<String?> _uploadImageToCloudinary(File imageFile, void Function(void Function())? setStateCallback) async {
    if (CLOUDINARY_CLOUD_NAME == 'YOUR_CLOUD_NAME') {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ERROR: Cloudinary credentials not configured. Cannot upload image.')),
      );
      return null;
    }

    (setStateCallback ?? setState)(() {
      _isUploading = true;
    });

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/image/upload');

    try {
      var request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = CLOUDINARY_UPLOAD_PRESET;
      request.fields['folder'] = 'establishment_logos';

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
      (setStateCallback ?? setState)(() {
        _isUploading = false;
      });
    }
  }
  
  // --- END IMAGE LOGIC ---

  void _addEstablishment() async {
    if (_formKey.currentState!.validate()) {
      String? finalLogoUrl;

      // 1. Upload image if selected
      if (_selectedImage != null) {
        // Pass null for setStateCallback to use the widget's setState
        finalLogoUrl = await _uploadImageToCloudinary(_selectedImage!, null); 
        if (finalLogoUrl == null) {
          // Upload failed, halt process
          return;
        }
      }

      // 2. Add data to Firestore
      try {
        final userId = _auth.currentUser!.uid;
        await _firestore.collection('establishments').add({
          'userId': userId,
          'name': _establishmentNameController.text,
          'address': _addressController.text,
          'category': _selectedCategory,
          'contactNumber': _contactNumberController.text,
          'description': _descriptionController.text,
          'logoUrl': finalLogoUrl, // Store the URL
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Establishment added successfully!')),
        );

        // 3. Clear form and state
        _establishmentNameController.clear();
        _addressController.clear();
        _contactNumberController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedCategory = null;
          _selectedImage = null; // Clear selected image file
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add establishment: $e')),
        );
      }
    }
  }

  void _deleteEstablishment(String docId) async {
    final bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this establishment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmDelete) {
      try {
        await _firestore.collection('establishments').doc(docId).delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Establishment deleted successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete establishment: $e')),
        );
      }
    }
  }

  void _editEstablishment(String docId, Map<String, dynamic> currentData) {
    final TextEditingController nameController = TextEditingController(text: currentData['name']);
    final TextEditingController addressController = TextEditingController(text: currentData['address']);
    final TextEditingController contactController = TextEditingController(text: currentData['contactNumber']);
    final TextEditingController descriptionController = TextEditingController(text: currentData['description']);
    String? tempCategory = currentData['category'];
    
    // Use an object to hold the logo state within the dialog
    // 1. Existing URL
    // 2. Newly selected file
    // 3. Flag to explicitly remove the logo
    String? tempCurrentLogoUrl = currentData['logoUrl'];
    File? tempSelectedImage; 
    bool tempRemoveLogo = false; // Flag to indicate intent to remove logo

    bool tempIsUploading = false; // Upload state local to dialog

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            
            // Determine what to display as the current logo: 
            // 1. New selected image (highest priority)
            // 2. Existing URL (if not set to be removed)
            final String? previewUrl = tempSelectedImage != null 
                ? null // Preview the local file
                : (tempRemoveLogo ? null : tempCurrentLogoUrl); // Show URL unless marked for removal

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text('Edit Establishment', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Form(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextFormField(controller: nameController, label: 'Name'),
                      const SizedBox(height: 12),
                      _buildTextFormField(controller: addressController, label: 'Address'),
                      const SizedBox(height: 12),
                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: tempCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(color: primaryGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: secondaryGreen, width: 2)),
                        ),
                        items: _categories.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setStateInDialog(() {
                            tempCategory = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextFormField(controller: contactController, label: 'Contact Number'),
                      const SizedBox(height: 12),
                      _buildTextFormField(controller: descriptionController, label: 'Description', maxLines: 3),
                      const SizedBox(height: 16),

                      // --- REFINED Image Picker in Edit Dialog ---
                      Text('Logo', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. Preview/Placeholder
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: primaryGreen.withOpacity(0.5)),
                              color: backgroundColor,
                            ),
                            child: tempSelectedImage != null 
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.file(tempSelectedImage!, fit: BoxFit.cover),
                                  )
                                : (previewUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8.0),
                                        child: Image.network(
                                          previewUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Icon(Icons.storefront, color: secondaryGreen, size: 30),
                                        ),
                                      )
                                    : Icon(Icons.storefront, color: primaryGreen, size: 30)),
                          ),
                          const SizedBox(width: 12),
                          
                          // 2. Pick/Change Button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: tempIsUploading ? null : () async {
                                await _pickImage(setStateInDialog, onImageSelected: (file) {
                                  // When a new image is picked, clear the 'remove' flag
                                  tempSelectedImage = file;
                                  tempRemoveLogo = false; 
                                });
                              },
                              icon: Icon(tempSelectedImage != null || previewUrl != null ? Icons.photo_library : Icons.add_photo_alternate),
                              label: Text(tempSelectedImage != null ? 'Change' : (previewUrl != null ? 'Replace Logo' : 'Upload Logo')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: secondaryGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          
                          // 3. Clear/Remove Button
                          if (tempSelectedImage != null || previewUrl != null) 
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.red),
                                onPressed: () {
                                  setStateInDialog(() {
                                    tempSelectedImage = null; // Clear selected file
                                    tempRemoveLogo = true; // Mark existing URL for removal
                                  });
                                },
                              ),
                            ),

                          // 4. Loading Indicator
                          if (tempIsUploading)
                            const Padding(
                              padding: EdgeInsets.only(left: 16.0),
                              child: CircularProgressIndicator(color: primaryGreen),
                            ),
                        ],
                      ),
                      // --- End REFINED Image Picker ---
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: secondaryGreen,
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: tempIsUploading ? null : () async {
                    String? finalLogoUrl = tempCurrentLogoUrl;

                    // 1. Handle image upload/removal logic
                    if (tempRemoveLogo) {
                        finalLogoUrl = null; // Set to null to remove it from Firestore
                    } else if (tempSelectedImage != null) {
                      setStateInDialog(() { tempIsUploading = true; });
                      
                      // Upload the new image.
                      final resultUrl = await _uploadImageToCloudinary(tempSelectedImage!, setStateInDialog);
                      
                      // The finally block in _uploadImageToCloudinary will set tempIsUploading = false
                      if (resultUrl == null) {
                        return; // Upload failed, stay in dialog
                      }
                      finalLogoUrl = resultUrl;
                    }

                    // 2. Update Firestore
                    try {
                      await _firestore.collection('establishments').doc(docId).update({
                        'name': nameController.text,
                        'address': addressController.text,
                        'category': tempCategory,
                        'contactNumber': contactController.text,
                        'description': descriptionController.text,
                        'logoUrl': finalLogoUrl, // Update the URL (can be null)
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Establishment updated successfully!')),
                        );
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update establishment: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Widget for image selection in the main 'Add' form
  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Establishment Logo (Optional)', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            // 1. Preview/Placeholder
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: primaryGreen.withOpacity(0.5)),
                color: backgroundColor,
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  : Icon(Icons.storefront, color: primaryGreen, size: 30),
            ),
            const SizedBox(width: 12),
            
            // 2. Pick/Change Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : () => _pickImage(null, onImageSelected: (file) {
                  _selectedImage = file;
                }), // Use main setState
                icon: Icon(_selectedImage == null ? Icons.add_photo_alternate : Icons.photo_library),
                label: Text(_selectedImage == null ? 'Select Logo' : 'Change Logo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: secondaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            
            // 3. Clear/Remove Button (NEW)
            if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _selectedImage = null;
                    });
                  },
                ),
              ),
              
            // 4. Loading Indicator
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: CircularProgressIndicator(color: primaryGreen),
              ),
          ],
        ),
        if (_selectedImage != null && !_isUploading)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'File selected: ${_selectedImage!.path.split('/').last}',
              style: TextStyle(fontSize: 12, color: primaryGreen),
            ),
          )
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('My Establishments'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Add a New Food Establishment',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      _buildTextFormField(
                        controller: _establishmentNameController,
                        label: 'Establishment Name',
                        validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextFormField(
                        controller: _addressController,
                        label: 'Address',
                        validator: (value) => value!.isEmpty ? 'Please enter the address' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(color: primaryGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: secondaryGreen, width: 2)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        ),
                        items: _categories.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        },
                        validator: (value) => value == null ? 'Please select a category' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextFormField(
                        controller: _contactNumberController,
                        label: 'Contact Number',
                      ),
                      const SizedBox(height: 12),
                      _buildTextFormField(
                        controller: _descriptionController,
                        label: 'Description',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      // --- NEW: Image Picker Widget ---
                      _buildImagePicker(),
                      // --- END NEW ---
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isUploading ? null : _addEstablishment, // Disable button while uploading
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isUploading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Add Establishment', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Your Establishments',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryGreen),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _auth.currentUser != null
                  ? _firestore.collection('establishments').where('userId', isEqualTo: _auth.currentUser!.uid).snapshots()
                  : const Stream.empty(),
              builder: (context, snapshot) {
                if (_auth.currentUser == null) {
                  return const Center(child: Text('Please sign in to view your establishments.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No establishments added yet.'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final establishment = snapshot.data!.docs[index];
                    final data = establishment.data() as Map<String, dynamic>;
                    final logoUrl = data['logoUrl'] as String?;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        // --- Display Image from URL ---
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                            color: logoUrl != null ? Colors.transparent : secondaryGreen.withOpacity(0.1),
                          ),
                          child: logoUrl != null && logoUrl.isNotEmpty
                              ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.network(
                                      logoUrl,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                      },
                                      errorBuilder: (context, error, stackTrace) => Icon(Icons.storefront, color: primaryGreen, size: 30),
                                    ),
                                )
                              : Icon(Icons.storefront, color: primaryGreen, size: 30),
                        ),
                        // --- END DISPLAY ---
                        title: Text(data['name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${data['category'] ?? 'Uncategorized'}\n${data['address'] ?? 'N/A'}'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: secondaryGreen),
                              onPressed: () => _editEstablishment(establishment.id, data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteEstablishment(establishment.id),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: primaryGreen),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: secondaryGreen, width: 2)),
      ),
      maxLines: maxLines,
      validator: validator,
    );
  }
}