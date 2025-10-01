import 'package:flutter/material.dart';
import 'business_auth_page.dart'; // Import the new file
import 'home_page.dart'; // Import the new file

// A StatefulWidget is needed to manage the loading state
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  bool _isLoadingExplore = false;
  bool _isLoadingBusiness = false;

  // Define the new storyboard colors
  static const Color primaryGreen = Color(0xFF1B5E20); // A dark forest green
  static const Color secondaryGreen = Color(0xFF4CAF50); // A brighter green for accents

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Set the background color to match the storyboard
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // MamFood Hub Logo
              Image.asset('assets/logo.png', height: 120),
              const SizedBox(height: 32),

              const Text(
                'Explore Mambusao',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen, // Use the new primary green color
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your Mambusao food trip starts here.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Button to navigate to the Home Page
              ElevatedButton(
                onPressed: _isLoadingExplore ? null : () async {
                  setState(() {
                    _isLoadingExplore = true;
                  });
                  // Simulate a delay for a smoother user experience
                  await Future.delayed(const Duration(milliseconds: 500)); 
                  
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HomePage()),
                    );
                  }
                  
                  // Reset loading state after navigation
                  if (mounted) {
                    setState(() {
                      _isLoadingExplore = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen, // Use the new primary green color
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoadingExplore
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        'Explore Mambusao',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 16),

              // Button for business owners
              TextButton(
                onPressed: _isLoadingBusiness ? null : () async {
                  setState(() {
                    _isLoadingBusiness = true;
                  });
                  await Future.delayed(const Duration(milliseconds: 500));

                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const BusinessAuthPage()),
                    );
                  }
                  
                  if (mounted) {
                    setState(() {
                      _isLoadingBusiness = false;
                    });
                  }
                },
                child: _isLoadingBusiness
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: primaryGreen, // Use the new primary green color
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'I am a business owner',
                        style: TextStyle(
                          color: primaryGreen, // Use the new primary green color
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
