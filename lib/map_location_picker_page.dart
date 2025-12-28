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
  final LatLng? initialLocation;

  const MapLocationPickerPage({
    Key? key,
    this.initialLocation,
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
    
    // Use initial location if provided, otherwise use default
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
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Location updated to your current position'),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            duration: const Duration(seconds: 2),
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
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to get location: $e')),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Select Location'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.space8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: const Icon(
                          Icons.help_outline,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space12),
                      const Text('How to use'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHelpItem(
                        Icons.touch_app,
                        'Drag the map to position the pin',
                      ),
                      const SizedBox(height: AppTheme.space12),
                      _buildHelpItem(
                        Icons.my_location,
                        'Tap "Use GPS" to use your current location',
                      ),
                      const SizedBox(height: AppTheme.space12),
                      _buildHelpItem(
                        Icons.check_circle,
                        'Tap "Confirm" to save the location',
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 16,
            ),
            onCameraMove: _onCameraMove,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // Center Pin (stays fixed while map moves)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.space8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space12,
                    vertical: AppTheme.space4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Text(
                    'Drop pin here',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Info Card
          Positioned(
            left: AppTheme.space16,
            right: AppTheme.space16,
            bottom: AppTheme.space16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                boxShadow: AppTheme.shadowCardHeavy,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Coordinates Display
                    Container(
                      padding: const EdgeInsets.all(AppTheme.space16),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppTheme.space8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: const Icon(
                              Icons.place,
                              color: AppTheme.primaryGreen,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppTheme.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _locationDescription,
                                  style: AppTheme.titleSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}',
                                  style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  'Long: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                                  style: AppTheme.labelSmall.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.space16),

                    // Action Buttons
                    Row(
                      children: [
                        // Use Current Location Button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoadingLocation ? null : _useCurrentLocation,
                            icon: _isLoadingLocation
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  )
                                : const Icon(Icons.my_location, size: 20),
                            label: Text(_isLoadingLocation ? 'Getting...' : 'Use GPS'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryGreen,
                              side: const BorderSide(
                                color: AppTheme.primaryGreen,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.space16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.space12),

                        // Confirm Location Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _confirmLocation,
                            icon: const Icon(Icons.check, size: 20),
                            label: const Text('Confirm'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.space16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              ),
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

  Widget _buildHelpItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.space8),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryGreen,
            size: 20,
          ),
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}