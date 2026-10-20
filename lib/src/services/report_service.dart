import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Report a post
  static Future<bool> reportPost({
    required String postId,
    required String reason,
    String? additionalInfo,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('ReportService: User not authenticated');
        return false;
      }

      // Check if user already reported this post
      final existingReport = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: currentUser.uid)
          .where('postId', isEqualTo: postId)
          .where('type', isEqualTo: 'post')
          .get();

      if (existingReport.docs.isNotEmpty) {
        debugPrint('ReportService: Post already reported by this user');
        return false;
      }

      // Get post data for context
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        debugPrint('ReportService: Post not found');
        return false;
      }

      final postData = postDoc.data()!;

      // Create report document
      await _firestore.collection('reports').add({
        'type': 'post',
        'postId': postId,
        'reportedUserId': postData['userId'],
        'reporterId': currentUser.uid,
        'reason': reason,
        'additionalInfo': additionalInfo ?? '',
        'status': 'pending', // pending, reviewed, resolved, dismissed
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Include post context for moderators
        'postContent': {
          'text': postData['text'] ?? '',
          'imageUrl': postData['imageUrl'] ?? '',
          'userName': postData['userName'] ?? '',
          'fullName': postData['fullName'] ?? '',
        },
      });

      debugPrint('ReportService: Post reported successfully');
      return true;
    } catch (e) {
      debugPrint('ReportService: Error reporting post: $e');
      return false;
    }
  }

  /// Report a user
  static Future<bool> reportUser({
    required String userId,
    required String reason,
    String? additionalInfo,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('ReportService: User not authenticated');
        return false;
      }

      // Check if user already reported this user
      final existingReport = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: currentUser.uid)
          .where('reportedUserId', isEqualTo: userId)
          .where('type', isEqualTo: 'user')
          .get();

      if (existingReport.docs.isNotEmpty) {
        debugPrint('ReportService: User already reported by this user');
        return false;
      }

      // Get user data for context
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('ReportService: User not found');
        return false;
      }

      final userData = userDoc.data()!;

      // Create report document
      await _firestore.collection('reports').add({
        'type': 'user',
        'reportedUserId': userId,
        'reporterId': currentUser.uid,
        'reason': reason,
        'additionalInfo': additionalInfo ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Include user context for moderators
        'userContext': {
          'username': userData['username'] ?? '',
          'fullName': userData['fullName'] ?? '',
          'email': userData['email'] ?? '',
          'profilePictureUrl': userData['profilePictureUrl'] ?? '',
        },
      });

      debugPrint('ReportService: User reported successfully');
      return true;
    } catch (e) {
      debugPrint('ReportService: Error reporting user: $e');
      return false;
    }
  }

  /// Block a user
  static Future<bool> blockUser(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('ReportService: User not authenticated');
        return false;
      }

      // Add to blocked users list
      await _firestore.collection('users').doc(currentUser.uid).update({
        'blockedUsers': FieldValue.arrayUnion([userId]),
      });

      // Remove from following/followers if exists
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(userId)
          .delete();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .doc(currentUser.uid)
          .delete();

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('followers')
          .doc(userId)
          .delete();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .doc(currentUser.uid)
          .delete();

      debugPrint('ReportService: User blocked successfully');
      return true;
    } catch (e) {
      debugPrint('ReportService: Error blocking user: $e');
      return false;
    }
  }

  /// Unblock a user
  static Future<bool> unblockUser(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('ReportService: User not authenticated');
        return false;
      }

      // Remove from blocked users list
      await _firestore.collection('users').doc(currentUser.uid).update({
        'blockedUsers': FieldValue.arrayRemove([userId]),
      });

      debugPrint('ReportService: User unblocked successfully');
      return true;
    } catch (e) {
      debugPrint('ReportService: Error unblocking user: $e');
      return false;
    }
  }

  /// Check if a user is blocked
  static Future<bool> isUserBlocked(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) return false;

      final blockedUsers = List<String>.from(userDoc.data()?['blockedUsers'] ?? []);
      return blockedUsers.contains(userId);
    } catch (e) {
      debugPrint('ReportService: Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Get report reasons
  static List<String> getPostReportReasons() {
    return [
      'Spam or misleading content',
      'Harassment or bullying',
      'Hate speech or discrimination',
      'Violence or dangerous content',
      'Inappropriate or adult content',
      'Copyright infringement',
      'False information',
      'Other',
    ];
  }

  static List<String> getUserReportReasons() {
    return [
      'Harassment or bullying',
      'Hate speech or discrimination',
      'Spam or fake account',
      'Inappropriate behavior',
      'Impersonation',
      'Sharing inappropriate content',
      'Other',
    ];
  }
}