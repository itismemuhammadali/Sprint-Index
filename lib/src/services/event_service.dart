import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create event
  Future<void> createEvent({
    required String title,
    required String description,
    required String date,
    required String time,
    required DateTime dateTime,
    required String location,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      await _firestore.collection('events').add({
        'userId': user.uid,
        'userName': userData?['fullName'] ?? 'Unknown',
        'userProfilePic': userData?['profilePictureUrl'] ?? '',
        'title': title,
        'description': description,
        'date': date,
        'time': time,
        'dateTime': dateTime,
        'location': location,
        'createdAt': FieldValue.serverTimestamp(),
        'visibility': 'followers',
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get upcoming events for current user's followers
  Stream<QuerySnapshot> getUpcomingEvents() {
    final user = _auth.currentUser;
    if (user == null) return Stream.empty();

    return _firestore
        .collection('events')
        .where('dateTime', isGreaterThan: DateTime.now())
        .orderBy('dateTime', descending: false)
        .snapshots();
  }

  // Get recently listed events
  Stream<QuerySnapshot> getRecentlyListedEvents() {
    return _firestore
        .collection('events')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  // Get events by user
  Stream<QuerySnapshot> getUserEvents(String userId) {
    return _firestore
        .collection('events')
        .where('userId', isEqualTo: userId)
        .orderBy('dateTime', descending: false)
        .snapshots();
  }
}
