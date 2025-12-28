// lib/pages/business_route_map_page.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../config/app_theme.dart';

class BusinessRouteMapPage extends StatefulWidget {
  final double userLat;
  final double userLng;
  final double businessLat;
  final double businessLng;
  final String businessName;

  const BusinessRouteMapPage({
    super.key,
    required this.userLat,
    required this.userLng,
    required this.businessLat,
    required this.businessLng,
    required this.businessName,
  });

  @override
  State<BusinessRouteMapPage> createState() => _BusinessRouteMapPageState();
}

class _BusinessRouteMapPageState extends State<BusinessRouteMapPage> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  
  bool _isLoadingRoute = true;
  String? _errorMessage;
  String _distance = '';
  String _duration = '';

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _fetchRoute();
  }

  // ==================== INITIALIZE MAP ====================
  void _initializeMap() {
    // Create markers for user and business locations
    _markers = {
      Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(widget.userLat, widget.userLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ),
      Marker(
        markerId: const MarkerId('business_location'),
        position: LatLng(widget.businessLat, widget.businessLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: widget.businessName),
      ),
    };
  }

  // ==================== FETCH ROUTE FROM GOOGLE DIRECTIONS API ====================
  Future<void> _fetchRoute() async {
    setState(() {
      _isLoadingRoute = true;
      _errorMessage = null;
    });

    try {
      final String origin = '${widget.userLat},${widget.userLng}';
      final String destination = '${widget.businessLat},${widget.businessLng}';
      
      final url = Uri.parse(
        '${AppConfig.googleDirectionsApiUrl}'
        '?origin=$origin'
        '&destination=$destination'
        '&key=${AppConfig.googleMapsApiKey}'
      );

      if (AppConfig.enableDebugMode) {
        debugPrint('🗺️ Fetching route from Directions API...');
      }

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Extract distance and duration
          _distance = leg['distance']['text'];
          _duration = leg['duration']['text'];

          // Decode polyline
          final polylinePoints = _decodePolyline(route['overview_polyline']['points']);

          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: polylinePoints,
                color: AppTheme.accentBlue,
                width: 5,
              ),
            };
            _isLoadingRoute = false;
          });

          // Adjust camera to show entire route
          _fitMapToRoute(polylinePoints);

          if (AppConfig.enableDebugMode) {
            debugPrint('✅ Route fetched: $_distance, $_duration');
          }
        } else {
          throw Exception('Route not found: ${data['status']}');
        }
      } else {
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoadingRoute = false;
        _errorMessage = 'Could not load route: $e';
      });

      if (AppConfig.enableDebugMode) {
        debugPrint('❌ Route error: $e');
      }
    }
  }

  // ==================== DECODE POLYLINE ====================
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  // ==================== FIT MAP TO SHOW ENTIRE ROUTE ====================
  void _fitMapToRoute(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100), // 100px padding
    );
  }

  // ==================== OPEN IN GOOGLE MAPS ====================
  Future<void> _openInGoogleMaps() async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${widget.userLat},${widget.userLng}'
      '&destination=${widget.businessLat},${widget.businessLng}'
      '&travelmode=driving'
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch Google Maps');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening Google Maps: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  // ==================== BUILD METHOD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Directions to ${widget.businessName}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
            },
            initialCameraPosition: CameraPosition(
              target: LatLng(
                (widget.userLat + widget.businessLat) / 2,
                (widget.userLng + widget.businessLng) / 2,
              ),
              zoom: 13,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
          ),

          // Loading Overlay
          if (_isLoadingRoute)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppTheme.primaryGreen,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Calculating route...',
                          style: AppTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Error Message
          if (_errorMessage != null && !_isLoadingRoute)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: AppTheme.errorRed,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => setState(() => _errorMessage = null),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Distance & Duration Info Card
          if (!_isLoadingRoute && _errorMessage == null && _distance.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
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
                      // Distance
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.straighten,
                              color: AppTheme.primaryGreen,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Distance',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                _distance,
                                style: AppTheme.titleMedium.copyWith(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const Divider(height: 20),
                      
                      // Duration
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.access_time,
                              color: AppTheme.accentBlue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estimated Time',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                _duration,
                                style: AppTheme.titleMedium.copyWith(
                                  color: AppTheme.accentBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // "Open in Google Maps" Button
          if (!_isLoadingRoute && _errorMessage == null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: _openInGoogleMaps,
                icon: const Icon(Icons.map, size: 24),
                label: const Text(
                  'Open in Google Maps',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
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