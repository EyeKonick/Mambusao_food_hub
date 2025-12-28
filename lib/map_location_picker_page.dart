import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../config/app_theme.dart';
import '../config/app_config.dart';

/// Interactive map page for selecting business location
/// 
/// Features:
/// - Draggable map with fixed center pin
/// - "Use Current Location" button for GPS
/// - "Confirm Location" returns selected coordinates
class MapLocationPickerPage extends StatefulWidget {
  final LatLng? initialLocation; // ✅ Accept previous location

  const MapLocationPickerPage({
    Key? key,
    this.initialLocation, // ✅ Optional parameter
  }) : super(key: key);

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

class _MapLocationPickerPageState extends State<MapLocationPickerPage> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(11.429878, 122.596657); // Default: Mambusao, Capiz
  bool _isLoadingLocation = false;
  String _locationDescription = 'Mambusao, Capiz';

  @override
  void initState() {
    super.initState();
    
    // ✅ Use initial location if provided, otherwise use default
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
      _locationDescription = 'Previously Selected Location';
      
      if (AppConfig.enableDebugMode) {
        debugPrint('📍 Map opened with previous location:');
        debugPrint('   Lat: ${_selectedLocation.latitude}');
        debugPrint('   Long: ${_selectedLocation.longitude}');
      }
    } else {
      if (AppConfig.enableDebugMode) {
        debugPrint('📍 Map opened with default location (Mambusao center)');
      }
    }
  }

  // When map is created
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    if (AppConfig.enableDebugMode) {
      debugPrint('✓ Map controller created');
    }
  }

  // When map camera moves
  void _onCameraMove(CameraPosition position) {
    setState(() {
      _selectedLocation = position.target;
    });
  }

  // Use current GPS location
  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Check location services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions permanently denied');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = newLocation;
        _locationDescription = 'Current Location';
        _isLoadingLocation = false;
      });

      // Animate camera to current location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(newLocation, 16),
      );

      if (AppConfig.enableDebugMode) {
        debugPrint('✓ Current location: ${position.latitude}, ${position.longitude}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated to your current position'),
            backgroundColor: AppTheme.successGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);

      if (AppConfig.enableDebugMode) {
        debugPrint('✗ Location error: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            backgroundColor: AppTheme.errorRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Return selected location
  void _confirmLocation() {
    if (_selectedLocation != null) {
      Navigator.pop(context, {
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
        'address': _locationDescription,
        'hasLocation': true,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 16, // Closer zoom for town center
            ),
            onCameraMove: _onCameraMove,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // We'll use custom button
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // Center Pin (stays fixed while map moves)
          Center(
            child: Icon(
              Icons.location_on,
              size: 50,
              color: AppTheme.errorRed,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),

          // Bottom Info Card
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Coordinates Display
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.place,
                            color: AppTheme.primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _locationDescription,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  'Long: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        // Use Current Location Button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoadingLocation ? null : _useCurrentLocation,
                            icon: _isLoadingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                            label: Text(_isLoadingLocation ? 'Getting...' : 'Use GPS'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryGreen,
                              side: const BorderSide(color: AppTheme.primaryGreen),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Confirm Location Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _confirmLocation,
                            icon: const Icon(Icons.check),
                            label: const Text('Confirm'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}