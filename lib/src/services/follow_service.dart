import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sports_chat_app/src/services/notification_util.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Follow a user
  Future<String?> followUser(String targetUserId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not authenticated';
      if (user.uid == targetUserId) return 'Cannot follow yourself';

      await _firestore.runTransaction((transaction) async {
        // Add to current user's following list
        transaction.set(
          _firestore
              .collection('users')
              .doc(user.uid)
              .collection('following')
              .doc(targetUserId),
          {
            'userId': targetUserId,
            'followedAt': FieldValue.serverTimestamp(),
          },
        );

        // Add to target user's followers list
        transaction.set(
          _firestore
              .collection('users')
              .doc(targetUserId)
              .collection('followers')
              .doc(user.uid),
          {
            'userId': user.uid,
            'followedAt': FieldValue.serverTimestamp(),
          },
        );

        // Update follower/following counts
        transaction.update(
          _firestore.collection('users').doc(user.uid),
          {'followingCount': FieldValue.increment(1)},
        );

        transaction.update(
          _firestore.collection('users').doc(targetUserId),
          {'followersCount': FieldValue.increment(1)},
        );
      });

      // Send follow notification
      final currentUserDoc = await _firestore.collection('users').doc(user.uid).get();
      final followerName = currentUserDoc.data()?['fullName'] ?? 'Someone';
      
      await NotificationUtil.sendFollowNotification(
        userId: targetUserId,
        followerName: followerName,
        followerId: user.uid,
      );

      return null;
    } catch (e) {
      return 'Error following user: ${e.toString()}';
    }
  }

  // Unfollow a user
  Future<String?> unfollowUser(String targetUserId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not authenticated';

      await _firestore.runTransaction((transaction) async {
        // Remove from current user's following list
        transaction.delete(
          _firestore
              .collection('users')
              .doc(user.uid)
              .collection('following')
              .doc(targetUserId),
        );

        // Remove from target user's followers list
        transaction.delete(
          _firestore
              .collection('users')
              .doc(targetUserId)
              .collection('followers')
              .doc(user.uid),
        );

        // Update follower/following counts
        transaction.update(
          _firestore.collection('users').doc(user.uid),
          {'followingCount': FieldValue.increment(-1)},
        );

        transaction.update(
          _firestore.collection('users').doc(targetUserId),
          {'followersCount': FieldValue.increment(-1)},
        );
      });

      return null;
    } catch (e) {
      return 'Error unfollowing user: ${e.toString()}';
    }
  }

  // Check if current user follows target user
  Stream<bool> isFollowing(String targetUserId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(targetUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // Get followers count
  Future<int> getFollowersCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Get following count
  Future<int> getFollowingCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Get followers list
  Stream<QuerySnapshot> getFollowers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots();
  }

  // Get following list
  Stream<QuerySnapshot> getFollowing(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots();
  }
}
