import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:sports_chat_app/src/screens/settings_screen.dart';
import 'package:sports_chat_app/src/screens/create_club_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  
  String _username = '';
  String _bio = '';
  String _location = '';
  List<String> _selectedSports = [];
  String _profilePictureUrl = '';
  int _totalPosts = 0;
  int _followers = 0;
  int _following = 0;
  int _temporary = 0;
  
  final List<String> _availableSports = [
    'Football',
    'Basketball',
    'Tennis',
    'Cricket',
    'Rugby',
    'Athletics/Track & Field',
  ];
  
  List<Map<String, dynamic>> _photoPosts = [];
  List<Map<String, dynamic>> _textPosts = [];
  List<Map<String, dynamic>> _temporaryPosts = [];
  bool _isLoading = true;
  bool _isUploadingPicture = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadUserData();
    _setupFollowersListener();
  }

  void _setupFollowersListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Listen to followers collection changes
    _firestore
        .collection('users')
        .doc(user.uid)
        .collection('followers')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _followers = snapshot.docs.length;
        });
      }
    });

    // Listen to following collection changes
    _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _following = snapshot.docs.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Load user profile
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          
          // Load user's location from user_locations collection
          String userLocation = '';
          try {
            final locationDoc = await _firestore.collection('user_locations').doc(user.uid).get();
            if (locationDoc.exists) {
              userLocation = locationDoc.data()?['location'] ?? '';
            }
          } catch (e) {
            // Location not found, continue without it
          }
          
          // Load user's posts
          final postsSnapshot = await _firestore
              .collection('posts')
              .where('userId', isEqualTo: user.uid)
              .get();
          
          // Sort in code instead of in query
          final postsList = postsSnapshot.docs.toList();
          postsList.sort((a, b) {
            final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });
          
          final photoPosts = <Map<String, dynamic>>[];
          final textPosts = <Map<String, dynamic>>[];
          final temporaryPosts = <Map<String, dynamic>>[];
          
          for (var doc in postsList) {
            final postData = doc.data();
            final post = {
              'id': doc.id,
              ...postData,
            };
            
            final hasImage = postData['imageUrl'] != null && postData['imageUrl'].toString().isNotEmpty;
            final hasText = postData['text'] != null && postData['text'].toString().isNotEmpty;
            final isPermanent = postData['isPermanent'] ?? true;
            
            // Categorize posts
            if (isPermanent) {
              // Permanent posts: separate by content type
              if (hasImage && !hasText) {
                // Photo only
                photoPosts.add(post);
              } else if (hasText && !hasImage) {
                // Text only
                textPosts.add(post);
              }
              // If both text and image, don't show in permanent tabs
            } else {
              // Temporary posts: show both text and photos
              temporaryPosts.add(post);
            }
          }
          
          // Load user's sports from user_sports collection
          List<String> userSports = [];
          try {
            final sportsDoc = await _firestore.collection('user_sports').doc(user.uid).get();
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

          // Load followers and following counts
          int followersCount = 0;
          int followingCount = 0;
          try {
            final followersSnapshot = await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('followers')
                .count()
                .get();
            followersCount = followersSnapshot.count ?? 0;

            final followingSnapshot = await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('following')
                .count()
                .get();
            followingCount = followingSnapshot.count ?? 0;
          } catch (e) {
            // Error loading counts, use defaults
          }

          setState(() {
            _username = userData['username'] ?? 'User';
            _bio = (userData['bio'] ?? '').toString().isEmpty 
                ? 'New to SprintIndex! Let\'s connect\nand get active together.'
                : userData['bio'].toString();
            _location = userLocation;
            _selectedSports = userSports;
            _profilePictureUrl = userData['profilePictureUrl'] ?? '';
            _photoPosts = photoPosts;
            _textPosts = textPosts;
            _temporaryPosts = temporaryPosts;
            _totalPosts = postsList.length;
            _temporary = temporaryPosts.length;
            _followers = followersCount;
            _following = followingCount;
            _isLoading = false;
          });
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _username.isEmpty ? 'Profile' : _username,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
              // Refresh profile data after returning from settings
              _loadUserData();
            },
          ),
        ],
      ),
      body: Column(
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
                    // Bio text
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
                    GestureDetector(
                      onTap: _isUploadingPicture ? null : _uploadProfilePicture,
                      child: Stack(
                        children: [
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
                          if (_isUploadingPicture)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          else
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF8C00),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Location and Sport buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectLocation,
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
                                  _location.isEmpty ? 'Add Location' : _location,
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showSportSelector,
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
                                        'Select Sports',
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
                    _buildStatItem('Temporary', _temporary),
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
                  icon: Icon(Icons.photo_camera, size: 22),
                  text: 'Photos',
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
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF8C00),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Photos Tab
                      _photoPosts.isEmpty
                          ? _buildEmptyState(
                              icon: Icons.photo_camera,
                              title: 'No Photos Yet',
                              subtitle: 'Share your sports photos and videos to see them here',
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(8),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: _photoPosts.length,
                              itemBuilder: (context, index) {
                                final post = _photoPosts[index];
                                return GestureDetector(
                                  onTap: () => _showPostDetail(post),
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
                      // Text Tab
                      _textPosts.isEmpty
                          ? _buildEmptyState(
                              icon: Icons.text_fields,
                              title: 'No Text Posts Yet',
                              subtitle: 'Share your thoughts and updates to see them here',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _textPosts.length,
                              itemBuilder: (context, index) {
                                final post = _textPosts[index];
                                final timestamp = (post['createdAt'] as Timestamp?)?.toDate();
                                final timeAgo = timestamp != null ? _getTimeAgo(timestamp) : 'Unknown';
                                
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                post['text'] ?? '',
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                            if (post['isPermanent'] == true)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF2196F3),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  'Permanent',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                          ],
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
                                );
                              },
                            ),
                      // Temporary Tab
                      _temporaryPosts.isEmpty
                          ? _buildEmptyState(
                              icon: Icons.schedule,
                              title: 'No Temporary Posts',
                              subtitle: 'Your temporary posts will appear here',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _temporaryPosts.length,
                              itemBuilder: (context, index) {
                                final post = _temporaryPosts[index];
                                final hasImage = post['imageUrl'] != null && post['imageUrl'].toString().isNotEmpty;
                                final timestamp = (post['createdAt'] as Timestamp?)?.toDate();
                                final timeAgo = timestamp != null ? _getTimeAgo(timestamp) : 'Unknown';
                                
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
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
                                                (post['text'] ?? '').toString(),
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Posted $timeAgo',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFF8C00),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    post['duration'] ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 10,
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
                                    ],
                                  ),
                                );
                              },
                            ),
                      // Clubs Tab
                      _buildClubsTab(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 3
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateClubScreen(),
                  ),
                );
              },
              backgroundColor: const Color(0xFFFF8C00),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Future<void> _showSportSelector() async {
    final selectedSports = List<String>.from(_selectedSports);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollController) => Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Your Sports',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose the sports you\'re interested in',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Sports List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _availableSports.length,
                  itemBuilder: (context, index) {
                    final sport = _availableSports[index];
                    final isSelected = selectedSports.contains(sport);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedSports.remove(sport);
                            } else {
                              selectedSports.add(sport);
                            }
                          });
                        },
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF8C00).withValues(alpha: 0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF8C00)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFF8C00)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFFF8C00)
                                        : Colors.grey[400]!,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  sport,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? const Color(0xFFFF8C00)
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Footer with Save Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Save to Firebase user_sports collection
                      final user = _auth.currentUser;
                      if (user != null) {
                        try {
                          // Create sports map with sport1, sport2, sport3, etc.
                          final sportsMap = <String, String>{};
                          for (int i = 0; i < selectedSports.length; i++) {
                            sportsMap['sport${i + 1}'] = selectedSports[i];
                          }

                          await _firestore.collection('user_sports').doc(user.uid).set({
                            'userId': user.uid,
                            ...sportsMap,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                          if (mounted && context.mounted) {
                            setState(() {
                              _selectedSports = selectedSports;
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sports updated successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error updating sports: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save Sports',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPostDetail(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostDetailModal(post: post),
    );
  }

  Future<void> _selectLocation() async {
    final cityController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Your City'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the city where you\'re located',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cityController,
              decoration: InputDecoration(
                hintText: 'e.g., New York, London, Tokyo',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF8C00),
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(Icons.location_city),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (cityController.text.trim().isNotEmpty) {
                Navigator.pop(context, cityController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C00),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final user = _auth.currentUser;
        if (user != null) {
          // Save location to separate user_locations collection
          await _firestore.collection('user_locations').doc(user.uid).set({
            'userId': user.uid,
            'location': result,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          setState(() {
            _location = result;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating location: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _uploadProfilePicture() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingPicture = true);

      final user = _auth.currentUser;
      if (user == null) return;

      // Upload to Firebase Storage
      final fileName = 'profile_${user.uid}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profiles')
          .child(user.uid)
          .child(fileName);

      await storageRef.putFile(File(pickedFile.path));
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'profilePictureUrl': downloadUrl,
      });

      setState(() {
        _profilePictureUrl = downloadUrl;
        _isUploadingPicture = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingPicture = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
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

  Widget _buildClubsTab() {
    final currentUserId = _auth.currentUser?.uid;
    
    if (currentUserId == null) {
      return const Center(
        child: Text('Not authenticated'),
      );
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('clubs')
          .where('memberIds', arrayContains: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final clubs = snapshot.data?.docs ?? [];

        if (clubs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.groups,
                    size: 50,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No Clubs Yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Create or join clubs to see them here',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ),

              ],
            ),
          );
        }

        return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: clubs.length,
                itemBuilder: (context, index) {
                  final club = clubs[index].data() as Map<String, dynamic>;
                  final clubName = club['clubName'] ?? 'Unnamed Club';
                  final memberCount = (club['memberIds'] as List?)?.length ?? 0;
                  final isAdmin = club['adminId'] == currentUserId;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      clubName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$memberCount members',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF8C00),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Admin',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (club['onlyAdminCanMessage'] == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.blue[200]!,
                                  ),
                                ),
                                child: Text(
                                  'Only admin can message',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
      },
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
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 50,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PostDetailModal extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailModal({
    super.key,
    required this.post,
  });

  @override
  State<PostDetailModal> createState() => _PostDetailModalState();
}

class _PostDetailModalState extends State<PostDetailModal> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _commentsStream;
  int _likes = 0;
  int _dislikes = 0;
  bool _userLiked = false;
  bool _userDisliked = false;

  @override
  void initState() {
    super.initState();
    _commentsStream = _firestore
        .collection('posts')
        .doc(widget.post['id'])
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _loadEngagementData();
  }

  Future<void> _loadEngagementData() async {
    try {
      final postDoc = await _firestore
          .collection('posts')
          .doc(widget.post['id'])
          .get();

      if (postDoc.exists) {
        final data = postDoc.data()!;
        final currentUserId = _auth.currentUser?.uid;

        setState(() {
          _likes = (data['likes'] as List?)?.length ?? 0;
          _dislikes = (data['dislikes'] as List?)?.length ?? 0;
          _userLiked = currentUserId != null && ((data['likes'] as List?)?.contains(currentUserId) ?? false);
          _userDisliked = currentUserId != null && ((data['dislikes'] as List?)?.contains(currentUserId) ?? false);
        });
      }
    } catch (e) {
      debugPrint('Error loading engagement data: $e');
    }
  }

  Future<void> _toggleLike() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final postRef = _firestore.collection('posts').doc(widget.post['id']);

    try {
      if (_userLiked) {
        await postRef.update({
          'likes': FieldValue.arrayRemove([currentUserId]),
        });
        setState(() {
          _userLiked = false;
          _likes--;
        });
      } else {
        await postRef.update({
          'likes': FieldValue.arrayUnion([currentUserId]),
        });
        if (_userDisliked) {
          await postRef.update({
            'dislikes': FieldValue.arrayRemove([currentUserId]),
          });
          setState(() {
            _userDisliked = false;
            _dislikes--;
          });
        }
        setState(() {
          _userLiked = true;
          _likes++;
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  Future<void> _toggleDislike() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final postRef = _firestore.collection('posts').doc(widget.post['id']);

    try {
      if (_userDisliked) {
        await postRef.update({
          'dislikes': FieldValue.arrayRemove([currentUserId]),
        });
        setState(() {
          _userDisliked = false;
          _dislikes--;
        });
      } else {
        await postRef.update({
          'dislikes': FieldValue.arrayUnion([currentUserId]),
        });
        if (_userLiked) {
          await postRef.update({
            'likes': FieldValue.arrayRemove([currentUserId]),
          });
          setState(() {
            _userLiked = false;
            _likes--;
          });
        }
        setState(() {
          _userDisliked = true;
          _dislikes++;
        });
      }
    } catch (e) {
      debugPrint('Error toggling dislike: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.post['imageUrl'] != null && 
        widget.post['imageUrl'].toString().isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48),
                const Text(
                  'Post Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  if (hasImage)
                    Image.network(
                      widget.post['imageUrl'] ?? '',
                      width: double.infinity,
                      height: 300,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 300,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image),
                        );
                      },
                    ),
                  // Post info
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text content
                        if ((widget.post['text'] ?? '').toString().isNotEmpty)
                          Text(
                            widget.post['text'] ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                              height: 1.5,
                            ),
                          ),
                        if ((widget.post['text'] ?? '').toString().isNotEmpty)
                          const SizedBox(height: 16),
                        // Engagement stats
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  _likes.toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Likes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  _dislikes.toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Dislikes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Like/Dislike buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _toggleLike,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _userLiked
                                      ? const Color(0xFF2196F3)
                                      : Colors.grey[300],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.thumb_up,
                                  color: _userLiked ? Colors.white : Colors.grey[700],
                                ),
                                label: Text(
                                  'Like',
                                  style: TextStyle(
                                    color: _userLiked ? Colors.white : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _toggleDislike,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _userDisliked
                                      ? const Color(0xFFFF8C00)
                                      : Colors.grey[300],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.thumb_down,
                                  color: _userDisliked ? Colors.white : Colors.grey[700],
                                ),
                                label: Text(
                                  'Dislike',
                                  style: TextStyle(
                                    color: _userDisliked ? Colors.white : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Comments section
                        const Text(
                          'Comments',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  // Comments list
                  StreamBuilder<QuerySnapshot>(
                    stream: _commentsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No comments yet',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final comment = snapshot.data!.docs[index].data()
                              as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment['userName'] ?? 'Anonymous',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  comment['text'] ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
