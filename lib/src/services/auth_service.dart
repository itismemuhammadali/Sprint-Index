import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sports_chat_app/src/services/device_token_service.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign up with email and password
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required int age,
  }) async {
    try {
      // Create user
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'username': username,
        'fullName': fullName,
        'age': age,
        'isPrivate': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send welcome notification
      await _sendWelcomeNotification(userCredential.user!.uid);

      return null; // Success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return 'The password is too weak.';
      } else if (e.code == 'email-already-in-use') {
        return 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        return 'The email address is invalid.';
      }
      return e.message ?? 'An error occurred during sign up.';
    } catch (e) {
      return 'An error occurred. Please try again.';
    }
  }

  // Sign in with email and password
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Send welcome back notification
      await _sendWelcomeBackNotification(userCredential.user!.uid);
      
      return null; // Success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        return 'Wrong password provided.';
      } else if (e.code == 'invalid-email') {
        return 'The email address is invalid.';
      } else if (e.code == 'user-disabled') {
        return 'This user account has been disabled.';
      }
      return e.message ?? 'An error occurred during sign in.';
    } catch (e) {
      return 'An error occurred. Please try again.';
    }
  }

  // Sign out
  Future<void> signOut() async {
    final userId = _auth.currentUser?.uid;
    
    // Send logout notification
    if (userId != null) {
      await _sendLogoutNotification(userId);
    }
    
    // Remove device token before signing out
    await DeviceTokenService().removeDeviceToken();
    await _auth.signOut();
  }

  // Send welcome notification
  Future<void> _sendWelcomeNotification(String userId) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Welcome to SprintIndex',
        'body': 'Welcome to SprintIndex! Start connecting with sports enthusiasts.',
        'type': 'welcome',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        print('Welcome notification sent to $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending welcome notification: $e');
      }
    }
  }

  // Send welcome back notification
  Future<void> _sendWelcomeBackNotification(String userId) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Welcome Back',
        'body': 'Welcome back to SprintIndex!',
        'type': 'welcome_back',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        print('Welcome back notification sent to $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending welcome back notification: $e');
      }
    }
  }

  // Send logout notification
  Future<void> _sendLogoutNotification(String userId) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Logged Out',
        'body': 'You have been logged out.',
        'type': 'logout',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        print('Logout notification sent to $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending logout notification: $e');
      }
    }
  }

  // Reset password
  Future<String?> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email address';
        case 'invalid-email':
          return 'Invalid email address';
        default:
          return 'Error: ${e.message}';
      }
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  // Update password after OTP verification
  Future<String?> updatePasswordAfterReset({
    required String email,
    required String newPassword,
  }) async {
    try {
      // Store the new password hash in Firestore temporarily
      // This will be used when user logs in next time
      await _firestore.collection('password_updates').doc(email).set({
        'email': email,
        'newPassword': newPassword,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      return null; // Success
    } catch (e) {
      return 'Error updating password: ${e.toString()}';
    }
  }
}
