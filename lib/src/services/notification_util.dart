import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationUtil {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Truncate message to first 3 words if too long
  static String _truncateMessage(String message) {
    final words = message.split(' ');
    if (words.length > 3) {
      return '${words.take(3).join(' ')}...';
    }
    return message;
  }

  /// Verify recipient has FCM token before sending
  static Future<bool> _verifyRecipientToken(String recipientId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(recipientId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) {
        if (kDebugMode) {
          print('⚠️ Recipient $recipientId has no FCM token');
        }
        return false;
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error verifying recipient token: $e');
      }
      return false;
    }
  }

  /// Send club message notification
  static Future<void> sendClubMessageNotification({
    required String clubId,
    required String clubName,
    required String senderName,
    required String message,
    required List<String> memberIds,
  }) async {
    try {
      final truncatedMessage = _truncateMessage(message);
      final title = 'New message in $clubName';
      final body = '$senderName: $truncatedMessage';

      for (final memberId in memberIds) {
        // Get member's FCM token
        final memberDoc = await _firestore.collection('users').doc(memberId).get();
        final fcmToken = memberDoc.data()?['fcmToken'] as String?;

        if (fcmToken == null) {
          if (kDebugMode) {
            print('⚠️ No FCM token for member: $memberId');
          }
          continue;
        }

        // Send via new notification system
        await _firestore.collection('notifications').add({
          'recipientUserId': memberId,
          'fcmToken': fcmToken,
          'title': title,
          'body': body,
          'data': {
            'type': 'club_message',
            'clubId': clubId,
            'clubName': clubName,
            'senderName': senderName,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'sent': false,
        });
      }

      if (kDebugMode) {
        print('✅ Club message notification sent for $clubName to ${memberIds.length} members');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending club message notification: $e');
      }
    }
  }

  /// Send direct message notification
  static Future<bool> sendDirectMessageNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    try {
      // Verify recipient has FCM token
      final hasToken = await _verifyRecipientToken(recipientId);
      if (!hasToken) {
        if (kDebugMode) {
          print('⚠️ Cannot send notification - recipient has no FCM token');
        }
        return false;
      }

      final truncatedMessage = _truncateMessage(message);
      final title = 'Message from $senderName';
      final body = truncatedMessage;

      // Get recipient's FCM token
      final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
      final fcmToken = recipientDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        if (kDebugMode) {
          print('❌ No valid FCM token for recipient: $recipientId');
        }
        return false;
      }

      // Send via new notification system
      final docRef = await _firestore.collection('notifications').add({
        'recipientUserId': recipientId,
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'data': {
          'type': 'direct_message',
          'chatId': chatId,
          'senderName': senderName,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
        'retryCount': 0,
      });

      if (kDebugMode) {
        print('✅ Direct message notification queued');
        print('   Document ID: ${docRef.id}');
        print('   Recipient: $recipientId');
        print('   Title: $title');
        print('   Body: $body');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending direct message notification: $e');
      }
      return false;
    }
  }

  /// Send post notification to followers
  static Future<void> sendPostNotification({
    required String userId,
    required String userName,
    required String postId,
    required List<String> followerIds,
  }) async {
    try {
      final title = 'New post from $userName';
      final body = '$userName posted something new';

      for (final followerId in followerIds) {
        // Get follower's FCM token
        final followerDoc = await _firestore.collection('users').doc(followerId).get();
        final fcmToken = followerDoc.data()?['fcmToken'] as String?;

        if (fcmToken == null) {
          if (kDebugMode) {
            print('⚠️ No FCM token for follower: $followerId');
          }
          continue;
        }

        await _firestore.collection('notifications').add({
          'recipientUserId': followerId,
          'fcmToken': fcmToken,
          'title': title,
          'body': body,
          'data': {
            'type': 'new_post',
            'postId': postId,
            'postUserId': userId,
            'userName': userName,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'sent': false,
        });
      }

      if (kDebugMode) {
        print('Post notification sent to ${followerIds.length} followers');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending post notification: $e');
      }
    }
  }

  /// Send follow notification
  static Future<void> sendFollowNotification({
    required String userId,
    required String followerName,
    required String followerId,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        if (kDebugMode) {
          print('⚠️ No FCM token for user: $userId');
        }
        return;
      }

      final title = 'New Follower';
      final body = '$followerName started following you';

      await _firestore.collection('notifications').add({
        'recipientUserId': userId,
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'data': {
          'type': 'new_follow',
          'followerId': followerId,
          'followerName': followerName,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      if (kDebugMode) {
        print('✅ Follow notification sent to $userId');
        print('✅ Follower: $followerName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending follow notification: $e');
      }
    }
  }

  /// Send post upload notification
  static Future<void> sendPostUploadNotification({
    required String userId,
    required bool success,
    String? errorMessage,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        if (kDebugMode) {
          print('⚠️ No FCM token for user: $userId');
        }
        return;
      }

      await _firestore.collection('notifications').add({
        'recipientUserId': userId,
        'fcmToken': fcmToken,
        'title': success ? 'Post Published' : 'Post Upload Failed',
        'body': success
            ? 'Your post has been published successfully'
            : 'Failed to upload post: ${errorMessage ?? 'Unknown error'}',
        'data': {
          'type': 'post_upload',
          'success': success,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      if (kDebugMode) {
        print('Post upload notification sent to $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending post upload notification: $e');
      }
    }
  }

  /// Send event notification
  static Future<void> sendEventNotification({
    required String userId,
    required String eventName,
    required String action, // created, deleted, completed
    required List<String> recipientIds,
  }) async {
    try {
      final title = 'Event ${action.capitalize()}';
      final body = 'Event "$eventName" has been $action';

      for (final recipientId in recipientIds) {
        // Get recipient's FCM token
        final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
        final fcmToken = recipientDoc.data()?['fcmToken'] as String?;

        if (fcmToken == null) {
          if (kDebugMode) {
            print('⚠️ No FCM token for recipient: $recipientId');
          }
          continue;
        }

        await _firestore.collection('notifications').add({
          'recipientUserId': recipientId,
          'fcmToken': fcmToken,
          'title': title,
          'body': body,
          'data': {
            'type': 'event_$action',
            'eventName': eventName,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'sent': false,
        });
      }

      if (kDebugMode) {
        print('Event notification sent for $eventName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending event notification: $e');
      }
    }
  }

  /// Send poll notification
  static Future<void> sendPollNotification({
    required String userId,
    required String pollTitle,
    required String action, // created, deleted, completed
    required List<String> recipientIds,
  }) async {
    try {
      final title = 'Poll ${action.capitalize()}';
      final body = 'Poll "$pollTitle" has been $action';

      for (final recipientId in recipientIds) {
        // Get recipient's FCM token
        final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
        final fcmToken = recipientDoc.data()?['fcmToken'] as String?;

        if (fcmToken == null) {
          if (kDebugMode) {
            print('⚠️ No FCM token for recipient: $recipientId');
          }
          continue;
        }

        await _firestore.collection('notifications').add({
          'recipientUserId': recipientId,
          'fcmToken': fcmToken,
          'title': title,
          'body': body,
          'data': {
            'type': 'poll_$action',
            'pollTitle': pollTitle,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'sent': false,
        });
      }

      if (kDebugMode) {
        print('Poll notification sent for $pollTitle');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending poll notification: $e');
      }
    }
  }

  /// Send club notification
  static Future<void> sendClubNotification({
    required String clubName,
    required String action, // created, joined, deleted, removed, exited
    required List<String> recipientIds,
    String? userName,
  }) async {
    try {
      String title;
      String body;

      switch (action) {
        case 'created':
          title = 'New Club Created';
          body = 'Club "$clubName" has been created';
          break;
        case 'joined':
          title = 'New Member';
          body = '$userName joined $clubName';
          break;
        case 'deleted':
          title = 'Club Deleted';
          body = 'Club "$clubName" has been deleted';
          break;
        case 'removed':
          title = 'Removed from Club';
          body = 'You have been removed from $clubName';
          break;
        case 'exited':
          title = 'Member Left';
          body = '$userName left $clubName';
          break;
        default:
          title = 'Club Update';
          body = 'Club "$clubName" has been updated';
      }

      for (final recipientId in recipientIds) {
        // Get recipient's FCM token
        final recipientDoc = await _firestore.collection('users').doc(recipientId).get();
        final fcmToken = recipientDoc.data()?['fcmToken'] as String?;

        if (fcmToken == null) {
          if (kDebugMode) {
            print('⚠️ No FCM token for recipient: $recipientId');
          }
          continue;
        }

        await _firestore.collection('notifications').add({
          'recipientUserId': recipientId,
          'fcmToken': fcmToken,
          'title': title,
          'body': body,
          'data': {
            'type': 'club_$action',
            'clubName': clubName,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'sent': false,
        });
      }

      if (kDebugMode) {
        print('Club notification sent for $clubName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending club notification: $e');
      }
    }
  }

  /// Send profile update notification
  static Future<void> sendProfileUpdateNotification({
    required String userId,
    required String userName,
    required List<String> followerIds,
  }) async {
    try {
      for (final followerId in followerIds) {
        // Get follower's FCM token
        final followerDoc = await _firestore.collection('users').doc(followerId).get();
        final fcmToken = followerDoc.data()?['fcmToken'] as String?;

        if (fcmToken == null) {
          if (kDebugMode) {
            print('⚠️ No FCM token for follower: $followerId');
          }
          continue;
        }

        await _firestore.collection('notifications').add({
          'recipientUserId': followerId,
          'fcmToken': fcmToken,
          'title': 'Profile Updated',
          'body': '$userName updated their profile',
          'data': {
            'type': 'profile_update',
            'userName': userName,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'sent': false,
        });
      }

      if (kDebugMode) {
        print('Profile update notification sent');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending profile update notification: $e');
      }
    }
  }

  /// Send nearby club notification
  static Future<void> sendNearbyClubNotification({
    required String userId,
    required String clubName,
    required double distance,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        if (kDebugMode) {
          print('⚠️ No FCM token for user: $userId');
        }
        return;
      }

      await _firestore.collection('notifications').add({
        'recipientUserId': userId,
        'fcmToken': fcmToken,
        'title': 'Club Nearby',
        'body': '$clubName is ${distance.toStringAsFixed(1)} km away',
        'data': {
          'type': 'nearby_club',
          'clubName': clubName,
          'distance': distance,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      if (kDebugMode) {
        print('Nearby club notification sent to $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending nearby club notification: $e');
      }
    }
  }

  /// Send comment notification
  static Future<void> sendCommentNotification({
    required String postOwnerId,
    required String commenterName,
    required String comment,
    required String postId,
  }) async {
    try {
      // Get post owner's FCM token
      final ownerDoc = await _firestore.collection('users').doc(postOwnerId).get();
      final fcmToken = ownerDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        if (kDebugMode) {
          print('⚠️ No FCM token for post owner: $postOwnerId');
        }
        return;
      }

      final truncatedComment = _truncateMessage(comment);

      await _firestore.collection('notifications').add({
        'recipientUserId': postOwnerId,
        'fcmToken': fcmToken,
        'title': 'New Comment',
        'body': '$commenterName: $truncatedComment',
        'data': {
          'type': 'comment',
          'postId': postId,
          'commenterName': commenterName,
          'comment': comment,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      if (kDebugMode) {
        print('Comment notification sent to $postOwnerId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending comment notification: $e');
      }
    }
  }

  /// Send like notification
  static Future<void> sendLikeNotification({
    required String postOwnerId,
    required String likerName,
    required String postId,
  }) async {
    try {
      // Get post owner's FCM token
      final ownerDoc = await _firestore.collection('users').doc(postOwnerId).get();
      final fcmToken = ownerDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        if (kDebugMode) {
          print('⚠️ No FCM token for post owner: $postOwnerId');
        }
        return;
      }

      await _firestore.collection('notifications').add({
        'recipientUserId': postOwnerId,
        'fcmToken': fcmToken,
        'title': 'Post Liked',
        'body': '$likerName liked your post',
        'data': {
          'type': 'like',
          'postId': postId,
          'likerName': likerName,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      if (kDebugMode) {
        print('Like notification sent to $postOwnerId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending like notification: $e');
      }
    }
  }

  /// Send dislike notification
  static Future<void> sendDislikeNotification({
    required String postOwnerId,
    required String dislikerName,
    required String postId,
  }) async {
    try {
      // Get post owner's FCM token
      final ownerDoc = await _firestore.collection('users').doc(postOwnerId).get();
      final fcmToken = ownerDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        if (kDebugMode) {
          print('⚠️ No FCM token for post owner: $postOwnerId');
        }
        return;
      }

      await _firestore.collection('notifications').add({
        'recipientUserId': postOwnerId,
        'fcmToken': fcmToken,
        'title': 'Post Disliked',
        'body': '$dislikerName disliked your post',
        'data': {
          'type': 'dislike',
          'postId': postId,
          'dislikerName': dislikerName,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      if (kDebugMode) {
        print('Dislike notification sent to $postOwnerId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending dislike notification: $e');
      }
    }
  }

  /// Send club join request notification to admin
  static Future<void> sendClubJoinRequestNotification({
    required String adminId,
    required String clubName,
    required String requesterName,
    required String requesterId,
    required String clubId,
  }) async {
    try {
      // Get admin's FCM token
      final adminDoc = await _firestore.collection('users').doc(adminId).get();
      final fcmToken = adminDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        if (kDebugMode) {
          print('⚠️ No FCM token for admin: $adminId');
        }
        return;
      }

      final title = 'Join Request for $clubName';
      final body = '$requesterName wants to join $clubName';

      await _firestore.collection('notifications').add({
        'recipientUserId': adminId,
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'data': {
          'type': 'club_join_request',
          'clubId': clubId,
          'clubName': clubName,
          'requesterId': requesterId,
          'requesterName': requesterName,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      if (kDebugMode) {
        print('✅ Club join request notification sent to admin: $adminId');
        print('✅ Club: $clubName, Requester: $requesterName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending club join request notification: $e');
      }
    }
  }

  /// Send club join approved notification
  static Future<void> sendClubJoinApprovedNotification({
    required String userId,
    required String clubName,
    required String clubId,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        if (kDebugMode) {
          print('⚠️ No FCM token for user: $userId');
        }
        return;
      }

      final title = 'Joined $clubName';
      final body = 'Your request to join $clubName has been approved!';

      await _firestore.collection('notifications').add({
        'recipientUserId': userId,
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'data': {
          'type': 'club_join_approved',
          'clubId': clubId,
          'clubName': clubName,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      if (kDebugMode) {
        print('✅ Club join approved notification sent to $userId');
        print('✅ Club: $clubName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending club join approved notification: $e');
      }
    }
  }

  /// Send club join rejected notification
  static Future<void> sendClubJoinRejectedNotification({
    required String userId,
    required String clubName,
    required String clubId,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        if (kDebugMode) {
          print('⚠️ No FCM token for user: $userId');
        }
        return;
      }

      final title = 'Request Declined';
      final body = 'Your request to join $clubName has been declined';

      await _firestore.collection('notifications').add({
        'recipientUserId': userId,
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'data': {
          'type': 'club_join_rejected',
          'clubId': clubId,
          'clubName': clubName,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      if (kDebugMode) {
        print('✅ Club join rejected notification sent to $userId');
        print('✅ Club: $clubName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending club join rejected notification: $e');
      }
    }
  }

  /// Send club post notification to all members
  static Future<void> sendClubPostNotification({
    required String clubId,
    required String clubName,
    required String posterName,
    required String postPreview,
    required List<String> memberIds,
  }) async {
    try {
      final truncatedPreview = _truncateMessage(postPreview);
      final title = 'New post in $clubName';
      final body = '$posterName: $truncatedPreview';

      for (final memberId in memberIds) {
        // Get member's FCM token
        final memberDoc = await _firestore.collection('users').doc(memberId).get();
        final fcmToken = memberDoc.data()?['fcmToken'] as String?;

        if (fcmToken == null) {
          if (kDebugMode) {
            print('⚠️ No FCM token for member: $memberId');
          }
          continue;
        }

        await _firestore.collection('notifications').add({
          'recipientUserId': memberId,
          'fcmToken': fcmToken,
          'title': title,
          'body': body,
          'data': {
            'type': 'club_post',
            'clubId': clubId,
            'clubName': clubName,
            'posterName': posterName,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'sent': false,
        });
      }

      if (kDebugMode) {
        print('✅ Club post notification sent to ${memberIds.length} members');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending club post notification: $e');
      }
    }
  }

  /// Send new club nearby notification
  static Future<void> sendNewClubNearbyNotification({
    required String userId,
    required String clubName,
    required double distance,
    required String clubId,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        if (kDebugMode) {
          print('⚠️ No FCM token for user: $userId');
        }
        return;
      }

      final title = 'New Club Nearby';
      final body = '$clubName is ${distance.toStringAsFixed(1)} km away';

      await _firestore.collection('notifications').add({
        'recipientUserId': userId,
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'data': {
          'type': 'new_club_nearby',
          'clubId': clubId,
          'clubName': clubName,
          'distance': distance.toString(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      if (kDebugMode) {
        print('✅ New club nearby notification sent to $userId');
        print('✅ Club: $clubName, Distance: ${distance.toStringAsFixed(1)} km');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending new club nearby notification: $e');
      }
    }
  }

  /// Send post notification to followers
  static Future<void> sendFollowerPostNotification({
    required String userId,
    required String userName,
    required String postPreview,
    required List<String> followerIds,
    required String postId,
  }) async {
    try {
      final truncatedPreview = _truncateMessage(postPreview);
      final title = 'New post from $userName';
      final body = truncatedPreview;

      for (final followerId in followerIds) {
        // Get follower's FCM token
        final followerDoc = await _firestore.collection('users').doc(followerId).get();
        final fcmToken = followerDoc.data()?['fcmToken'] as String?;

        if (fcmToken == null) {
          if (kDebugMode) {
            print('⚠️ No FCM token for follower: $followerId');
          }
          continue;
        }

        await _firestore.collection('notifications').add({
          'recipientUserId': followerId,
          'fcmToken': fcmToken,
          'title': title,
          'body': body,
          'data': {
            'type': 'follower_post',
            'postId': postId,
            'userId': userId,
            'userName': userName,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'sent': false,
        });
      }

      if (kDebugMode) {
        print('✅ Follower post notification sent to ${followerIds.length} followers');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending follower post notification: $e');
      }
    }
  }

  /// Send post notification to users following the poster
  static Future<void> sendFollowingPostNotification({
    required String userId,
    required String userName,
    required String postPreview,
    required List<String> followingUserIds,
    required String postId,
  }) async {
    try {
      final truncatedPreview = _truncateMessage(postPreview);
      final title = 'New post from $userName';
      final body = truncatedPreview;

      for (final followingUserId in followingUserIds) {
        // Get user's FCM token
        final userDoc = await _firestore.collection('users').doc(followingUserId).get();
        final fcmToken = userDoc.data()?['fcmToken'] as String?;

        if (fcmToken == null) {
          if (kDebugMode) {
            print('⚠️ No FCM token for user: $followingUserId');
          }
          continue;
        }

        await _firestore.collection('notifications').add({
          'recipientUserId': followingUserId,
          'fcmToken': fcmToken,
          'title': title,
          'body': body,
          'data': {
            'type': 'following_post',
            'postId': postId,
            'userId': userId,
            'userName': userName,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'sent': false,
        });
      }

      if (kDebugMode) {
        print('✅ Following post notification sent to ${followingUserIds.length} users');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending following post notification: $e');
      }
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
