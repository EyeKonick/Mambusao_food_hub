// lib/config/app_theme.dart

import 'package:flutter/material.dart';

/// Central theme configuration for MamFood Hub
/// 
/// This file defines:
/// - All colors used in the app
/// - Text styles
/// - Button styles
/// - Card styles
/// - Input field styles
/// 
/// Why do this?
/// - Consistent look throughout the app
/// - Change design once, updates everywhere
/// - Easy to switch between light/dark themes
class AppTheme {
  // Private constructor - this class is not meant to be instantiated
  AppTheme._();

  // ==================== COLORS ====================
  
  // Primary brand colors (your green theme)
  static const Color primaryGreen = Color(0xFF1B5E20); // Dark forest green
  static const Color secondaryGreen = Color(0xFF4CAF50); // Lighter green
  static const Color accentGreen = Color(0xFF66BB6A); // Even lighter green
  static const Color lightGreen = Color(0xFFC8E6C9); // Very light green (backgrounds)
  
  // Accent colors for specific purposes
  static const Color accentYellow = Color(0xFFFFC107); // For ratings, highlights
  static const Color accentRed = Color(0xFFF44336); // For errors, delete actions
  static const Color accentBlue = Color(0xFF2196F3); // For links, info

  static const Color successGreen = Color(0xFF4CAF50); // For success messages
  static const Color errorRed = Color(0xFFF44336); // For errors
  static const Color warningOrange = Color(0xFFFF9800); // For warnings
  static const Color surfaceColor = Color(0xFFF5F5F5); // For surface backgrounds
  
  // Neutral colors
  static const Color backgroundColor = Color(0xFFF5F5F5); // Light gray background
  static const Color cardBackground = Color(0xFFFFFFFF); // White cards
  static const Color dividerColor = Color(0xFFE0E0E0); // Light gray dividers
  
  // Text colors
  static const Color textPrimary = Color(0xFF212121); // Almost black
  static const Color textSecondary = Color(0xFF757575); // Gray
  static const Color textHint = Color(0xFF9E9E9E); // Light gray
  static const Color textWhite = Color(0xFFFFFFFF); // White

  // ==================== THEME DATA ====================
  
  /// Main theme for the entire app
  static ThemeData get lightTheme {
    return ThemeData(
      // Use Material Design 3 (latest version with better components)
      useMaterial3: true,
      
      // Define color scheme from our colors
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: secondaryGreen,
        tertiary: accentYellow,
        error: accentRed,
        background: backgroundColor,
        surface: cardBackground,
        onPrimary: textWhite, // Text color on primary color
        onSecondary: textWhite, // Text color on secondary color
        onBackground: textPrimary, // Text color on background
        onSurface: textPrimary, // Text color on cards
      ),
      
      // Make UI adapt to screen density
      visualDensity: VisualDensity.adaptivePlatformDensity,
      
      // Font family (you can add custom fonts later)
      fontFamily: 'Roboto',
      
      // ===== APP BAR THEME =====
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: textWhite,
        elevation: 0, // Flat design
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      // ===== CARD THEME =====
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      
      // ===== BUTTON THEMES =====
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: textWhite,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // ===== FLOATING ACTION BUTTON THEME =====
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: textWhite,
        elevation: 6,
      ),
      
      // ===== INPUT FIELD THEME =====
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[200],
        
        // Border when not focused
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        
        // Border when enabled but not focused
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dividerColor, width: 1),
        ),
        
        // Border when focused (user is typing)
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: secondaryGreen, width: 2),
        ),
        
        // Border when there's an error
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentRed, width: 1),
        ),
        
        // Border when focused and has error
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentRed, width: 2),
        ),
        
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        
        // Label and hint text styling
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textHint),
      ),
      
      // ===== ICON THEME =====
      iconTheme: const IconThemeData(
        color: primaryGreen,
        size: 24,
      ),

      
      
      // ===== DIVIDER THEME =====
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 16,
      ),
    );
  }

  // ==================== TEXT STYLES ====================
  // Custom text styles you can use throughout the app

  static const TextStyle titleMedium = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: textPrimary,
);

  static const TextStyle titleSmall= TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w400,
  color: textPrimary,
);
  
  static const TextStyle headingLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  
  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  
  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textHint,
  );
  
  // ==================== CUSTOM DECORATIONS ====================
  
  /// Standard box shadow for cards and elevated elements
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      spreadRadius: 1,
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  /// Subtle shadow for floating elements
  static List<BoxShadow> get lightShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      spreadRadius: 1,
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];
}