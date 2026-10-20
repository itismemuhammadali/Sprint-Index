import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sports_chat_app/src/utils/post_engagement_util.dart';
import 'package:sports_chat_app/src/services/image_cache_service.dart';
import 'package:sports_chat_app/src/screens/user_profile_screen.dart';
import 'package:sports_chat_app/src/widgets/block_report_sheet.dart';
import 'package:sports_chat_app/src/widgets/banner_ad_widget.dart';
import 'comments_tab.dart';

class TemporaryTab extends StatefulWidget {
  const TemporaryTab({super.key});

  @override
  State<TemporaryTab> createState() => _TemporaryTabState();
}

class _TemporaryTabState extends State<TemporaryTab> {

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('isPermanent', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
          );
        }

        final posts = snapshot.data?.docs ?? [];
        
        // Filter out expired posts
        final now = DateTime.now();
        final activePost = posts.where((doc) {
          final post = doc.data() as Map<String, dynamic>;
          final expiresAt = post['expiresAt'] as Timestamp?;
          if (expiresAt == null) return true; // Keep posts without expiry
          final expiryDate = expiresAt.toDate();
          return expiryDate.isAfter(now); // Only keep posts that haven't expired
        }).toList();

        if (activePost.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.schedule,
                    size: 40,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Temporary Posts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your temporary posts will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _getItemCount(activePost.length),
          itemBuilder: (context, index) {
            // Show ad every 13 posts
            if ((index + 1) % 13 == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    const BannerAdWidget(),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            }

            final postIndex = _getPostIndex(index);
            if (postIndex >= activePost.length) {
              return const SizedBox.shrink();
            }

            final post = activePost[postIndex].data() as Map<String, dynamic>;
            final postId = activePost[postIndex].id;
            return _buildPostCard(post, postId);
          },
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, String postId) {
    final timestamp = post['createdAt'] as Timestamp?;
    final date = timestamp?.toDate();
    final timeAgo = date != null ? _getTimeAgo(date) : '';
    
    final expiresAt = post['expiresAt'] as Timestamp?;
    final expiryDate = expiresAt?.toDate();
    final timeLeft = expiryDate != null ? _getTimeLeft(expiryDate) : '';

    return FutureBuilder<String>(
      future: _getUserSports(post['userId']),
      builder: (context, snapshot) {
        final sportsText = snapshot.data ?? 'Sports';
        
        // Only listen to likes and dislikes counts, not the entire post
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .snapshots(),
          builder: (context, postSnapshot) {
            // Get current counts from stream, fallback to initial post data
            int currentLikesCount = post['likesCount'] ?? 0;
            int currentDislikesCount = post['dislikesCount'] ?? 0;
            int currentCommentsCount = post['commentsCount'] ?? 0;
            
            if (postSnapshot.hasData && postSnapshot.data != null) {
              final data = postSnapshot.data!.data() as Map<String, dynamic>?;
              if (data != null) {
                currentLikesCount = data['likesCount'] ?? currentLikesCount;
                currentDislikesCount = data['dislikesCount'] ?? currentDislikesCount;
                currentCommentsCount = data['commentsCount'] ?? currentCommentsCount;
              }
            }
            
            final currentLikePercentage = PostEngagementUtil.calculateLikePercentage(currentLikesCount, currentDislikesCount);
            final currentDislikePercentage = PostEngagementUtil.calculateDislikePercentage(currentLikesCount, currentDislikesCount);
            
            return _buildPostCardContent(
              context,
              post,
              postId,
              sportsText,
              timeAgo,
              timeLeft,
              currentLikePercentage,
              currentDislikePercentage,
              currentCommentsCount: currentCommentsCount,
            );
          },
        );
      },
    );
  }

  Widget _buildPostCardContent(
    BuildContext context,
    Map<String, dynamic> post,
    String postId,
    String sportsText,
    String timeAgo,
    String timeLeft,
    int likePercentage,
    int dislikePercentage, {
    required int currentCommentsCount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with profile info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreen(
                          userId: post['userId'] ?? '',
                          userName: post['userName'] ?? 'user',
                        ),
                      ),
                    );
                  },
                  child: RepaintBoundary(
                    child: ImageCacheService.loadProfileImage(
                      imageUrl: post['profilePictureUrl']?.toString() ?? '',
                      radius: 24,
                      fallbackInitial: (post['userName'] ?? 'U')[0].toUpperCase(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(
                            userId: post['userId'] ?? '',
                            userName: post['userName'] ?? 'user',
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['fullName'] ?? 'Unknown User',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '$sportsText • $timeAgo',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            if (timeLeft.isNotEmpty) ...[
                              Text(
                                ' • ',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeLeft,
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showPostMenu(context, postId, post['userId']),
                  child: Icon(Icons.more_horiz, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          
          // Text content if available
          if (post['text'] != null && post['text'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                post['text'],
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ),
          
          // Image if available
          if (post['imageUrl'] != null && post['imageUrl'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Image.network(
                post['imageUrl'],
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 300,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 50),
                    ),
                  );
                },
              ),
            ),
          
          // Stats bar at bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Likes button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _toggleLike(postId),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.arrow_upward,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$likePercentage%',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  
                  // Dislikes button
                  if (post['allowDislikes'] == true)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _toggleDislike(postId),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.arrow_downward,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$dislikePercentage%',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  const SizedBox(width: 20),
                  
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
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'View ${currentCommentsCount == 1 ? '1 comment' : '$currentCommentsCount comments'}',
                                style: const TextStyle(
                                  color: Color(0xFFFF8C00),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
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
  }

  Future<String> _getUserSports(String userId) async {
    try {
      final sportsDoc = await FirebaseFirestore.instance
          .collection('user_sports')
          .doc(userId)
          .get();
      
      if (sportsDoc.exists) {
        final data = sportsDoc.data()!;
        final sports = <String>[];
        int i = 1;
        while (data.containsKey('sport$i')) {
          sports.add(data['sport$i'] as String);
          i++;
        }
        // Remove duplicates
        final uniqueSports = sports.toSet().toList();
        return uniqueSports.isNotEmpty ? uniqueSports.join(', ') : 'Sports';
      }
      return 'Sports';
    } catch (e) {
      return 'Sports';
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

  String _getTimeLeft(DateTime expiryDate) {
    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    if (difference.isNegative) {
      return 'Expired';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Expiring soon';
    }
  }

  // Calculate total item count including ads
  int _getItemCount(int postsCount) {
    if (postsCount == 0) return 0;
    final adsCount = (postsCount / 13).ceil();
    return postsCount + adsCount;
  }

  // Get the actual post index from the list view index
  int _getPostIndex(int listIndex) {
    int postIndex = 0;
    int currentIndex = 0;

    while (currentIndex < listIndex) {
      if ((currentIndex + 1) % 13 == 0) {
        currentIndex++;
      } else {
        postIndex++;
        currentIndex++;
      }
    }

    return postIndex;
  }

  Future<void> _toggleLike(String postId) async {
    await PostEngagementUtil.toggleLike(postId);
  }

  Future<void> _toggleDislike(String postId) async {
    await PostEngagementUtil.toggleDislike(postId);
  }

  void _showPostMenu(BuildContext context, String postId, String? postUserId) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isPostOwner = currentUserId == postUserId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlockReportSheet(
        postId: postId,
        userId: isPostOwner ? null : postUserId,
        isPostOwner: isPostOwner,
        onPostDeleted: () => _deletePost(postId),
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
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
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
