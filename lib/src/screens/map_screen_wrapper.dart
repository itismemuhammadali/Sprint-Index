import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sports_chat_app/src/screens/map_screen.dart';
import 'package:sports_chat_app/src/screens/google_map_screen.dart';

/// Platform-aware map screen wrapper
/// Uses OpenStreetMap for iOS and Google Maps for Android
class MapScreenWrapper extends StatelessWidget {
  const MapScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      // Use OpenStreetMap for iOS
      return const MapScreen();
    } else if (Platform.isAndroid) {
      // Use Google Maps for Android
      return const GoogleMapScreen();
    } else {
      // Fallback to OpenStreetMap for other platforms
      return const MapScreen();
    }
  }
}
