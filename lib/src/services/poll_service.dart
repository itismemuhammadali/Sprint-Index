import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PollService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create poll
  Future<void> createPoll({
    required String question,
    required List<String> options,
    required String? timeLimit,
    required List<String> taggedUserIds,
    required List<String> taggedClubIds,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      // Calculate end time based on time limit
      DateTime? endTime;
      if (timeLimit == '6h') {
        endTime = DateTime.now().add(const Duration(hours: 6));
      } else if (timeLimit == '24h') {
        endTime = DateTime.now().add(const Duration(hours: 24));
      } else if (timeLimit == '72h') {
        endTime = DateTime.now().add(const Duration(hours: 72));
      }

      // Initialize vote counts for each option
      final voteMap = <String, int>{};
      for (var option in options) {
        voteMap[option] = 0;
      }

      await _firestore.collection('polls').add({
        'userId': user.uid,
        'userName': userData?['fullName'] ?? 'Unknown',
        'userProfilePic': userData?['profilePictureUrl'] ?? '',
        'question': question,
        'options': options,
        'votes': voteMap,
        'timeLimit': timeLimit,
        'endTime': endTime,
        'taggedUserIds': taggedUserIds,
        'taggedClubIds': taggedClubIds,
        'createdAt': FieldValue.serverTimestamp(),
        'visibility': 'followers',
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get all polls
  Stream<QuerySnapshot> getAllPolls() {
    return _firestore
        .collection('polls')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get active polls (not expired)
  Stream<QuerySnapshot> getActivePolls() {
    return _firestore
        .collection('polls')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Vote on poll
  Future<void> voteOnPoll({
    required String pollId,
    required String selectedOption,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final pollDoc = await _firestore.collection('polls').doc(pollId).get();
      final pollData = pollDoc.data() as Map<String, dynamic>;
      final votes = Map<String, int>.from(pollData['votes'] ?? {});

      // Increment vote count for selected option
      if (votes.containsKey(selectedOption)) {
        votes[selectedOption] = (votes[selectedOption] ?? 0) + 1;
      }

      // Record user's vote
      await _firestore
          .collection('polls')
          .doc(pollId)
          .collection('userVotes')
          .doc(user.uid)
          .set({
        'selectedOption': selectedOption,
        'votedAt': FieldValue.serverTimestamp(),
      });

      // Update poll votes
      await _firestore.collection('polls').doc(pollId).update({
        'votes': votes,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Check if user has voted on poll
  Future<bool> hasUserVoted(String pollId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final voteDoc = await _firestore
          .collection('polls')
          .doc(pollId)
          .collection('userVotes')
          .doc(user.uid)
          .get();

      return voteDoc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get user's vote on poll
  Future<String?> getUserVote(String pollId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final voteDoc = await _firestore
          .collection('polls')
          .doc(pollId)
          .collection('userVotes')
          .doc(user.uid)
          .get();

      if (voteDoc.exists) {
        return voteDoc.data()?['selectedOption'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Remove user's vote from poll
  Future<void> removeVoteFromPoll({
    required String pollId,
    required String selectedOption,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final pollDoc = await _firestore.collection('polls').doc(pollId).get();
      final pollData = pollDoc.data() as Map<String, dynamic>;
      final votes = Map<String, int>.from(pollData['votes'] ?? {});

      // Decrement vote count for selected option
      if (votes.containsKey(selectedOption) && votes[selectedOption]! > 0) {
        votes[selectedOption] = votes[selectedOption]! - 1;
      }

      // Delete user's vote record
      await _firestore
          .collection('polls')
          .doc(pollId)
          .collection('userVotes')
          .doc(user.uid)
          .delete();

      // Update poll votes
      await _firestore.collection('polls').doc(pollId).update({
        'votes': votes,
      });
    } catch (e) {
      rethrow;
    }
  }
}
