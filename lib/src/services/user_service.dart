import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sports_chat_app/src/services/notification_util.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Follow a user
  Future<String?> followUser(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 'User not authenticated';

      // Add to current user's following list
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(userId)
          .set({
        'followedAt': FieldValue.serverTimestamp(),
      });

      // Add to target user's followers list
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .doc(currentUser.uid)
          .set({
        'followedAt': FieldValue.serverTimestamp(),
      });

      // Get current user name and send follow notification
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final followerName = currentUserDoc.data()?['fullName'] ?? 'Someone';

      await NotificationUtil.sendFollowNotification(
        userId: userId,
        followerName: followerName,
        followerId: currentUser.uid,
      );

      return null;
    } catch (e) {
      return 'Error following user: ${e.toString()}';
    }
  }

  /// Unfollow a user
  Future<String?> unfollowUser(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 'User not authenticated';

      // Remove from current user's following list
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(userId)
          .delete();

      // Remove from target user's followers list
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .doc(currentUser.uid)
          .delete();

      return null;
    } catch (e) {
      return 'Error unfollowing user: ${e.toString()}';
    }
  }

  /// Check if current user is following a user
  Future<bool> isFollowing(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final doc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(userId)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get user's followers count
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

  /// Get user's following count
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

  /// Create a post
  Future<String?> createPost({
    required String content,
    required List<String>? imageUrls,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 'User not authenticated';

      // Get current user info
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userName = userDoc.data()?['fullName'] ?? 'Someone';

      // Create post
      final postRef = await _firestore.collection('posts').add({
        'userId': currentUser.uid,
        'userName': userName,
        'content': content,
        'imageUrls': imageUrls ?? [],
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'comments': 0,
      });

      // Send success notification to user
      await NotificationUtil.sendPostUploadNotification(
        userId: currentUser.uid,
        success: true,
      );

      // Get user's followers
      final followersSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('followers')
          .get();

      final followerIds =
          followersSnapshot.docs.map((doc) => doc.id).toList();

      // Send post notification to followers
      if (followerIds.isNotEmpty) {
        await NotificationUtil.sendPostNotification(
          userId: currentUser.uid,
          userName: userName,
          postId: postRef.id,
          followerIds: followerIds,
        );
      }

      return postRef.id;
    } catch (e) {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Send failure notification
        await NotificationUtil.sendPostUploadNotification(
          userId: currentUser.uid,
          success: false,
          errorMessage: e.toString(),
        );
      }
      return null;
    }
  }

  /// Update user profile
  Future<String?> updateProfile({
    required String fullName,
    required int age,
    String? bio,
    String? profilePictureUrl,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 'User not authenticated';

      // Update user document
      await _firestore.collection('users').doc(currentUser.uid).update({
        'fullName': fullName,
        'age': age,
        'bio': bio,
        'profilePictureUrl': profilePictureUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Get user's followers
      final followersSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('followers')
          .get();

      final followerIds =
          followersSnapshot.docs.map((doc) => doc.id).toList();

      // Send profile update notification to followers
      if (followerIds.isNotEmpty) {
        await NotificationUtil.sendProfileUpdateNotification(
          userId: currentUser.uid,
          userName: fullName,
          followerIds: followerIds,
        );
      }

      return null;
    } catch (e) {
      return 'Error updating profile: ${e.toString()}';
    }
  }

  /// Like a post
  Future<String?> likePost({
    required String postId,
    required String postOwnerId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 'User not authenticated';

      // Add like
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(currentUser.uid)
          .set({'likedAt': FieldValue.serverTimestamp()});

      // Update like count
      await _firestore.collection('posts').doc(postId).update({
        'likes': FieldValue.increment(1),
      });

      // Get current user name
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userName = userDoc.data()?['fullName'] ?? 'Someone';

      // Send like notification
      await NotificationUtil.sendLikeNotification(
        postOwnerId: postOwnerId,
        likerName: userName,
        postId: postId,
      );

      return null;
    } catch (e) {
      return 'Error liking post: ${e.toString()}';
    }
  }

  /// Dislike a post
  Future<String?> dislikePost({
    required String postId,
    required String postOwnerId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 'User not authenticated';

      // Add dislike
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('dislikes')
          .doc(currentUser.uid)
          .set({'dislikedAt': FieldValue.serverTimestamp()});

      // Update dislike count
      await _firestore.collection('posts').doc(postId).update({
        'dislikes': FieldValue.increment(1),
      });

      // Get current user name
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userName = userDoc.data()?['fullName'] ?? 'Someone';

      // Send dislike notification
      await NotificationUtil.sendDislikeNotification(
        postOwnerId: postOwnerId,
        dislikerName: userName,
        postId: postId,
      );

      return null;
    } catch (e) {
      return 'Error disliking post: ${e.toString()}';
    }
  }

  /// Comment on a post
  Future<String?> commentOnPost({
    required String postId,
    required String postOwnerId,
    required String comment,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 'User not authenticated';

      // Get current user name
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userName = userDoc.data()?['fullName'] ?? 'Someone';

      // Add comment
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .add({
        'userId': currentUser.uid,
        'userName': userName,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update comment count
      await _firestore.collection('posts').doc(postId).update({
        'comments': FieldValue.increment(1),
      });

      // Send comment notification
      await NotificationUtil.sendCommentNotification(
        postOwnerId: postOwnerId,
        commenterName: userName,
        comment: comment,
        postId: postId,
      );

      return null;
    } catch (e) {
      return 'Error commenting on post: ${e.toString()}';
    }
  }

  /// Get user's posts
  Stream<QuerySnapshot> getUserPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get feed posts from followed users
  Stream<QuerySnapshot> getFeedPosts() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.empty();

    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
