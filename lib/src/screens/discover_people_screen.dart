import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sports_chat_app/src/services/follow_service.dart';
import 'package:sports_chat_app/src/services/club_join_service.dart';
import 'package:sports_chat_app/src/services/image_cache_service.dart';
import 'package:sports_chat_app/src/screens/user_profile_screen.dart';
import 'package:sports_chat_app/src/screens/club_profile_screen.dart';

class DiscoverPeopleScreen extends StatefulWidget {
  const DiscoverPeopleScreen({super.key});

  @override
  State<DiscoverPeopleScreen> createState() => _DiscoverPeopleScreenState();
}

class _DiscoverPeopleScreenState extends State<DiscoverPeopleScreen> {
  final _searchController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _followService = FollowService();
  final _clubJoinService = ClubJoinService();
  
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  List<Map<String, dynamic>> _suggestedUsers = [];
  List<Map<String, dynamic>> _allClubs = [];
  List<Map<String, dynamic>> _filteredClubs = [];
  List<Map<String, dynamic>> _suggestedClubs = [];
  
  bool _isLoading = true;
  String _searchQuery = '';
  Set<String> _followingUsers = {};
  Set<String> _joinedClubs = {};
  Set<String> _pendingJoinRequests = {};
  
  double? _userLatitude;
  double? _userLongitude;
  static const double _nearbyRadiusKm = 50;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
    _loadFollowingList();
    _loadJoinedClubs();
    _loadPendingRequests();
    _loadUsersAndClubs();
    _searchController.addListener(_filterUsers);
  }

  Future<void> _loadUsersAndClubs() async {
    await Future.wait([
      _loadUsers(),
      _loadClubs(),
    ]);
    // After both complete, generate suggested lists
    if (mounted) {
      setState(() {
        _loadSuggestedUsers();
        _loadSuggestedClubs();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _userLatitude = position.latitude;
        _userLongitude = position.longitude;
      });
    } catch (e) {
      // Location error, continue without it
    }
  }

  bool _isNearby(double? latitude, double? longitude) {
    if (_userLatitude == null || _userLongitude == null || latitude == null || longitude == null) {
      return true; // Show as nearby if location not set
    }
    final distance = Geolocator.distanceBetween(
      _userLatitude!,
      _userLongitude!,
      latitude,
      longitude,
    );
    return distance <= (_nearbyRadiusKm * 1000); // Convert km to meters
  }

  Future<void> _loadFollowingList() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .get();
      setState(() {
        _followingUsers = snapshot.docs.map((doc) => doc.id).toSet();
      });
    } catch (e) {
      // Error loading following list
    }
  }

  Future<void> _loadJoinedClubs() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      final snapshot = await _firestore
          .collection('clubs')
          .where('memberIds', arrayContains: currentUser.uid)
          .get();
      setState(() {
        _joinedClubs = snapshot.docs.map((doc) => doc.id).toSet();
      });
    } catch (e) {
      debugPrint('Error loading joined clubs: $e');
    }
  }

  Future<void> _loadPendingRequests() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      final snapshot = await _firestore
          .collection('clubJoinRequests')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();
      setState(() {
        _pendingJoinRequests = snapshot.docs.map((doc) => doc['clubId'] as String).toSet();
      });
    } catch (e) {
      debugPrint('Error loading pending requests: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      final snapshot = await _firestore.collection('users').get();
      final users = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        if (doc.id == currentUserId) continue;
        final data = doc.data();
        String userSports = 'Not specified';
        try {
          final sportsDoc = await _firestore
              .collection('user_sports')
              .doc(doc.id)
              .get();
          if (sportsDoc.exists) {
            final sportsData = sportsDoc.data()!;
            final sports = <String>[];
            int i = 1;
            while (sportsData.containsKey('sport$i')) {
              sports.add(sportsData['sport$i'] as String);
              i++;
            }
            if (sports.isNotEmpty) {
              final uniqueSports = sports.toSet().toList();
              userSports = uniqueSports.join(', ');
            }
          }
        } catch (e) {
          userSports = 'Not specified';
        }
        users.add({
          'id': doc.id,
          'username': data['username'] ?? 'Unknown',
          'fullName': data['fullName'] ?? 'Unknown User',
          'email': data['email'] ?? '',
          'location': data['location'] ?? 'Unknown',
          'sport': userSports,
          'age': data['age'] ?? 0,
          'isPrivate': data['isPrivate'] ?? false,
          'profilePictureUrl': data['profilePictureUrl'] ?? '',
          'latitude': data['latitude'] as double?,
          'longitude': data['longitude'] as double?,
        });
      }
      if (mounted) {
        setState(() {
          _allUsers = users;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadClubs() async {
    try {
      final snapshot = await _firestore.collection('clubs').get();
      final clubs = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        clubs.add({
          'id': doc.id,
          'clubName': data['clubName'] ?? 'Unknown Club',
          'sport': data['sport'] ?? 'Not specified',
          'location': data['location'] ?? 'Unknown',
          'adminId': data['adminId'] ?? '',
          'memberIds': List<String>.from(data['memberIds'] ?? []),
          'profilePictureUrl': data['profilePictureUrl'] ?? '',
          'latitude': data['latitude'] as double?,
          'longitude': data['longitude'] as double?,
        });
      }
      if (mounted) {
        setState(() {
          _allClubs = clubs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading clubs: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredUsers = [];
        _filteredClubs = [];
      } else {
        _filteredUsers = _allUsers.where((user) {
          final username = (user['username'] ?? '').toLowerCase();
          final fullName = (user['fullName'] ?? '').toLowerCase();
          final email = (user['email'] ?? '').toLowerCase();
          return username.contains(query) ||
              fullName.contains(query) ||
              email.contains(query);
        }).toList();
        _filteredClubs = _allClubs.where((club) {
          final clubName = (club['clubName'] ?? '').toLowerCase();
          final sport = (club['sport'] ?? '').toLowerCase();
          return clubName.contains(query) || sport.contains(query);
        }).toList();
      }
    });
  }

  void _loadSuggestedUsers() {
    _suggestedUsers = _allUsers
        .where((user) => !_followingUsers.contains(user['id']))
        .toList();
    _suggestedUsers.sort((a, b) {
      final aSport = (a['sport'] ?? '').toString().trim();
      final bSport = (b['sport'] ?? '').toString().trim();
      bool aHasSport = aSport.isNotEmpty;
      bool bHasSport = bSport.isNotEmpty;
      return bHasSport ? -1 : (aHasSport ? 1 : 0);
    });
  }

  void _loadSuggestedClubs() {
    _suggestedClubs = _allClubs
        .where((club) => !_joinedClubs.contains(club['id']))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Discover',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search people or clubs...',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 15,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[600],
                          size: 24,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF8C00),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_searchQuery.isNotEmpty) ...[
                            _buildSearchResults(),
                            if (_filteredClubs.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              _buildSearchClubResults(),
                            ],
                          ] else ...[
                            _buildSuggestedUsers(),
                            const SizedBox(height: 24),
                            _buildSuggestedClubs(),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_filteredUsers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'No users found',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        ..._filteredUsers
            .map((user) => _buildUserCard(
                  id: user['id'] ?? '',
                  name: user['fullName'] ?? 'Unknown',
                  username: user['username'] ?? 'unknown',
                  location: user['location'] ?? 'Unknown',
                  sport: user['sport'] ?? 'Not specified',
                  isNearby: _isNearby(user['latitude'] as double?, user['longitude'] as double?),
                  profilePictureUrl: user['profilePictureUrl'],
                )),
      ],
    );
  }

  Widget _buildSuggestedUsers() {
    if (_suggestedUsers.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: const Color(0xFFFF8C00),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Suggested People',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._suggestedUsers
            .take(10)
            .map((user) => _buildUserCard(
                  id: user['id'] ?? '',
                  name: user['fullName'] ?? 'Unknown',
                  username: user['username'] ?? 'unknown',
                  location: user['location'] ?? 'Unknown',
                  sport: user['sport'] ?? 'Not specified',
                  isNearby: _isNearby(user['latitude'] as double?, user['longitude'] as double?),
                  profilePictureUrl: user['profilePictureUrl'],
                )),
      ],
    );
  }

  Widget _buildSearchClubResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Clubs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ..._filteredClubs
            .map((club) => _buildClubCard(
                  id: club['id'] ?? '',
                  name: club['clubName'] ?? 'Unknown',
                  sport: club['sport'] ?? 'Not specified',
                  memberCount: (club['memberIds'] as List?)?.length ?? 0,
                  isNearby: _isNearby(club['latitude'] as double?, club['longitude'] as double?),
                )),
      ],
    );
  }

  Widget _buildSuggestedClubs() {
    if (_suggestedClubs.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(
                Icons.groups,
                color: const Color(0xFFFF8C00),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Discover Clubs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._suggestedClubs
            .take(5)
            .map((club) => _buildClubCard(
                  id: club['id'] ?? '',
                  name: club['clubName'] ?? 'Unknown',
                  sport: club['sport'] ?? 'Not specified',
                  memberCount: (club['memberIds'] as List?)?.length ?? 0,
                  isNearby: _isNearby(club['latitude'] as double?, club['longitude'] as double?),
                )),
      ],
    );
  }

  Widget _buildUserCard({
    required String id,
    required String name,
    required String username,
    required String location,
    required bool isNearby,
    required String sport,
    String? profilePictureUrl,
  }) {
    final isFollowing = _followingUsers.contains(id);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(
              userId: id,
              userName: username,
            ),
          ),
        ).then((_) {
          _loadFollowingList();
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ImageCacheService.loadProfileImage(
                  imageUrl: profilePictureUrl ?? '',
                  radius: 22.5,
                  fallbackInitial: name.isNotEmpty ? name[0].toUpperCase() : '?',
                ),
                if (isNearby)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Nearby',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    sport,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _toggleFollow(id),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing
                    ? Colors.grey[300]
                    : const Color(0xFFFF8C00),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                elevation: 0,
              ),
              child: Text(
                isFollowing ? 'Following' : 'Follow',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isFollowing ? Colors.black : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClubCard({
    required String id,
    required String name,
    required String sport,
    required int memberCount,
    bool isNearby = false,
  }) {
    final hasPendingRequest = _pendingJoinRequests.contains(id);
    final isJoined = _joinedClubs.contains(id);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClubProfileScreen(
              clubId: id,
              clubName: name,
            ),
          ),
        ).then((_) {
          _loadJoinedClubs();
          _loadPendingRequests();
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C00),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (isNearby)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Nearby',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  '$sport • $memberCount members',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: (isJoined || hasPendingRequest)
                ? null
                : () => _requestToJoinClub(id),
            style: ElevatedButton.styleFrom(
              backgroundColor: isJoined
                  ? Colors.grey[300]
                  : hasPendingRequest
                      ? Colors.orange[300]
                      : const Color(0xFFFF8C00),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              elevation: 0,
            ),
            child: Text(
              isJoined ? 'Joined' : hasPendingRequest ? 'Pending' : 'Ask',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isJoined || hasPendingRequest
                    ? Colors.grey[600]
                    : Colors.white,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _toggleFollow(String userId) async {
    try {
      if (_followingUsers.contains(userId)) {
        final error = await _followService.unfollowUser(userId);
        if (error == null) {
          setState(() {
            _followingUsers.remove(userId);
          });
        }
      } else {
        final error = await _followService.followUser(userId);
        if (error == null) {
          setState(() {
            _followingUsers.add(userId);
          });
        }
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
    }
  }

  Future<void> _requestToJoinClub(String clubId) async {
    final error = await _clubJoinService.requestToJoinClub(clubId);
    if (mounted) {
      if (error == null) {
        setState(() {
          _pendingJoinRequests.add(clubId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Join request sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
