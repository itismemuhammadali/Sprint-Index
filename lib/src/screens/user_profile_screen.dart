import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sports_chat_app/src/services/follow_service.dart';
import 'package:sports_chat_app/src/screens/chat_screen.dart';
import 'package:sports_chat_app/src/widgets/block_report_sheet.dart';
import 'package:sports_chat_app/src/screens/profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _followService = FollowService();

  String _bio = '';
  String _location = '';
  String _fullName = '';
  List<String> _selectedSports = [];
  String _profilePictureUrl = '';
  int _totalPosts = 0;
  int _followers = 0;
  int _following = 0;
  bool _isLoading = true;
  bool _isFollowing = false;

  List<QueryDocumentSnapshot> _photoPostDocs = [];
  List<QueryDocumentSnapshot> _textPostDocs = [];
  List<QueryDocumentSnapshot> _temporaryPostDocs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      // Load user profile
      final userDoc = await _firestore.collection('users').doc(widget.userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;

        // Load user's location
        String userLocation = '';
        try {
          final locationDoc =
              await _firestore.collection('user_locations').doc(widget.userId).get();
          if (locationDoc.exists) {
            userLocation = locationDoc.data()?['location'] ?? '';
          }
        } catch (e) {
          // Location not found
        }

        // Load user's posts
        final postsSnapshot = await _firestore
            .collection('posts')
            .where('userId', isEqualTo: widget.userId)
            .orderBy('createdAt', descending: true)
            .get();

        final postsList = postsSnapshot.docs.toList();

        final photoPosts = <Map<String, dynamic>>[];
        final photoPostDocs = <QueryDocumentSnapshot>[];
        final textPosts = <Map<String, dynamic>>[];
        final textPostDocs = <QueryDocumentSnapshot>[];
        final temporaryPosts = <Map<String, dynamic>>[];
        final temporaryPostDocs = <QueryDocumentSnapshot>[];

        for (var doc in postsList) {
          final postData = doc.data();
          final isPermanent = postData['isPermanent'] ?? true;
          final hasImage = postData['imageUrl'] != null && postData['imageUrl'].toString().isNotEmpty;
          final hasText = postData['text'] != null && postData['text'].toString().isNotEmpty;

          final post = {
            'id': doc.id,
            ...postData,
          };

          if (isPermanent) {
            // Permanent posts: separate by content type
            if (hasImage && !hasText) {
              // Photo only
              photoPosts.add(post);
              photoPostDocs.add(doc);
            } else if (hasText && !hasImage) {
              // Text only
              textPosts.add(post);
              textPostDocs.add(doc);
            }
            // If both text and image, don't show in permanent tabs
          } else {
            // Temporary posts: show both text and photos
            temporaryPosts.add(post);
            temporaryPostDocs.add(doc);
          }
        }

        // Load user's sports
        List<String> userSports = [];
        try {
          final sportsDoc = await _firestore.collection('user_sports').doc(widget.userId).get();
          if (sportsDoc.exists) {
            final data = sportsDoc.data()!;
            int i = 1;
            while (data.containsKey('sport$i')) {
              userSports.add(data['sport$i'] as String);
              i++;
            }
          }
        } catch (e) {
          userSports = [];
        }

        // Get follower/following counts
        final followersCount = await _followService.getFollowersCount(widget.userId);
        final followingCount = await _followService.getFollowingCount(widget.userId);

        // Check if current user is following this user
        final currentUser = _auth.currentUser;
        bool isFollowing = false;
        if (currentUser != null && currentUser.uid != widget.userId) {
          final followDoc = await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('following')
              .doc(widget.userId)
              .get();
          isFollowing = followDoc.exists;
        }

        setState(() {
          _fullName = userData['fullName'] ?? 'User';
          _bio = (userData['bio'] ?? '').toString().isEmpty
              ? 'New to SprintIndex! Let\'s connect\nand get active together.'
              : userData['bio'].toString();
          _location = userLocation;
          _selectedSports = userSports;
          _profilePictureUrl = userData['profilePictureUrl'] ?? '';
          _photoPostDocs = photoPostDocs;
          _textPostDocs = textPostDocs;
          _temporaryPostDocs = temporaryPostDocs;
          _totalPosts = postsList.length;
          _followers = followersCount;
          _following = followingCount;
          _isFollowing = isFollowing;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      if (_isFollowing) {
        final error = await _followService.unfollowUser(widget.userId);
        if (error != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
        } else {
          setState(() {
            _isFollowing = false;
            _followers--;
          });
        }
      } else {
        final error = await _followService.followUser(widget.userId);
        if (error != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
        } else {
          setState(() {
            _isFollowing = true;
            _followers++;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _openChat() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final conversationId = _getConversationId(currentUser.uid, widget.userId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversationId,
          recipientId: widget.userId,
          recipientName: _fullName.isNotEmpty ? _fullName : 'User',
          recipientUsername: widget.userName,
          recipientProfilePicture: _profilePictureUrl,
        ),
      ),
    );
  }

  void _showUserOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlockReportSheet(
        userId: widget.userId,
        userName: widget.userName,
        fullName: _fullName,
        isPostOwner: false,
      ),
    );
  }

  String _getConversationId(String userId1, String userId2) {
    final ids = [userId1, userId2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    final isOwnProfile = currentUser?.uid == widget.userId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '@${widget.userName}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!isOwnProfile)
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onPressed: () => _showUserOptions(context),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF8C00),
              ),
            )
          : Column(
              children: [
                // Profile Header
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
                                  _bio,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.4,
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
                            child: (_profilePictureUrl.isNotEmpty)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      _profilePictureUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.grey[500],
                                        );
                                      },
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.grey[500],
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
                                      _location.isEmpty ? 'Unknown' : _location,
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
                              child: _selectedSports.isEmpty
                                  ? Row(
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
                                            'No Sports',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: _selectedSports.map((sport) {
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFF8C00),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                sport,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Total Posts', _totalPosts),
                          _buildStatItem('Followers', _followers),
                          _buildStatItem('Following', _following),
                          _buildStatItem('Temporary', 0),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Follow/Message buttons
                      if (!isOwnProfile)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _toggleFollow,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isFollowing
                                      ? Colors.grey[300]
                                      : const Color(0xFFFF8C00),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  elevation: 0,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isFollowing ? Icons.check_circle : Icons.person_add,
                                      size: 16,
                                      color: _isFollowing ? Colors.black : Colors.white,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _isFollowing ? 'Following' : 'Follow',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _isFollowing ? Colors.black : Colors.white,
                                      ),
                                    ),
                                    Text(
                                      _isFollowing ? 'See their posts' : 'Get updates',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: _isFollowing ? Colors.black54 : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _openChat();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2196F3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  elevation: 0,
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.message,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Message',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.feed, size: 22),
                        text: 'Posts',
                      ),
                      Tab(
                        icon: Icon(Icons.text_fields, size: 22),
                        text: 'Text',
                      ),
                      Tab(
                        icon: Icon(Icons.schedule, size: 22),
                        text: 'Temporary',
                      ),
                      Tab(
                        icon: Icon(Icons.groups, size: 22),
                        text: 'Clubs',
                      ),
                    ],
                  ),
                ),
                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Posts Tab - Photos only
                      _photoPostDocs.isEmpty
                          ? _buildEmptyState(
                              icon: Icons.feed,
                              title: 'No Photos Yet',
                              subtitle: 'When they share photos, they will appear here',
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(8),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: _photoPostDocs.length,
                              itemBuilder: (context, index) {
                                final post = _photoPostDocs[index].data() as Map<String, dynamic>;
                                final postId = _photoPostDocs[index].id;
                                
                                return GestureDetector(
                                  onTap: () => _showPostDetail(post, postId),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      post['imageUrl'] ?? '',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.broken_image),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                      // Text Tab - Text only
                      _textPostDocs.isEmpty
                          ? _buildEmptyState(
                              icon: Icons.text_fields,
                              title: 'No Text Posts Yet',
                              subtitle: 'When they share text posts, they will appear here',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _textPostDocs.length,
                              itemBuilder: (context, index) {
                                final post = _textPostDocs[index].data() as Map<String, dynamic>;
                                final postId = _textPostDocs[index].id;
                                final timestamp = post['createdAt'] as Timestamp?;
                                final date = timestamp?.toDate();
                                final timeAgo = date != null ? _getTimeAgo(date) : '';

                                return GestureDetector(
                                  onTap: () => _showPostDetail(post, postId),
                                  child: Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            post['text'] ?? '',
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            timeAgo,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                      // Temporary Tab - Both text and photos
                      _temporaryPostDocs.isEmpty
                          ? _buildEmptyState(
                              icon: Icons.schedule,
                              title: 'No Temporary Posts',
                              subtitle: 'Temporary posts will appear here',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _temporaryPostDocs.length,
                              itemBuilder: (context, index) {
                                final post = _temporaryPostDocs[index].data() as Map<String, dynamic>;
                                final postId = _temporaryPostDocs[index].id;
                                final hasImage = post['imageUrl'] != null && 
                                    post['imageUrl'].toString().isNotEmpty;
                                final timestamp = post['createdAt'] as Timestamp?;
                                final date = timestamp?.toDate();
                                final timeAgo = date != null ? _getTimeAgo(date) : '';

                                return GestureDetector(
                                  onTap: () => _showPostDetail(post, postId),
                                  child: Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (hasImage)
                                          ClipRRect(
                                            borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(4),
                                            ),
                                            child: Image.network(
                                              post['imageUrl'] ?? '',
                                              width: double.infinity,
                                              height: 200,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  height: 200,
                                                  color: Colors.grey[300],
                                                  child: const Icon(Icons.broken_image),
                                                );
                                              },
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if ((post['text'] ?? '').toString().isNotEmpty)
                                                Text(
                                                  post['text'] ?? '',
                                                  style: const TextStyle(fontSize: 14),
                                                ),
                                              if ((post['text'] ?? '').toString().isNotEmpty)
                                                const SizedBox(height: 8),
                                              Text(
                                                'Posted $timeAgo',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                      // Clubs Tab
                      _buildEmptyState(
                        icon: Icons.groups,
                        title: 'No Clubs',
                        subtitle: 'Clubs will appear here',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showPostDetail(Map<String, dynamic> post, String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostDetailModal(post: {...post, 'id': postId}),
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
}
