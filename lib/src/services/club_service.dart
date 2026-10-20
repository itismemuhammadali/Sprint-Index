import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sports_chat_app/src/services/notification_util.dart';

class ClubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new club
  Future<String?> createClub({
    required String clubName,
    required List<String> memberIds,
    required bool onlyAdminCanMessage,
    String? location,
    double? latitude,
    double? longitude,
    String? sport,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not authenticated';

      // Add current user as admin
      final allMembers = [user.uid, ...memberIds];

      final clubData = {
        'clubName': clubName,
        'adminId': user.uid,
        'memberIds': allMembers,
        'onlyAdminCanMessage': onlyAdminCanMessage,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add location data if provided
      if (location != null && location.isNotEmpty) {
        clubData['location'] = location;
        if (latitude != null && longitude != null) {
          clubData['latitude'] = latitude;
          clubData['longitude'] = longitude;
        }
      }

      // Add sport if provided
      if (sport != null && sport.isNotEmpty) {
        clubData['sport'] = sport;
      }

      final clubRef = await _firestore.collection('clubs').add(clubData);

      // Add club to creator's clubs subcollection
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('clubs')
          .doc(clubRef.id)
          .set({});

      // Add club to all members' clubs subcollection
      for (final memberId in memberIds) {
        await _firestore
            .collection('users')
            .doc(memberId)
            .collection('clubs')
            .doc(clubRef.id)
            .set({});
      }

      // Send club creation notification to all members
      await NotificationUtil.sendClubNotification(
        clubName: clubName,
        action: 'created',
        recipientIds: allMembers,
      );

      return clubRef.id;
    } catch (e) {
      return null;
    }
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

  // Get club details
  Future<Map<String, dynamic>?> getClubDetails(String clubId) async {
    try {
      final doc = await _firestore.collection('clubs').doc(clubId).get();
      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Add member to club
  Future<String?> addMemberToClub(String clubId, String memberId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not authenticated';

      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      if (!clubDoc.exists) return 'Club not found';

      final adminId = clubDoc.data()?['adminId'];
      if (adminId != user.uid) return 'Only admin can add members';

      final clubName = clubDoc.data()?['clubName'] ?? 'Club';
      final currentMembers =
          List<String>.from(clubDoc.data()?['memberIds'] ?? []);

      await _firestore.collection('clubs').doc(clubId).update({
        'memberIds': FieldValue.arrayUnion([memberId]),
      });

      // Get member name
      final memberDoc =
          await _firestore.collection('users').doc(memberId).get();
      final memberName = memberDoc.data()?['fullName'] ?? 'Someone';

      // Send join notification to all members
      await NotificationUtil.sendClubNotification(
        clubName: clubName,
        action: 'joined',
        recipientIds: [...currentMembers, memberId],
        userName: memberName,
      );

      return null;
    } catch (e) {
      return 'Error adding member: ${e.toString()}';
    }
  }

  // Remove member from club
  Future<String?> removeMemberFromClub(String clubId, String memberId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not authenticated';

      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      if (!clubDoc.exists) return 'Club not found';

      final adminId = clubDoc.data()?['adminId'];
      if (adminId != user.uid) return 'Only admin can remove members';

      final clubName = clubDoc.data()?['clubName'] ?? 'Club';
      final currentMembers =
          List<String>.from(clubDoc.data()?['memberIds'] ?? []);

      await _firestore.collection('clubs').doc(clubId).update({
        'memberIds': FieldValue.arrayRemove([memberId]),
      });

      // Send removal notification to removed member
      await NotificationUtil.sendClubNotification(
        clubName: clubName,
        action: 'removed',
        recipientIds: [memberId],
      );

      // Send exit notification to remaining members
      final remainingMembers =
          currentMembers.where((id) => id != memberId).toList();
      if (remainingMembers.isNotEmpty) {
        final memberDoc =
            await _firestore.collection('users').doc(memberId).get();
        final memberName = memberDoc.data()?['fullName'] ?? 'Someone';

        await NotificationUtil.sendClubNotification(
          clubName: clubName,
          action: 'exited',
          recipientIds: remainingMembers,
          userName: memberName,
        );
      }

      return null;
    } catch (e) {
      return 'Error removing member: ${e.toString()}';
    }
  }

  // Delete club
  Future<String?> deleteClub(String clubId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not authenticated';

      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      if (!clubDoc.exists) return 'Club not found';

      final adminId = clubDoc.data()?['adminId'];
      if (adminId != user.uid) return 'Only admin can delete club';

      final clubName = clubDoc.data()?['clubName'] ?? 'Club';
      final memberIds =
          List<String>.from(clubDoc.data()?['memberIds'] ?? []);

      // Delete club
      await _firestore.collection('clubs').doc(clubId).delete();

      // Send deletion notification to all members
      await NotificationUtil.sendClubNotification(
        clubName: clubName,
        action: 'deleted',
        recipientIds: memberIds,
      );

      return null;
    } catch (e) {
      return 'Error deleting club: ${e.toString()}';
    }
  }

  // Exit club
  Future<String?> exitClub(String clubId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not authenticated';

      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      if (!clubDoc.exists) return 'Club not found';

      final clubName = clubDoc.data()?['clubName'] ?? 'Club';
      final currentMembers =
          List<String>.from(clubDoc.data()?['memberIds'] ?? []);

      // Remove user from club
      await _firestore.collection('clubs').doc(clubId).update({
        'memberIds': FieldValue.arrayRemove([user.uid]),
      });

      // Get user name
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['fullName'] ?? 'Someone';

      // Send exit notification to remaining members
      final remainingMembers =
          currentMembers.where((id) => id != user.uid).toList();
      if (remainingMembers.isNotEmpty) {
        await NotificationUtil.sendClubNotification(
          clubName: clubName,
          action: 'exited',
          recipientIds: remainingMembers,
          userName: userName,
        );
      }

      return null;
    } catch (e) {
      return 'Error exiting club: ${e.toString()}';
    }
  }

  // Join club
  Future<String?> joinClub(String clubId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not authenticated';

      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      if (!clubDoc.exists) return 'Club not found';

      final memberIds = List<String>.from(clubDoc.data()?['memberIds'] ?? []);
      if (memberIds.contains(user.uid)) return 'Already a member';

      final clubName = clubDoc.data()?['clubName'] ?? 'Club';

      // Add user to club
      await _firestore.collection('clubs').doc(clubId).update({
        'memberIds': FieldValue.arrayUnion([user.uid]),
      });

      // Add club to user's clubs subcollection
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('clubs')
          .doc(clubId)
          .set({});

      // Get user name
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['fullName'] ?? 'Someone';

      // Send join notification to all members
      await NotificationUtil.sendClubNotification(
        clubName: clubName,
        action: 'joined',
        recipientIds: [...memberIds, user.uid],
        userName: userName,
      );

      return null;
    } catch (e) {
      return 'Error joining club: ${e.toString()}';
    }
  }

  // Update club settings
  Future<String?> updateClubSettings({
    required String clubId,
    String? clubName,
    String? location,
    double? latitude,
    double? longitude,
    String? sport,
    String? profilePictureUrl,
    bool? onlyAdminCanMessage,
    bool? onlyAdminCanEditSettings,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not authenticated';

      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      if (!clubDoc.exists) return 'Club not found';

      final adminId = clubDoc.data()?['adminId'];
      if (adminId != user.uid) return 'Only admin can edit settings';

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (clubName != null) updateData['clubName'] = clubName;
      if (location != null) updateData['location'] = location;
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;
      if (sport != null) updateData['sport'] = sport;
      if (profilePictureUrl != null) updateData['profilePictureUrl'] = profilePictureUrl;
      if (onlyAdminCanMessage != null) updateData['onlyAdminCanMessage'] = onlyAdminCanMessage;
      if (onlyAdminCanEditSettings != null) updateData['onlyAdminCanEditSettings'] = onlyAdminCanEditSettings;

      await _firestore.collection('clubs').doc(clubId).update(updateData);
      return null;
    } catch (e) {
      return 'Error updating club: ${e.toString()}';
    }
  }

  // Check if user is admin
  Future<bool> isAdmin(String clubId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      if (!clubDoc.exists) return false;

      return clubDoc.data()?['adminId'] == user.uid;
    } catch (e) {
      return false;
    }
  }

  // Check if only admin can message
  Future<bool> isOnlyAdminCanMessage(String clubId) async {
    try {
      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      if (!clubDoc.exists) return false;

      return clubDoc.data()?['onlyAdminCanMessage'] ?? false;
    } catch (e) {
      return false;
    }
  }
}
