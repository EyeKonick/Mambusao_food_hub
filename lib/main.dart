// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'business_dashboard.dart';

// Import our configuration files
import 'firebase_options.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';

// Import pages
import 'explore.dart';
import 'business_auth_page.dart';
import 'user_auth_page.dart';
import 'user_profile_page.dart';
import 'admin_dashboard_page.dart';

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
    
    // STEP 2: Configure Firestore Offline Support
    if (AppConfig.enableOfflineMode) {
      await _configureFirestore();
    }
    
    // STEP 3: Check current auth state (DON'T create anonymous user automatically)
    // Only log the current state, don't sign in
    await _checkAuthState();
    
    _logSuccess('App initialization complete');
    
  } catch (e) {
    _logError('Critical initialization error: $e');
    // App will still run, but some features may not work
  }
}

/// Check current authentication state WITHOUT auto-signing in
/// 
/// This just logs the state for debugging purposes.
/// Anonymous users will be created on-demand when needed.
Future<void> _checkAuthState() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      _logInfo('No user signed in (anonymous browsing will work without auth)');
    } else if (currentUser.isAnonymous) {
      _logInfo('Anonymous user active: ${currentUser.uid}');
    } else {
      _logInfo('User signed in: ${currentUser.email ?? currentUser.uid}');
    }
  } catch (e) {
    _logError('Could not check auth state: $e');
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
      theme: ThemeData(
        primaryColor: AppTheme.primaryGreen,
        scaffoldBackgroundColor: AppTheme.surfaceColor,
        appBarTheme: AppBarTheme(
          backgroundColor: AppTheme.primaryGreen,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      initialRoute: '/', // This tells Flutter to start with '/' route
      routes: {
        '/': (context) => const ExplorePage(),
        '/business-auth': (context) => const BusinessAuthPage(),
        '/business-dashboard': (context) => const BusinessDashboardPage(),
        '/user-auth': (context) => const UserAuthPage(),
        '/user-profile': (context) => const UserProfilePage(),
        '/admin-dashboard': (context) => const AdminDashboardPage(),
      },
    );
  }
}