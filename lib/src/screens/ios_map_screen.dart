import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sports_chat_app/src/services/remote_config_service.dart';

class IosMapScreen extends StatefulWidget {
  const IosMapScreen({super.key});

  @override
  State<IosMapScreen> createState() => _IosMapScreenState();
}

class _IosMapScreenState extends State<IosMapScreen> {
  GoogleMapController? mapController;
  LatLng? currentLocation;
  bool isLoading = false;
  final RemoteConfigService _remoteConfig = RemoteConfigService();

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) {
      _initializeMap();
    }
  }

  Future<void> _initializeMap() async {
    // Initialize remote config to get API key
    await _remoteConfig.initialize();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => isLoading = true);

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied'),
            ),
          );
        }
        return;
      }

      // Get current position
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        currentLocation = newLocation;
        isLoading = false;
      });

      // Animate camera to current location
      if (mounted) {
        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newLocation, 15),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show on iOS
    if (!Platform.isIOS) {
      return Scaffold(
        appBar: AppBar(title: const Text('Map')),
        body: const Center(
          child: Text('This feature is only available on iOS'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Location'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              mapController = controller;
              if (currentLocation != null && mapController != null) {
                mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(currentLocation!, 15),
                );
              }
            },
            initialCameraPosition: CameraPosition(
              target: currentLocation ?? const LatLng(37.7749, -122.4194),
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            markers: currentLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('current_location'),
                      position: currentLocation!,
                      infoWindow: const InfoWindow(title: 'Your Location'),
                    ),
                  }
                : {},
          ),
          if (isLoading)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const CircularProgressIndicator(),
              ),
            ),
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              onPressed: isLoading ? null : _getCurrentLocation,
              backgroundColor: Colors.blue,
              disabledElevation: 0,
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }
}
