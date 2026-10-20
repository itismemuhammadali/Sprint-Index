import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sports_chat_app/src/services/notification_util.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Calculate distance between two coordinates in kilometers
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  /// Get nearby clubs within 5km radius
  Future<List<Map<String, dynamic>>> getNearbyClubs() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Get user's current location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Get all clubs
      final clubsSnapshot = await _firestore.collection('clubs').get();
      final nearbyClubs = <Map<String, dynamic>>[];

      for (final clubDoc in clubsSnapshot.docs) {
        final clubData = clubDoc.data();
        final clubLat = clubData['latitude'] as double?;
        final clubLon = clubData['longitude'] as double?;

        if (clubLat != null && clubLon != null) {
          final distance = calculateDistance(
            position.latitude,
            position.longitude,
            clubLat,
            clubLon,
          );

          // If within 5km
          if (distance <= 5.0) {
            nearbyClubs.add({
              'clubId': clubDoc.id,
              'clubName': clubData['clubName'] ?? 'Club',
              'distance': distance,
              'latitude': clubLat,
              'longitude': clubLon,
            });
          }
        }
      }

      // Sort by distance
      nearbyClubs.sort((a, b) => (a['distance'] as double)
          .compareTo(b['distance'] as double));

      return nearbyClubs;
    } catch (e) {
      return [];
    }
  }

  /// Send nearby club notification
  Future<void> checkAndNotifyNearbyClubs() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final nearbyClubs = await getNearbyClubs();

      for (final club in nearbyClubs) {
        await NotificationUtil.sendNearbyClubNotification(
          userId: user.uid,
          clubName: club['clubName'] as String,
          distance: club['distance'] as double,
        );
      }
    } catch (e) {
      // Handle error silently
    }
  }

  /// Update club location
  Future<String?> updateClubLocation({
    required String clubId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not authenticated';

      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      if (!clubDoc.exists) return 'Club not found';

      final adminId = clubDoc.data()?['adminId'];
      if (adminId != user.uid) return 'Only admin can update location';

      await _firestore.collection('clubs').doc(clubId).update({
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      return 'Error updating location: ${e.toString()}';
    }
  }

  /// Get user's current location
  Future<Position?> getUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        if (result == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      return null;
    }
  }
}
