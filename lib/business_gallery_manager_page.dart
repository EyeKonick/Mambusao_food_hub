import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'services/gallery_service.dart';
import 'photo_gallery_viewer_page.dart';

class BusinessGalleryManagerPage extends StatefulWidget {
  final String businessId;
  final String businessName;

  const BusinessGalleryManagerPage({
    Key? key,
    required this.businessId,
    required this.businessName,
  }) : super(key: key);

  @override
  State<BusinessGalleryManagerPage> createState() => _BusinessGalleryManagerPageState();
}

class _BusinessGalleryManagerPageState extends State<BusinessGalleryManagerPage> {
  final GalleryService _galleryService = GalleryService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;

  Future<void> _addPhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image == null) return;

    final file = File(image.path);
    final fileSize = await file.length();

    // Validate file size
    if (!AppConfig.isValidImageSize(fileSize)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image too large. Maximum size is ${AppConfig.maxImageSizeBytes ~/ (1024 * 1024)}MB'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Upload to Cloudinary
      final photoUrl = await _galleryService.uploadPhoto(file);

      if (photoUrl == null) {
        throw Exception('Upload failed');
      }

      // Add to Firestore
      final success = await _galleryService.addPhotoToGallery(
        businessId: widget.businessId,
        photoUrl: photoUrl,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo added successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      } else {
        throw Exception('Failed to save photo');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deletePhoto(String photoId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _galleryService.deletePhoto(
      businessId: widget.businessId,
      photoId: photoId,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo deleted successfully'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete photo'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _editCaption(String photoId, String currentCaption) async {
    final controller = TextEditingController(text: currentCaption);
    
    final newCaption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Caption'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter caption (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newCaption == null) return;

    final success = await _galleryService.updateCaption(
      businessId: widget.businessId,
      photoId: photoId,
      caption: newCaption,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Caption updated'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  void _viewFullGallery(List<Map<String, dynamic>> photos, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoGalleryViewerPage(
          businessName: widget.businessName,
          photos: photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Gallery'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _galleryService.getBusinessGallery(widget.businessId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
                  const SizedBox(height: 16),
                  Text('Error loading gallery', style: AppTheme.titleMedium),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final photos = snapshot.data ?? [];

          if (_isUploading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading photo...'),
                ],
              ),
            );
          }

          if (photos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library, size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No photos yet', style: AppTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Add photos to showcase your business', style: AppTheme.bodyMedium),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _addPhoto,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add First Photo'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Photo count header
              Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.surfaceColor,
                child: Row(
                  children: [
                    Icon(Icons.photo_library, color: AppTheme.primaryGreen),
                    const SizedBox(width: 12),
                    Text(
                      '${photos.length} ${photos.length == 1 ? 'Photo' : 'Photos'}',
                      style: AppTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _viewFullGallery(photos, 0),
                      icon: const Icon(Icons.fullscreen),
                      label: const Text('View Gallery'),
                    ),
                  ],
                ),
              ),
              
              // Grid of photos
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    final photoUrl = photo['photoUrl'] as String;
                    final caption = photo['caption'] as String?;
                    final photoId = photo['id'] as String;

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Photo
                          GestureDetector(
                            onTap: () => _viewFullGallery(photos, index),
                            child: Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image, size: 48),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Caption overlay (if exists)
                          if (caption != null && caption.isNotEmpty)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.7),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Text(
                                  caption,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),

                          // Action buttons
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit caption
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    color: Colors.white,
                                    onPressed: () => _editCaption(photoId, caption ?? ''),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Delete
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    color: Colors.red,
                                    onPressed: () => _deletePhoto(photoId),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _isUploading
          ? null
          : FloatingActionButton.extended(
              onPressed: _addPhoto,
              backgroundColor: AppTheme.primaryGreen,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add Photo'),
            ),
    );
  }
}