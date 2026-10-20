import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sports_chat_app/src/services/notification_util.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send a message
  Future<String?> sendMessage({
    required String recipientId,
    required String message,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not authenticated';

      final conversationId = _getConversationId(user.uid, recipientId);

      // Create or update conversation
      await _firestore.collection('conversations').doc(conversationId).set({
        'participants': [user.uid, recipientId],
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Add message to conversation
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
        'senderId': user.uid,
        'recipientId': recipientId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Get sender name and send notification
      final senderDoc = await _firestore.collection('users').doc(user.uid).get();
      final senderName = senderDoc.data()?['fullName'] ?? 'Someone';
      
      await NotificationUtil.sendDirectMessageNotification(
        recipientId: recipientId,
        senderName: senderName,
        message: message,
        chatId: conversationId,
      );

      return null;
    } catch (e) {
      return 'Error sending message: ${e.toString()}';
    }
  }

  // Get conversations for current user
  Stream<QuerySnapshot> getConversations() {
    final user = _auth.currentUser;
    if (user == null) return Stream.empty();

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: user.uid)
        .snapshots();
  }

  // Get messages for a conversation
  Stream<QuerySnapshot> getMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get conversation ID from two user IDs
  String getConversationId(String userId1, String userId2) {
    final ids = [userId1, userId2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  // Private method for internal use
  String _getConversationId(String userId1, String userId2) {
    return getConversationId(userId1, userId2);
  }

  // Get other user info from conversation
  Future<Map<String, dynamic>?> getOtherUserInfo(
      String conversationId, String currentUserId) async {
    try {
      final doc = await _firestore.collection('conversations').doc(conversationId).get();
      if (!doc.exists) {
        // If conversation doesn't exist yet, try to extract user ID from conversation ID
        // Conversation ID format: userId1_userId2 (sorted)
        final parts = conversationId.split('_');
        if (parts.length == 2) {
          final otherUserId = parts[0] == currentUserId ? parts[1] : parts[0];
          final userDoc = await _firestore.collection('users').doc(otherUserId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            return {
              'userId': otherUserId,
              'fullName': userData['fullName'] ?? 'Unknown',
              'username': userData['username'] ?? 'unknown',
              'profilePictureUrl': userData['profilePictureUrl'] ?? '',
            };
          }
        }
        return null;
      }

      final participants = List<String>.from(doc['participants'] ?? []);
      final otherUserId = participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );

      if (otherUserId.isEmpty) return null;

      final userDoc = await _firestore.collection('users').doc(otherUserId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      return {
        'userId': otherUserId,
        'fullName': userData['fullName'] ?? 'Unknown',
        'username': userData['username'] ?? 'unknown',
        'profilePictureUrl': userData['profilePictureUrl'] ?? '',
      };
    } catch (e) {
      return null;
    }
  }

  // Check if current user is following the other user
  Future<bool> isFollowing(String otherUserId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final followDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .doc(otherUserId)
          .get();

      return followDoc.exists;
    } catch (e) {
      return false;
    }
  }

  // Send a message to a club
  Future<String?> sendClubMessage({
    required String clubId,
    required String message,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not authenticated';

      // Get club info
      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      final clubName = clubDoc.data()?['clubName'] ?? 'Club';
      final memberIds = List<String>.from(clubDoc.data()?['memberIds'] ?? []);

      // Add message to club messages collection
      await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('messages')
          .add({
        'senderId': user.uid,
        'senderName': user.displayName ?? 'Unknown',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'sentAt': FieldValue.serverTimestamp(),
        'receivedAt': null,
        'seenBy': {},
      });

      // Update club's last message
      await _firestore.collection('clubs').doc(clubId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': user.uid,
      });

      // Get sender name and send notification to all members except sender
      final senderDoc = await _firestore.collection('users').doc(user.uid).get();
      final senderName = senderDoc.data()?['fullName'] ?? 'Someone';
      
      final otherMembers = memberIds.where((id) => id != user.uid).toList();
      
      await NotificationUtil.sendClubMessageNotification(
        clubId: clubId,
        clubName: clubName,
        senderName: senderName,
        message: message,
        memberIds: otherMembers,
      );

      return null;
    } catch (e) {
      return 'Error sending message: ${e.toString()}';
    }
  }

  // Mark message as seen
  Future<void> markMessageAsSeen(String clubId, String messageId, String userId) async {
    try {
      await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('messages')
          .doc(messageId)
          .update({
        'seenBy.$userId': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Error marking message as seen
    }
  }

  // Get message read status
  Future<Map<String, dynamic>?> getMessageStatus(String clubId, String messageId) async {
    try {
      final doc = await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('messages')
          .doc(messageId)
          .get();
      
      if (doc.exists) {
        return {
          'sentAt': doc.data()?['sentAt'],
          'receivedAt': doc.data()?['receivedAt'],
          'seenBy': doc.data()?['seenBy'] ?? {},
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get club messages
  Stream<QuerySnapshot> getClubMessages(String clubId) {
    return _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get user's clubs
  Stream<QuerySnapshot> getUserClubs() {
    final user = _auth.currentUser;
    if (user == null) return Stream.empty();

    return _firestore
        .collection('clubs')
        .where('memberIds', arrayContains: user.uid)
        .snapshots();
  }

  // Search users for messaging
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username', isLessThan: '${query.toLowerCase()}z')
          .limit(10)
          .get();

      return snapshot.docs
          .where((doc) => doc.id != currentUser.uid)
          .map((doc) {
            final data = doc.data();
            return {
              'userId': doc.id,
              'fullName': data['fullName'] ?? 'Unknown',
              'username': data['username'] ?? 'unknown',
              'profilePictureUrl': data['profilePictureUrl'] ?? '',
            };
          })
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Search clubs for messaging
  Future<List<Map<String, dynamic>>> searchClubs(String query) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final snapshot = await _firestore
          .collection('clubs')
          .where('memberIds', arrayContains: currentUser.uid)
          .limit(10)
          .get();

      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            final clubName = (data['clubName'] ?? '').toString().toLowerCase();
            return clubName.contains(query.toLowerCase());
          })
          .map((doc) {
            final data = doc.data();
            return {
              'clubId': doc.id,
              'clubName': data['clubName'] ?? 'Unnamed Club',
              'memberCount': (data['memberIds'] as List?)?.length ?? 0,
            };
          })
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Advanced search for messages screen
  Future<List<Map<String, dynamic>>> advancedSearch(String query) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final results = <Map<String, dynamic>>[];
      final queryLower = query.toLowerCase();

      // Get current user's following and followers
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data();
      final following = List<String>.from(userData?['following'] ?? []);
      final followers = List<String>.from(userData?['followers'] ?? []);
      final blockedUsers = List<String>.from(userData?['blockedUsers'] ?? []);

      // Get user's clubs (admin and member)
      final userClubsSnapshot = await _firestore
          .collection('clubs')
          .where('memberIds', arrayContains: currentUser.uid)
          .get();
      final userClubIds = userClubsSnapshot.docs.map((doc) => doc.id).toSet();
      final adminClubIds = userClubsSnapshot.docs
          .where((doc) => (doc.data()['adminId'] as String?) == currentUser.uid)
          .map((doc) => doc.id)
          .toSet();

      // Search users based on 6 criteria
      final allUsersSnapshot = await _firestore.collection('users').get();
      final searchedUsers = <String>{};

      for (final userDoc in allUsersSnapshot.docs) {
        if (userDoc.id == currentUser.uid) continue;

        final userData = userDoc.data();
        final userName = (userData['fullName'] ?? '').toString().toLowerCase();
        final username = (userData['username'] ?? '').toString().toLowerCase();
        final isBlocked = blockedUsers.contains(userDoc.id);

        bool shouldInclude = false;

        // Criteria 1: I have followed that person
        if (following.contains(userDoc.id)) {
          shouldInclude = true;
        }

        // Criteria 2: That person has followed me
        if (followers.contains(userDoc.id)) {
          shouldInclude = true;
        }

        // Criteria 3: We follow each other
        if (following.contains(userDoc.id) && followers.contains(userDoc.id)) {
          shouldInclude = true;
        }

        // Criteria 4 & 5: Shared club membership
        final userClubsSnapshot = await _firestore
            .collection('clubs')
            .where('memberIds', arrayContains: userDoc.id)
            .get();

        for (final clubDoc in userClubsSnapshot.docs) {
          final clubId = clubDoc.id;
          // Criteria 4: Person is part of a club I'm admin of
          if (adminClubIds.contains(clubId)) {
            shouldInclude = true;
            break;
          }
          // Criteria 5: Person is part or admin of a club I'm part of
          if (userClubIds.contains(clubId)) {
            shouldInclude = true;
            break;
          }
        }

        // Check if name/username matches query
        if (userName.contains(queryLower) || username.contains(queryLower)) {
          if (shouldInclude || isBlocked) {
            searchedUsers.add(userDoc.id);
            results.add({
              'userId': userDoc.id,
              'fullName': userData['fullName'] ?? 'Unknown',
              'username': userData['username'] ?? 'unknown',
              'profilePictureUrl': userData['profilePictureUrl'] ?? '',
              'isBlocked': isBlocked,
            });
          }
        }
      }

      // Search clubs based on criteria 6
      for (final clubDoc in userClubsSnapshot.docs) {
        final clubData = clubDoc.data();
        final clubName = (clubData['clubName'] ?? '').toString().toLowerCase();

        if (clubName.contains(queryLower)) {
          results.add({
            'type': 'club',
            'clubId': clubDoc.id,
            'clubName': clubData['clubName'] ?? 'Unnamed Club',
            'memberCount': (clubData['memberIds'] as List?)?.length ?? 0,
          });
        }
      }

      return results;
    } catch (e) {
      return [];
    }
  }
}
