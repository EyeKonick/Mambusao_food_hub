import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'establishments_page.dart';
import 'menu_items_page.dart';

class BusinessDashboardPage extends StatefulWidget {
  const BusinessDashboardPage({super.key});

  @override
  _BusinessDashboardPageState createState() => _BusinessDashboardPageState();
}

class _BusinessDashboardPageState extends State<BusinessDashboardPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  String _currentBusinessName = 'Loading...';

  static const Color primaryGreen = Color(0xFF1B5E20); // A dark forest green
  static const Color secondaryGreen = Color(0xFF4CAF50);
  static const Color accentColor = Color(0xFF00C853);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color backgroundColor = Color(0xFFF0F0F0);

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _fetchBusinessData();
    }
  }

  Future<void> _fetchBusinessData() async {
    try {
      DocumentSnapshot businessDoc = await _firestore.collection('businesses').doc(_currentUser!.uid).get();
      if (businessDoc.exists) {
        setState(() {
          _currentBusinessName = (businessDoc.data() as Map<String, dynamic>)['businessName'] ?? 'No Name';
        });
      }
    } catch (e) {
      print('Error fetching business data: $e');
      setState(() {
        _currentBusinessName = 'Error loading name';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Dashboard: $_currentBusinessName'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(
                color: primaryGreen,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.business, size: 40, color: primaryGreen),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _currentBusinessName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _currentUser?.email ?? 'N/A',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerTile(Icons.home, 'Dashboard', () => Navigator.pop(context)),
            _buildDrawerTile(Icons.store, 'My Establishments', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EstablishmentsPage()),
              );
            }),
            _buildDrawerTile(Icons.fastfood, 'My Menu Items', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MenuItemsPage()),
              );
            }),
            _buildDrawerTile(Icons.reviews, 'Customer Reviews', () {
              Navigator.pop(context);
              // TODO: Navigate to reviews page
            }),
            _buildDrawerTile(Icons.analytics, 'Analytics', () {
              Navigator.pop(context);
              // TODO: Navigate to analytics page
            }),
            const Divider(),
            _buildDrawerTile(Icons.logout, 'Logout', () async {
              await _auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/');
            }),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Overview',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0, // Make cards square
                children: <Widget>[
                  _buildDashboardCard(
                    icon: Icons.visibility,
                    label: 'Total Views',
                    subLabel: '0,000', // Placeholder data
                    onTap: () {
                      // TODO: Navigate to views analytics
                    },
                  ),
                  _buildDashboardCard(
                    icon: Icons.bookmark,
                    label: 'Bookmarks',
                    subLabel: '000', // Placeholder data
                    onTap: () {
                      // TODO: Navigate to bookmarks list
                    },
                  ),
                  _buildDashboardCard(
                    icon: Icons.store,
                    label: 'My Establishments',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EstablishmentsPage()),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    icon: Icons.fastfood,
                    label: 'My Menu Items',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MenuItemsPage()),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    icon: Icons.reviews,
                    label: 'Customer Reviews',
                    onTap: () {
                      // TODO: Navigate to reviews page
                    },
                  ),
                  _buildDashboardCard(
                    icon: Icons.analytics,
                    label: 'Analytics',
                    onTap: () {
                      // TODO: Navigate to analytics page
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: primaryGreen),
      title: Text(title),
      onTap: onTap,
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String label,
    String? subLabel,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: primaryGreen),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              if (subLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  subLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accentColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
