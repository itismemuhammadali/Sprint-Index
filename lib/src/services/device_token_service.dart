import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class DeviceTokenService {
  static final DeviceTokenService _instance = DeviceTokenService._internal();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  factory DeviceTokenService() {
    return _instance;
  }

  DeviceTokenService._internal();

  /// Save device token to Firestore for the current user
  Future<void> saveDeviceToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('No user logged in, skipping device token save');
        }
        return;
      }

      final token = await NotificationService().getDeviceToken();
      if (token == null) {
        if (kDebugMode) {
          print('Failed to get device token');
        }
        return;
      }

      await _firestore.collection('users').doc(user.uid).update({
        'deviceTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('Device token saved for user: ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving device token: $e');
      }
    }
  }

  /// Remove device token from Firestore when user logs out
  Future<void> removeDeviceToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final token = await NotificationService().getDeviceToken();
      if (token == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'deviceTokens': FieldValue.arrayRemove([token]),
      });

      if (kDebugMode) {
        print('Device token removed for user: ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error removing device token: $e');
      }
    }
  }

  /// Get all device tokens for a specific user
  Future<List<String>> getUserDeviceTokens(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final tokens = List<String>.from(doc.data()?['deviceTokens'] ?? []);
      return tokens;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user device tokens: $e');
      }
      return [];
    }
  }

  /// Subscribe user to notification topics based on their interests
  Future<void> subscribeToUserTopics(List<String> topics) async {
    for (final topic in topics) {
      await NotificationService().subscribeToTopic(topic);
    }
  }

  /// Unsubscribe user from notification topics
  Future<void> unsubscribeFromUserTopics(List<String> topics) async {
    for (final topic in topics) {
      await NotificationService().unsubscribeFromTopic(topic);
    }
  }
}
