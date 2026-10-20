import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sports_chat_app/src/services/club_join_service.dart';
import 'package:sports_chat_app/src/services/image_cache_service.dart';
import 'package:sports_chat_app/src/tabs/create_post_tab.dart';
import 'package:sports_chat_app/src/utils/post_engagement_util.dart';
import 'package:sports_chat_app/src/tabs/comments_tab.dart';

class ClubProfileScreen extends StatefulWidget {
  final String clubId;
  final String clubName;
  final Map<String, dynamic>? clubData;

  const ClubProfileScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.clubData,
  });

  @override
  State<ClubProfileScreen> createState() => _ClubProfileScreenState();
}

class _ClubProfileScreenState extends State<ClubProfileScreen>
    with TickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _clubJoinService = ClubJoinService();

  late Future<Map<String, dynamic>?> _clubDetailsFuture;
  bool _isJoined = false;
  bool _hasPendingRequest = false;
  bool _isJoining = false;
  bool _isAdmin = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _clubDetailsFuture = widget.clubData != null 
        ? Future.value(widget.clubData)
        : _loadClubDetails();
    _checkMembershipStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadClubDetails() async {
    try {
      final doc = await _firestore.collection('clubs').doc(widget.clubId).get();
      return doc.data();
    } catch (e) {
      debugPrint('Error loading club details: $e');
    }
    return null;
  }

  Stream<List<QueryDocumentSnapshot>> _getClubPosts() {
    return _firestore
        .collection('posts')
        .where('clubId', isEqualTo: widget.clubId)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs.toList();
          docs.sort((a, b) {
            final aTime = (a.data())['createdAt'] as Timestamp?;
            final bTime = (b.data())['createdAt'] as Timestamp?;
            return (bTime?.toDate() ?? DateTime(2000)).compareTo(aTime?.toDate() ?? DateTime(2000));
          });
          return docs;
        });
  }

  Future<void> _checkMembershipStatus() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Check if joined
      final clubDoc = await _firestore.collection('clubs').doc(widget.clubId).get();
      final memberIds = List<String>.from(clubDoc.data()?['memberIds'] ?? []);
      final adminId = clubDoc.data()?['adminId'] as String?;
      _isJoined = memberIds.contains(userId);
      _isAdmin = adminId == userId;

      // Check if pending request
      final requestSnapshot = await _firestore
          .collection('clubJoinRequests')
          .where('userId', isEqualTo: userId)
          .where('clubId', isEqualTo: widget.clubId)
          .where('status', isEqualTo: 'pending')
          .get();
      _hasPendingRequest = requestSnapshot.docs.isNotEmpty;

      // Update TabController if admin status changed
      final tabCount = _isAdmin ? 4 : 3;
      if (_tabController.length != tabCount) {
        _tabController.dispose();
        _tabController = TabController(length: tabCount, vsync: this);
      }

      setState(() {});
    } catch (e) {
      debugPrint('Error checking membership status: $e');
    }
  }

  Future<void> _requestToJoinClub() async {
    setState(() => _isJoining = true);
    try {
      final error = await _clubJoinService.requestToJoinClub(widget.clubId);
      if (mounted) {
        setState(() => _isJoining = false);
        if (error == null) {
          setState(() => _hasPendingRequest = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Join request sent!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveClub() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('clubs').doc(widget.clubId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
      });

      if (mounted) {
        setState(() => _isJoined = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You left the club'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error leaving club: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Stream<List<QueryDocumentSnapshot>> _getJoinRequests() {
    return _firestore
        .collection('clubJoinRequests')
        .where('clubId', isEqualTo: widget.clubId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Future<void> _approveJoinRequest(String requestId, String userId) async {
    try {
      await _firestore.collection('clubJoinRequests').doc(requestId).update({
        'status': 'approved',
      });

      await _firestore.collection('clubs').doc(widget.clubId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectJoinRequest(String requestId) async {
    try {
      await _firestore.collection('clubJoinRequests').doc(requestId).update({
        'status': 'rejected',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Club Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _clubDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text('Club not found'),
            );
          }

          final club = snapshot.data!;
          final memberIds = List<String>.from(club['memberIds'] ?? []);
          final memberCount = memberIds.length;
          final sport = club['sport'] ?? 'Not specified';
          final location = club['location'] ?? 'Unknown';
          final profilePictureUrl = club['profilePictureUrl'] as String?;

          return Column(
            children: [
              // Club Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Bio and Avatar Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.clubName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Avatar
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: (profilePictureUrl != null &&
                                  profilePictureUrl.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    profilePictureUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: const Color(0xFFFF8C00),
                                        child: Center(
                                          child: Text(
                                            widget.clubName.isNotEmpty
                                                ? widget.clubName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontSize: 40,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFFFF8C00),
                                  child: Center(
                                    child: Text(
                                      widget.clubName.isNotEmpty
                                          ? widget.clubName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Location and Sport buttons
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Color(0xFF2196F3),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    location.isEmpty ? 'Unknown' : location,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.sports_soccer,
                                  color: Color(0xFF2196F3),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    sport,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Stats Row
                    StreamBuilder<List<QueryDocumentSnapshot>>(
                      stream: _getClubPosts(),
                      builder: (context, snapshot) {
                        final posts = snapshot.data ?? [];
                        final totalPosts = posts.length;
                        final permanentPosts = posts.where((p) {
                          final data = p.data() as Map<String, dynamic>;
                          return data['isPermanent'] != false;
                        }).length;
                        final temporaryPosts = posts.where((p) {
                          final data = p.data() as Map<String, dynamic>;
                          return data['isTemporary'] == true;
                        }).length;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Total Posts', totalPosts),
                            _buildStatItem('Permanent', permanentPosts),
                            _buildStatItem('Temporary', temporaryPosts),
                            _buildStatItem('Members', memberCount),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons
                    if (_isJoined)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _leaveClub,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Leave',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => CreatePostTab(
                                    clubId: widget.clubId,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF8C00),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Post',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (_hasPendingRequest || _isJoining)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          child: _isJoining
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.grey,
                                  ),
                                )
                              : Text(
                                  'Request Pending',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isJoining ? null : _requestToJoinClub,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8C00),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          child: _isJoining
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Ask to Join',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              // Tabs
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFFFF8C00),
                  unselectedLabelColor: Colors.grey[400],
                  indicatorColor: const Color(0xFFFF8C00),
                  indicatorWeight: 3,
                  tabs: [
                    const Tab(icon: Icon(Icons.feed), text: 'Posts'),
                    const Tab(icon: Icon(Icons.text_fields), text: 'Text'),
                    const Tab(icon: Icon(Icons.schedule), text: 'Temporary'),
                    if (_isAdmin)
                      const Tab(icon: Icon(Icons.person_add), text: 'Requests'),
                  ],
                ),
              ),
              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Posts Tab (Image-based posts only)
                    StreamBuilder<List<QueryDocumentSnapshot>>(
                      stream: _getClubPosts(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
                          );
                        }

                        final posts = snapshot.data ?? [];
                        final imagePosts = posts.where((post) {
                          final data = post.data() as Map<String, dynamic>;
                          final isPermanent = data['isPermanent'] != false;
                          final hasImage = data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty;
                          return isPermanent && hasImage;
                        }).toList();

                        if (imagePosts.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Image Posts Yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: imagePosts.length,
                          itemBuilder: (context, index) {
                            final post = imagePosts[index].data() as Map<String, dynamic>;
                            final postId = imagePosts[index].id;
                            return _buildPostCard(post, postId);
                          },
                        );
                      },
                    ),
                    // Text Tab (Text-only posts)
                    StreamBuilder<List<QueryDocumentSnapshot>>(
                      stream: _getClubPosts(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
                          );
                        }

                        final posts = snapshot.data ?? [];
                        final textPosts = posts.where((post) {
                          final data = post.data() as Map<String, dynamic>;
                          final isPermanent = data['isPermanent'] != false;
                          final hasText = data['text'] != null && data['text'].toString().isNotEmpty;
                          final hasImage = data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty;
                          return isPermanent && hasText && !hasImage;
                        }).toList();

                        if (textPosts.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.text_fields,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Text Posts Yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: textPosts.length,
                          itemBuilder: (context, index) {
                            final post = textPosts[index].data() as Map<String, dynamic>;
                            final postId = textPosts[index].id;
                            return _buildPostCard(post, postId);
                          },
                        );
                      },
                    ),
                    // Temporary Posts Tab
                    StreamBuilder<List<QueryDocumentSnapshot>>(
                      stream: _getClubPosts(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
                          );
                        }

                        final posts = snapshot.data ?? [];
                        final temporaryPosts = posts.where((post) {
                          final data = post.data() as Map<String, dynamic>;
                          return data['isTemporary'] == true;
                        }).toList();

                        if (temporaryPosts.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Temporary Posts',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: temporaryPosts.length,
                          itemBuilder: (context, index) {
                            final post = temporaryPosts[index].data() as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey[200]!,
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post['text'] ?? 'No content',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Posted by ${post['fullName'] ?? 'Unknown'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    // Join Requests Tab (only for admins)
                    if (_isAdmin)
                      StreamBuilder<List<QueryDocumentSnapshot>>(
                        stream: _getJoinRequests(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }

                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
                            );
                          }

                          final requests = snapshot.data ?? [];

                          if (requests.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_add,
                                    size: 64,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Join Requests',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: requests.length,
                            itemBuilder: (context, index) {
                              final request = requests[index].data() as Map<String, dynamic>;
                              final requestId = requests[index].id;
                              final userId = request['userId'] as String?;

                              return FutureBuilder<DocumentSnapshot>(
                                future: _firestore.collection('users').doc(userId).get(),
                                builder: (context, userSnapshot) {
                                  if (!userSnapshot.hasData) {
                                    return const SizedBox.shrink();
                                  }

                                  final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                                  final userName = userData?['fullName'] ?? 'Unknown';
                                  final userUsername = userData?['username'] ?? 'unknown';
                                  final profilePicUrl = userData?['profilePictureUrl'] as String?;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey[200]!),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          RepaintBoundary(
                                            child: ImageCacheService.loadProfileImage(
                                              imageUrl: profilePicUrl ?? '',
                                              radius: 24,
                                              fallbackInitial: userName[0].toUpperCase(),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  userName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  '@$userUsername',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              ElevatedButton(
                                                onPressed: () => _approveJoinRequest(requestId, userId!),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  elevation: 0,
                                                ),
                                                child: const Text(
                                                  'Approve',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () => _rejectJoinRequest(requestId),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  elevation: 0,
                                                ),
                                                child: const Text(
                                                  'Reject',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, String postId) {
    final timestamp = post['createdAt'] as Timestamp?;
    final date = timestamp?.toDate();
    final timeAgo = date != null ? _getTimeAgo(date) : '';

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('posts').doc(postId).snapshots(),
      builder: (context, postSnapshot) {
        final currentPost = postSnapshot.data?.data() as Map<String, dynamic>? ?? post;
        final currentLikesCount = (currentPost['likesCount'] ?? 0) as int;
        final currentDislikesCount = (currentPost['dislikesCount'] ?? 0) as int;
        final currentLikePercentage = PostEngagementUtil.calculateLikePercentage(currentLikesCount, currentDislikesCount);
        final currentDislikePercentage = PostEngagementUtil.calculateDislikePercentage(currentLikesCount, currentDislikesCount);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    RepaintBoundary(
                      child: ImageCacheService.loadProfileImage(
                        imageUrl: post['profilePictureUrl']?.toString() ?? '',
                        radius: 20,
                        fallbackInitial: (post['userName'] ?? 'U')[0].toUpperCase(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post['fullName'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showPostMenu(context, postId, post['userId']),
                      child: Icon(Icons.more_horiz, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              // Content
              if (post['text'] != null && post['text'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    post['text'],
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              // Image
              if (post['imageUrl'] != null && post['imageUrl'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Image.network(
                    post['imageUrl'],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 40),
                        ),
                      );
                    },
                  ),
                ),
              // Engagement bar
              Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Likes button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            await PostEngagementUtil.toggleLike(postId);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.arrow_upward,
                                  color: Colors.green,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$currentLikePercentage%',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Dislikes button
                      if (post['allowDislikes'] == true)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              await PostEngagementUtil.toggleDislike(postId);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.arrow_downward,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$currentDislikePercentage%',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 16),
                      // Comments
                      if (post['allowComments'] == true)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => CommentsTab(
                                  postId: postId,
                                  postAuthorName: post['fullName'] ?? 'Unknown',
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.chat_bubble,
                                    color: const Color(0xFFFF8C00),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${currentPost['commentsCount'] ?? 0}',
                                    style: const TextStyle(
                                      color: Color(0xFFFF8C00),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showPostMenu(BuildContext context, String postId, String? postUserId) {
    final currentUserId = _auth.currentUser?.uid;
    final isPostOwner = currentUserId == postUserId;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPostOwner)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Post'),
                onTap: () {
                  Navigator.pop(context);
                  _deletePost(postId);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Close'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('posts').doc(postId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
