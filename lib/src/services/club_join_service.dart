import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sports_chat_app/src/services/notification_util.dart';

class ClubJoinService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Send a join request to a club
  Future<String?> requestToJoinClub(String clubId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return 'User not authenticated';

      // Check if already a member
      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      if (!clubDoc.exists) return 'Club not found';

      final memberIds = List<String>.from(clubDoc.data()?['memberIds'] ?? []);
      if (memberIds.contains(userId)) return 'Already a member';

      // Check if request already pending
      final existingRequest = await _firestore
          .collection('clubJoinRequests')
          .where('clubId', isEqualTo: clubId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) return 'Request already pending';

      // Get user info
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userName = userDoc.data()?['fullName'] ?? 'Unknown User';

      // Create join request
      await _firestore.collection('clubJoinRequests').add({
        'clubId': clubId,
        'userId': userId,
        'userName': userName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send notification to club admin
      final adminId = clubDoc.data()?['adminId'];
      final clubName = clubDoc.data()?['clubName'] ?? 'Club';
      if (adminId != null) {
        await NotificationUtil.sendClubJoinRequestNotification(
          adminId: adminId,
          clubName: clubName,
          requesterName: userName,
          requesterId: userId,
          clubId: clubId,
        );
      }

      return null; // Success
    } catch (e) {
      debugPrint('Error requesting to join club: $e');
      return 'Error: ${e.toString()}';
    }
  }

  /// Approve a join request
  Future<String?> approveJoinRequest(String requestId, String clubId, String userId) async {
    try {
      // Add user to club members
      await _firestore.collection('clubs').doc(clubId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
      });

      // Add club to user's clubs subcollection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('clubs')
          .doc(clubId)
          .set({});

      // Update request status
      await _firestore.collection('clubJoinRequests').doc(requestId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Get club name for notification
      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      final clubName = clubDoc.data()?['clubName'] ?? 'Club';

      // Send notification to user
      await NotificationUtil.sendClubJoinApprovedNotification(
        userId: userId,
        clubName: clubName,
        clubId: clubId,
      );

      return null; // Success
    } catch (e) {
      debugPrint('Error approving join request: $e');
      return 'Error: ${e.toString()}';
    }
  }

  /// Reject a join request
  Future<String?> rejectJoinRequest(String requestId, String userId, String clubId) async {
    try {
      // Update request status
      await _firestore.collection('clubJoinRequests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Get club name for notification
      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      final clubName = clubDoc.data()?['clubName'] ?? 'Club';

      // Send notification to user
      await NotificationUtil.sendClubJoinRejectedNotification(
        userId: userId,
        clubName: clubName,
        clubId: clubId,
      );

      return null; // Success
    } catch (e) {
      debugPrint('Error rejecting join request: $e');
      return 'Error: ${e.toString()}';
    }
  }

  /// Get pending join requests for a club
  Stream<QuerySnapshot> getPendingRequestsForClub(String clubId) {
    return _firestore
        .collection('clubJoinRequests')
        .where('clubId', isEqualTo: clubId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Check if user has pending request for a club
  Future<bool> hasPendingRequest(String clubId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final snapshot = await _firestore
          .collection('clubJoinRequests')
          .where('clubId', isEqualTo: clubId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking pending request: $e');
      return false;
    }
  }

  /// Auto-join user to club (used when creating posts)
  Future<String?> autoJoinClub(String clubId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return 'User not authenticated';

      // Check if already a member
      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      if (!clubDoc.exists) return 'Club not found';

      final memberIds = List<String>.from(clubDoc.data()?['memberIds'] ?? []);
      if (memberIds.contains(userId)) return null; // Already a member

      // Add user to club members
      await _firestore.collection('clubs').doc(clubId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
      });

      // Add club to user's clubs list
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('clubs')
          .doc(clubId)
          .set({});

      return null; // Success
    } catch (e) {
      debugPrint('Error auto-joining club: $e');
      return 'Error: ${e.toString()}';
    }
  }
}
