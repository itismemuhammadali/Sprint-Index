import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PostEngagementUtil {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Toggle like on a post - removes dislike if exists
  static Future<void> toggleLike(String postId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint('PostEngagementUtil: User not authenticated');
      return;
    }

    final likeRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId);

    final dislikeRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('dislikes')
        .doc(userId);

    try {
      final likeDoc = await likeRef.get();
      final dislikeDoc = await dislikeRef.get();

      if (likeDoc.exists) {
        // Remove like
        debugPrint('PostEngagementUtil: Removing like from post $postId');
        await likeRef.delete();
        await _firestore.collection('posts').doc(postId).update({
          'likesCount': FieldValue.increment(-1),
        });
      } else {
        // Add like
        debugPrint('PostEngagementUtil: Adding like to post $postId');
        await likeRef.set({'userId': userId, 'timestamp': FieldValue.serverTimestamp()});
        await _firestore.collection('posts').doc(postId).update({
          'likesCount': FieldValue.increment(1),
        });

        // Remove dislike if exists
        if (dislikeDoc.exists) {
          debugPrint('PostEngagementUtil: Removing dislike from post $postId');
          await dislikeRef.delete();
          await _firestore.collection('posts').doc(postId).update({
            'dislikesCount': FieldValue.increment(-1),
          });
        }
      }
      debugPrint('PostEngagementUtil: Like toggle successful for post $postId');
    } catch (e) {
      debugPrint('PostEngagementUtil: Error toggling like: $e');
    }
  }

  /// Toggle dislike on a post - removes like if exists
  static Future<void> toggleDislike(String postId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint('PostEngagementUtil: User not authenticated');
      return;
    }

    final dislikeRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('dislikes')
        .doc(userId);

    final likeRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId);

    try {
      final dislikeDoc = await dislikeRef.get();
      final likeDoc = await likeRef.get();

      if (dislikeDoc.exists) {
        // Remove dislike
        debugPrint('PostEngagementUtil: Removing dislike from post $postId');
        await dislikeRef.delete();
        await _firestore.collection('posts').doc(postId).update({
          'dislikesCount': FieldValue.increment(-1),
        });
      } else {
        // Add dislike
        debugPrint('PostEngagementUtil: Adding dislike to post $postId');
        await dislikeRef.set({'userId': userId, 'timestamp': FieldValue.serverTimestamp()});
        await _firestore.collection('posts').doc(postId).update({
          'dislikesCount': FieldValue.increment(1),
        });

        // Remove like if exists
        if (likeDoc.exists) {
          debugPrint('PostEngagementUtil: Removing like from post $postId');
          await likeRef.delete();
          await _firestore.collection('posts').doc(postId).update({
            'likesCount': FieldValue.increment(-1),
          });
        }
      }
      debugPrint('PostEngagementUtil: Dislike toggle successful for post $postId');
    } catch (e) {
      debugPrint('PostEngagementUtil: Error toggling dislike: $e');
    }
  }

  /// Calculate like percentage
  static int calculateLikePercentage(int likesCount, int dislikesCount) {
    final total = likesCount + dislikesCount;
    return total > 0 ? ((likesCount / total) * 100).round() : 0;
  }

  /// Calculate dislike percentage
  static int calculateDislikePercentage(int likesCount, int dislikesCount) {
    final total = likesCount + dislikesCount;
    return total > 0 ? ((dislikesCount / total) * 100).round() : 0;
  }
}
