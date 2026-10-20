import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sports_chat_app/src/services/notification_util.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> createPost({
    required String content,
    required bool isPermanent,
    String? duration,
    required bool allowComments,
    required bool allowDislikes,
    String? clubId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return 'User not authenticated';
      }

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return 'User data not found';
      }

      final userData = userDoc.data()!;
      final now = Timestamp.now();
      
      // If creating a club post, ensure user is a member
      if (clubId != null) {
        try {
          final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
          if (clubDoc.exists) {
            final memberIds = List<String>.from(clubDoc.data()?['memberIds'] ?? []);
            if (!memberIds.contains(user.uid)) {
              // Auto-join the user to the club
              await _firestore.collection('clubs').doc(clubId).update({
                'memberIds': FieldValue.arrayUnion([user.uid]),
              });
              // Add club to user's clubs list
              await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('clubs')
                  .doc(clubId)
                  .set({});
            }
          }
        } catch (e) {
          debugPrint('Error auto-joining club: $e');
        }
      }
      
      // Calculate expiry time for temporary posts
      Timestamp? expiresAt;
      if (!isPermanent && duration != null) {
        final hours = int.parse(duration.replaceAll('h', ''));
        expiresAt = Timestamp.fromDate(
          DateTime.now().add(Duration(hours: hours)),
        );
      }

      // Create post document with all required fields
      final postData = {
        'userId': user.uid,
        'userName': userData['username'] ?? 'Unknown',
        'email': user.email ?? '',
        'fullName': userData['fullName'] ?? 'Unknown User',
        'profilePictureUrl': userData['profilePictureUrl'] ?? '',
        'text': content,
        'imageUrl': null, // No image for text posts
        'isPermanent': isPermanent,
        'duration': duration,
        'expiresAt': expiresAt,
        'allowComments': allowComments,
        'allowDislikes': allowDislikes,
        'likesCount': 0,
        'dislikesCount': 0,
        'commentsCount': 0,
        'timestamp': now,
        'createdAt': now,
        'updatedAt': now,
        if (clubId != null) 'clubId': clubId,
      };

      final postRef = await _firestore.collection('posts').add(postData);
      
      // Send success notification
      await NotificationUtil.sendPostUploadNotification(
        userId: user.uid,
        success: true,
      );

      // If this is a club post, notify all club members
      if (clubId != null) {
        try {
          final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
          if (clubDoc.exists) {
            final memberIds = List<String>.from(clubDoc.data()?['memberIds'] ?? []);
            final clubName = clubDoc.data()?['clubName'] ?? 'Club';
            // Remove the post creator from the list to avoid self-notification
            memberIds.removeWhere((id) => id == user.uid);
            
            if (memberIds.isNotEmpty) {
              await NotificationUtil.sendClubPostNotification(
                clubId: clubId,
                clubName: clubName,
                posterName: userData['fullName'] ?? 'Someone',
                postPreview: content,
                memberIds: memberIds,
              );
            }
          }
        } catch (e) {
          debugPrint('Error sending club post notification: $e');
        }
      } else {
        // For non-club posts, notify followers
        // Get user's followers
        final followersSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('followers')
            .get();

        final followerIds =
            followersSnapshot.docs.map((doc) => doc.id).toList();

        // Send post notification to followers
        if (followerIds.isNotEmpty) {
          await NotificationUtil.sendFollowerPostNotification(
            userId: user.uid,
            userName: userData['fullName'] ?? 'Someone',
            postPreview: content,
            followerIds: followerIds,
            postId: postRef.id,
          );
        }

        // Also notify users who follow this user
        final followingSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('following')
            .get();

        final followingIds =
            followingSnapshot.docs.map((doc) => doc.id).toList();

        if (followingIds.isNotEmpty) {
          await NotificationUtil.sendFollowingPostNotification(
            userId: user.uid,
            userName: userData['fullName'] ?? 'Someone',
            postPreview: content,
            followingUserIds: followingIds,
            postId: postRef.id,
          );
        }
      }

      return null; // Success
    } catch (e) {
      // Send failure notification
      final user = _auth.currentUser;
      if (user != null) {
        await NotificationUtil.sendPostUploadNotification(
          userId: user.uid,
          success: false,
          errorMessage: e.toString(),
        );
      }
      return 'Error creating post: ${e.toString()}';
    }
  }

  Future<String?> createMediaPost({
    required String mediaUrl,
    required String mediaType, // 'photo' or 'video'
    String? caption,
    required bool isPermanent,
    String? duration,
    required bool allowComments,
    required bool allowDislikes,
    String? clubId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return 'User not authenticated';
      }

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return 'User data not found';
      }

      final userData = userDoc.data()!;
      final now = Timestamp.now();
      
      // If creating a club post, ensure user is a member
      if (clubId != null) {
        try {
          final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
          if (clubDoc.exists) {
            final memberIds = List<String>.from(clubDoc.data()?['memberIds'] ?? []);
            if (!memberIds.contains(user.uid)) {
              // Auto-join the user to the club
              await _firestore.collection('clubs').doc(clubId).update({
                'memberIds': FieldValue.arrayUnion([user.uid]),
              });
              // Add club to user's clubs list
              await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('clubs')
                  .doc(clubId)
                  .set({});
            }
          }
        } catch (e) {
          debugPrint('Error auto-joining club: $e');
        }
      }
      
      // Calculate expiry time for temporary posts
      Timestamp? expiresAt;
      if (!isPermanent && duration != null) {
        final hours = int.parse(duration.replaceAll('h', ''));
        expiresAt = Timestamp.fromDate(
          DateTime.now().add(Duration(hours: hours)),
        );
      }

      // Create post document with all required fields
      final postData = {
        'userId': user.uid,
        'userName': userData['username'] ?? 'Unknown',
        'email': user.email ?? '',
        'fullName': userData['fullName'] ?? 'Unknown User',
        'profilePictureUrl': userData['profilePictureUrl'] ?? '',
        'text': caption ?? '',
        'imageUrl': mediaUrl,
        'mediaType': mediaType,
        'isPermanent': isPermanent,
        'duration': duration,
        'expiresAt': expiresAt,
        'allowComments': allowComments,
        'allowDislikes': allowDislikes,
        'likesCount': 0,
        'dislikesCount': 0,
        'commentsCount': 0,
        'timestamp': now,
        'createdAt': now,
        'updatedAt': now,
        if (clubId != null) 'clubId': clubId,
      };

      final postRef = await _firestore.collection('posts').add(postData);
      
      // Send success notification
      await NotificationUtil.sendPostUploadNotification(
        userId: user.uid,
        success: true,
      );

      // If this is a club post, notify all club members
      if (clubId != null) {
        try {
          final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
          if (clubDoc.exists) {
            final memberIds = List<String>.from(clubDoc.data()?['memberIds'] ?? []);
            final clubName = clubDoc.data()?['clubName'] ?? 'Club';
            // Remove the post creator from the list to avoid self-notification
            memberIds.removeWhere((id) => id == user.uid);
            
            if (memberIds.isNotEmpty) {
              await NotificationUtil.sendClubPostNotification(
                clubId: clubId,
                clubName: clubName,
                posterName: userData['fullName'] ?? 'Someone',
                postPreview: caption ?? '',
                memberIds: memberIds,
              );
            }
          }
        } catch (e) {
          debugPrint('Error sending club post notification: $e');
        }
      } else {
        // For non-club posts, notify followers
        // Get user's followers
        final followersSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('followers')
            .get();

        final followerIds =
            followersSnapshot.docs.map((doc) => doc.id).toList();

        // Send post notification to followers
        if (followerIds.isNotEmpty) {
          await NotificationUtil.sendFollowerPostNotification(
            userId: user.uid,
            userName: userData['fullName'] ?? 'Someone',
            postPreview: caption ?? '',
            followerIds: followerIds,
            postId: postRef.id,
          );
        }

        // Also notify users who follow this user
        final followingSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('following')
            .get();

        final followingIds =
            followingSnapshot.docs.map((doc) => doc.id).toList();

        if (followingIds.isNotEmpty) {
          await NotificationUtil.sendFollowingPostNotification(
            userId: user.uid,
            userName: userData['fullName'] ?? 'Someone',
            postPreview: caption ?? '',
            followingUserIds: followingIds,
            postId: postRef.id,
          );
        }
      }

      return null; // Success
    } catch (e) {
      // Send failure notification
      final user = _auth.currentUser;
      if (user != null) {
        await NotificationUtil.sendPostUploadNotification(
          userId: user.uid,
          success: false,
          errorMessage: e.toString(),
        );
      }
      return 'Error creating post: ${e.toString()}';
    }
  }

  // Like a post
  Future<String?> likePost(String postId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not authenticated';

      final likeRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(user.uid);

      final dislikeRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('dislikes')
          .doc(user.uid);

      // Get post owner info
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final postOwnerId = postDoc.data()?['userId'];
      
      // Get current user name
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['fullName'] ?? 'Someone';

      await _firestore.runTransaction((transaction) async {
        final likeDoc = await transaction.get(likeRef);
        final dislikeDoc = await transaction.get(dislikeRef);

        if (likeDoc.exists) {
          // Unlike
          transaction.delete(likeRef);
          transaction.update(_firestore.collection('posts').doc(postId), {
            'likesCount': FieldValue.increment(-1),
          });
        } else {
          // Like
          transaction.set(likeRef, {
            'userId': user.uid,
            'timestamp': FieldValue.serverTimestamp(),
          });
          transaction.update(_firestore.collection('posts').doc(postId), {
            'likesCount': FieldValue.increment(1),
          });

          // Remove dislike if exists
          if (dislikeDoc.exists) {
            transaction.delete(dislikeRef);
            transaction.update(_firestore.collection('posts').doc(postId), {
              'dislikesCount': FieldValue.increment(-1),
            });
          }
          
          // Send like notification to post owner
          if (postOwnerId != null && postOwnerId != user.uid) {
            await NotificationUtil.sendLikeNotification(
              postOwnerId: postOwnerId,
              likerName: userName,
              postId: postId,
            );
          }
        }
      });

      return null;
    } catch (e) {
      return 'Error liking post: ${e.toString()}';
    }
  }

  // Dislike a post
  Future<String?> dislikePost(String postId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not authenticated';

      final likeRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(user.uid);

      final dislikeRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('dislikes')
          .doc(user.uid);

      // Get post owner info
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final postOwnerId = postDoc.data()?['userId'];
      
      // Get current user name
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['fullName'] ?? 'Someone';

      await _firestore.runTransaction((transaction) async {
        final likeDoc = await transaction.get(likeRef);
        final dislikeDoc = await transaction.get(dislikeRef);

        if (dislikeDoc.exists) {
          // Remove dislike
          transaction.delete(dislikeRef);
          transaction.update(_firestore.collection('posts').doc(postId), {
            'dislikesCount': FieldValue.increment(-1),
          });
        } else {
          // Dislike
          transaction.set(dislikeRef, {
            'userId': user.uid,
            'timestamp': FieldValue.serverTimestamp(),
          });
          transaction.update(_firestore.collection('posts').doc(postId), {
            'dislikesCount': FieldValue.increment(1),
          });

          // Remove like if exists
          if (likeDoc.exists) {
            transaction.delete(likeRef);
            transaction.update(_firestore.collection('posts').doc(postId), {
              'likesCount': FieldValue.increment(-1),
            });
          }
          
          // Send dislike notification to post owner
          if (postOwnerId != null && postOwnerId != user.uid) {
            await NotificationUtil.sendDislikeNotification(
              postOwnerId: postOwnerId,
              dislikerName: userName,
              postId: postId,
            );
          }
        }
      });

      return null;
    } catch (e) {
      return 'Error disliking post: ${e.toString()}';
    }
  }

  // Add a comment
  Future<String?> addComment(String postId, String text) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not authenticated';

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return 'User data not found';

      final userData = userDoc.data()!;

      // Get post owner info
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final postOwnerId = postDoc.data()?['userId'];

      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .add({
        'userId': user.uid,
        'userName': userData['username'] ?? 'Unknown',
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('posts').doc(postId).update({
        'commentsCount': FieldValue.increment(1),
      });

      // Send comment notification to post owner
      if (postOwnerId != null && postOwnerId != user.uid) {
        await NotificationUtil.sendCommentNotification(
          postOwnerId: postOwnerId,
          commenterName: userData['fullName'] ?? 'Someone',
          comment: text,
          postId: postId,
        );
      }

      return null;
    } catch (e) {
      return 'Error adding comment: ${e.toString()}';
    }
  }

  // Get comments for a post
  Stream<QuerySnapshot> getComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Check if user liked a post
  Stream<bool> isPostLiked(String postId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // Check if user disliked a post
  Stream<bool> isPostDisliked(String postId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('dislikes')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists);
  }
}
