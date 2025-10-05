// lib/config/app_config.dart

/// Central configuration file for MamFood Hub
/// 
/// This file contains ALL configuration values for the app:
/// - API keys and credentials
/// - Feature flags (turn features on/off)
/// - App constants
/// 
/// Why do this?
/// - Change a value once, it updates everywhere
/// - Easy to find all settings
/// - No duplicate code
class AppConfig {
  // Private constructor prevents creating instances of this class
  // We only use it for static values: AppConfig.cloudinaryCloudName
  AppConfig._();

  // ==================== APP INFO ====================
  static const String appName = 'MamFood Hub';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Discover the best food in Mambusao, Capiz';

  // ==================== CLOUDINARY CONFIG ====================
  // Image upload service credentials
  static const String cloudinaryCloudName = 'dxjamzv0t';
  static const String cloudinaryUploadPreset = 'mamfoodhub_unsigned';
  
  // Cloudinary folders for organizing uploads
  static const String cloudinaryEstablishmentFolder = 'establishment_logos';
  static const String cloudinaryMenuItemFolder = 'menu_items';
  
  // Build the full API URL
  static const String cloudinaryApiUrl = 
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload';

  // ==================== FEATURE FLAGS ====================
  // These control what features are available in the app
  
  /// Allow users to browse without creating an account
  /// Set to false to require login for everything
  static const bool enableAnonymousBrowsing = true;
  
  /// Enable offline data caching
  /// Users can view previously loaded data without internet
  static const bool enableOfflineMode = true;
  
  /// Show debug information in the app
  /// Set to false before releasing to users
  static const bool enableDebugMode = true;
  
  /// Require admin approval for new business registrations
  /// Set to false to auto-approve all businesses
  static const bool requireBusinessApproval = true;

  // ==================== APP LIMITS ====================
  // Control data limits and restrictions
  
  /// Maximum file size for image uploads (in bytes)
  /// 5MB = 5 * 1024 * 1024 bytes
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5MB
  
  /// Maximum number of menu items per establishment
  static const int maxMenuItemsPerEstablishment = 100;
  
  /// Minimum rating value
  static const double minRating = 0.5;
  
  /// Maximum rating value
  static const double maxRating = 5.0;

  // ==================== FIRESTORE COLLECTION NAMES ====================
  // Keep collection names consistent across the app
  
  static const String businessesCollection = 'businesses';
  static const String establishmentsCollection = 'establishments';
  static const String menuItemsCollection = 'menuItems';
  static const String reviewsCollection = 'reviews';
  static const String usersCollection = 'users';
  static const String bookmarksCollection = 'bookmarks';

  static const String menuItemsSubcollection = 'menuItems';
  static const String reviewsSubcollection = 'reviews';
  static const String bookmarksSubcollection = 'bookmarks';
  
  // ==================== HELPER METHODS ====================
  
  /// Check if an image file size is within limits
  static bool isValidImageSize(int fileSizeBytes) {
    return fileSizeBytes <= maxImageSizeBytes;
  }
  
  /// Get human-readable image size limit
  static String get maxImageSizeFormatted {
    final mb = maxImageSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)}MB';
  }
  
  /// Check if a rating is valid
  static bool isValidRating(double rating) {
    return rating >= minRating && rating <= maxRating;
  }
}