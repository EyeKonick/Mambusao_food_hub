// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import our configuration files
import 'firebase_options.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';

// Import pages
import 'explore.dart';

/// Main entry point of the MamFood Hub application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize all app services
  await _initializeApp();
  
  // Start the Flutter application
  runApp(const MyApp());
}

/// Initialize all app services and configurations
Future<void> _initializeApp() async {
  try {
    // STEP 1: Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _logSuccess('Firebase initialized');
    
    // STEP 2: Configure Firestore Offline Support First
    if (AppConfig.enableOfflineMode) {
      await _configureFirestore();
    }
    
    // STEP 3: Enable Anonymous Browsing (with better error handling)
    if (AppConfig.enableAnonymousBrowsing) {
      await _enableAnonymousBrowsing();
    }
    
    _logSuccess('App initialization complete');
    
  } catch (e) {
    _logError('Critical initialization error: $e');
    // App will still run, but some features may not work
  }
}

/// Enable anonymous browsing for users
/// 
/// This allows users to explore restaurants without creating an account.
/// To bookmark or write reviews, they'll need to create an account.
Future<void> _enableAnonymousBrowsing() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      // No user exists - create an anonymous user
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      _logInfo('Anonymous user created: ${userCredential.user?.uid}');
    } else if (currentUser.isAnonymous) {
      // Anonymous user already exists
      _logInfo('Anonymous user already active: ${currentUser.uid}');
    } else {
      // Real user is signed in
      _logInfo('User signed in: ${currentUser.email ?? currentUser.uid}');
    }
  } on FirebaseAuthException catch (e) {
    // Specific Firebase Auth errors
    if (e.code == 'admin-restricted-operation') {
      _logError('Anonymous auth is disabled in Firebase Console. Please enable it:');
      _logError('Firebase Console → Authentication → Sign-in method → Anonymous → Enable');
    } else {
      _logError('Auth error: ${e.code} - ${e.message}');
    }
  } catch (e) {
    // Other errors
    _logError('Could not enable anonymous browsing: $e');
  }
}

/// Configure Firestore for offline support
Future<void> _configureFirestore() async {
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    _logSuccess('Firestore offline support enabled');
  } catch (e) {
    _logError('Could not configure Firestore: $e');
  }
}

// ==================== LOGGING HELPERS ====================

void _logSuccess(String message) {
  if (AppConfig.enableDebugMode) {
    debugPrint('✅ $message');
  }
}

void _logInfo(String message) {
  if (AppConfig.enableDebugMode) {
    debugPrint('ℹ️  $message');
  }
}

void _logError(String message) {
  if (AppConfig.enableDebugMode) {
    debugPrint('❌ $message');
  }
}

// ==================== APP WIDGET ====================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const ExplorePage(),
      routes: {
        '/explore': (context) => const ExplorePage(),
      },
    );
  }
}