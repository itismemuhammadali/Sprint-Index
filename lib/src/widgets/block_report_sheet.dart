import 'package:flutter/material.dart';
import 'package:sports_chat_app/src/services/report_service.dart';
import 'package:sports_chat_app/src/widgets/report_dialog.dart';

class BlockReportSheet extends StatelessWidget {
  final String? postId;
  final String? userId;
  final String? userName;
  final String? fullName;
  final bool isPostOwner;
  final VoidCallback? onPostDeleted;

  const BlockReportSheet({
    super.key,
    this.postId,
    this.userId,
    this.userName,
    this.fullName,
    this.isPostOwner = false,
    this.onPostDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              isPostOwner ? 'Post Options' : 'Report or Block',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Options
          if (!isPostOwner) ...[
            // Report Post (if postId is provided)
            if (postId != null)
              _buildOption(
                context,
                icon: Icons.flag_outlined,
                title: 'Report Post',
                subtitle: 'Report this post for inappropriate content',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(context, 'post');
                },
              ),
            
            // Report User (if userId is provided)
            if (userId != null)
              _buildOption(
                context,
                icon: Icons.person_off_outlined,
                title: 'Report ${fullName ?? userName ?? 'User'}',
                subtitle: 'Report this user for inappropriate behavior',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(context, 'user');
                },
              ),
            
            // Block User (if userId is provided)
            if (userId != null)
              _buildOption(
                context,
                icon: Icons.block,
                title: 'Block ${fullName ?? userName ?? 'User'}',
                subtitle: 'You won\'t see their posts or messages',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _showBlockConfirmation(context);
                },
              ),
          ] else ...[
            // Delete Post (for post owner)
            if (postId != null)
              _buildOption(
                context,
                icon: Icons.delete_outline,
                title: 'Delete Post',
                subtitle: 'Permanently remove this post',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context);
                },
              ),
          ],
          
          const SizedBox(height: 10),
          
          // Cancel button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (context) => ReportDialog(
        type: type,
        postId: postId,
        userId: userId,
        userName: fullName ?? userName,
      ),
    );
  }

  void _showBlockConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Block ${fullName ?? userName ?? 'User'}?'),
        content: Text(
          'You won\'t see their posts, stories, or be able to message each other. They won\'t be notified that you blocked them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (userId != null) {
                final success = await ReportService.blockUser(userId!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? '${fullName ?? userName ?? 'User'} has been blocked'
                            : 'Failed to block user',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Post?'),
        content: const Text(
          'This post will be permanently deleted and cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onPostDeleted?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
