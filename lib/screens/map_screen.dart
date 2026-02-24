import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  String _errorMessage = '';
  StreamSubscription<Position>? _locationSubscription; 

  // Initial camera position centered on coordinates (0,0)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(0, 0),
    zoom: 2,
  );

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  // Initialise location services and get current position
  Future<void> _initializeLocation() async {
    try {
      // Check and request location permissions
      bool hasPermission = await _handleLocationPermission();
      
      if (!hasPermission) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Location permission denied';
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // Move camera to current location
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15,
            ),
          ),
        );
      }

      // Start listening to location updates
      _startLocationUpdates();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error getting location: $e';
      });
    }
  }

  // Handle location permissions
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _errorMessage = 'Location services are disabled. Please enable them.';
      });
      return false;
    }

    // Check location permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = 'Location permission denied';
        });
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _errorMessage = 'Location permissions are permanently denied';
      });
      return false;
    }

    return true;
  }

  // Start listening to real-time location updates
  void _startLocationUpdates() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
    });
  }

  // When map is created
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // If we already have position, move to it
    if (_currentPosition != null) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 15,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Google Map
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: _initialPosition,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          zoomGesturesEnabled: true, // Pinch to zoom
          scrollGesturesEnabled: true, // Use one finger to move
          tiltGesturesEnabled: true, // Enable tilt gestures
          rotateGesturesEnabled: true, // Rotation
          mapType: MapType.normal,
          markers: _currentPosition != null
              ? {
                  Marker(
                    markerId: const MarkerId('current_location'),
                    position: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueOrange, 
                    ),
                    infoWindow: const InfoWindow(
                      title: 'You are here',
                      snippet: 'Current Location',
                    ),
                  ),
                }
              : {},
        ),

        // Loading indicator
        if (_isLoading)
          Container(
            color: Colors.white,
            child: const Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 255, 210, 75),
              ),
            ),
          ),

        // Error message
        if (_errorMessage.isNotEmpty && !_isLoading)
          Container(
            color: Colors.white,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = '';
                        });
                        _initializeLocation();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 255, 210, 75),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Custom "My Location" button (bottom right)
        if (!_isLoading && _errorMessage.isEmpty)
          Positioned(
            bottom: 100, // Above the bottom nav bar
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: () {
                if (_currentPosition != null && _mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: 15,
                      ),
                    ),
                  );
                }
              },
              child: const Icon(
                Icons.my_location,
                color: Color.fromARGB(255, 151, 86, 0),
              ),
            ),
          ),
      ],
    );
  }
}