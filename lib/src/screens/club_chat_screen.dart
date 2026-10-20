import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sports_chat_app/src/services/message_service.dart';
import 'package:sports_chat_app/src/services/club_service.dart';
import 'package:sports_chat_app/src/services/image_cache_service.dart';
import 'package:sports_chat_app/src/screens/club_settings_sheet.dart';
import 'package:sports_chat_app/src/screens/club_profile_screen.dart';

class ClubChatScreen extends StatefulWidget {
  final String clubId;
  final String clubName;

  const ClubChatScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<ClubChatScreen> createState() => _ClubChatScreenState();
}

class _ClubChatScreenState extends State<ClubChatScreen> {
  final _messageController = TextEditingController();
  final _messageService = MessageService();
  final _clubService = ClubService();
  final _auth = FirebaseAuth.instance;
  late bool _isAdmin = false;
  late bool _onlyAdminCanMessage = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _clubService.isAdmin(widget.clubId);
    final onlyAdminCanMessage = await _clubService.isOnlyAdminCanMessage(widget.clubId);
    setState(() {
      _isAdmin = isAdmin;
      _onlyAdminCanMessage = onlyAdminCanMessage;
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final error = await _messageService.sendClubMessage(
      clubId: widget.clubId,
      message: _messageController.text.trim(),
    );

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }

    _messageController.clear();
  }

  Future<void> _showClubSettings() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ClubSettingsSheet(
        clubId: widget.clubId,
        clubName: widget.clubName,
        isAdmin: _isAdmin,
        onSettingsUpdated: _checkAdminStatus,
      ),
    );
  }

  Future<void> _showLeaveOptions() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Club'),
        content: const Text('What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _leaveClub();
            },
            child: const Text('Leave Club'),
          ),
          if (_isAdmin)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _leaveAndDeleteClub();
              },
              child: const Text('Leave & Delete Club', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Future<void> _leaveClub() async {
    final error = await _clubService.exitClub(widget.clubId);
    if (mounted) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _leaveAndDeleteClub() async {
    final error = await _clubService.deleteClub(widget.clubId);
    if (mounted) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      } else {
        Navigator.pop(context);
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
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FutureBuilder<Map<String, dynamic>?>(
                  future: _clubService.getClubDetails(widget.clubId),
                  builder: (context, snapshot) {
                    return ClubProfileScreen(
                      clubId: widget.clubId,
                      clubName: widget.clubName,
                      clubData: snapshot.data,
                    );
                  },
                ),
              ),
            );
          },
          child: Row(
            children: [
              FutureBuilder<Map<String, dynamic>?>(
                future: _clubService.getClubDetails(widget.clubId),
                builder: (context, snapshot) {
                  final clubData = snapshot.data;
                  final profilePicUrl = clubData?['profilePictureUrl'] as String?;
                  final clubName = clubData?['clubName'] as String? ?? widget.clubName;

                  return ImageCacheService.loadProfileImage(
                    imageUrl: profilePicUrl ?? '',
                    radius: 16,
                    fallbackInitial: clubName[0].toUpperCase(),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                widget.clubName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.black),
              onPressed: _showClubSettings,
            ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.red),
            onPressed: _showLeaveOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messageService.getClubMessages(widget.clubId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final messageId = messages[index].id;
                    final isCurrentUser = message['senderId'] == _auth.currentUser?.uid;
                    final timestamp = (message['timestamp'] as Timestamp?)?.toDate();
                    final senderId = message['senderId'] as String?;
                    final seenBy = (message['seenBy'] as Map?)?.keys.toList() ?? [];

                    if (!isCurrentUser && _auth.currentUser != null) {
                      _messageService.markMessageAsSeen(
                        widget.clubId,
                        messageId,
                        _auth.currentUser!.uid,
                      );
                    }

                    bool showName = false;
                    if (!isCurrentUser) {
                      if (index > 0) {
                        final previousMessage =
                            messages[index - 1].data() as Map<String, dynamic>;
                        final previousSenderId = previousMessage['senderId'] as String?;
                        if (previousSenderId != senderId) {
                          showName = true;
                        }
                      } else {
                        showName = true;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        crossAxisAlignment: isCurrentUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (showName)
                            Padding(
                              padding: const EdgeInsets.only(left: 12, bottom: 4),
                              child: FutureBuilder<Map<String, dynamic>?>(
                                future: _getUserInfo(senderId),
                                builder: (context, userSnapshot) {
                                  final userName =
                                      userSnapshot.data?['fullName'] as String? ??
                                          'Unknown';
                                  return Text(
                                    userName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  );
                                },
                              ),
                            ),
                          Row(
                            mainAxisAlignment: isCurrentUser
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isCurrentUser && showName)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8, bottom: 2),
                                  child: FutureBuilder<Map<String, dynamic>?>(
                                    future: _getUserInfo(senderId),
                                    builder: (context, userSnapshot) {
                                      final userData = userSnapshot.data;
                                      final profilePicUrl =
                                          userData?['profilePictureUrl'] as String?;
                                      final userName =
                                          userData?['fullName'] as String? ?? 'Unknown';

                                      return RepaintBoundary(
                                        child: ImageCacheService.loadProfileImage(
                                          imageUrl: profilePicUrl ?? '',
                                          radius: 18,
                                          fallbackInitial: userName[0].toUpperCase(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              if (!isCurrentUser && !showName)
                                const SizedBox(width: 44),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrentUser
                                        ? const Color(0xFFFF8C00)
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isCurrentUser
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message['message'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isCurrentUser
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      if (timestamp != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            _formatTime(timestamp),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isCurrentUser
                                                  ? Colors.grey[300]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      if (isCurrentUser && seenBy.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Seen by ${seenBy.length}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[300],
                                            ),
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
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_onlyAdminCanMessage || _isAdmin,
                    decoration: InputDecoration(
                      hintText: _onlyAdminCanMessage && !_isAdmin
                          ? 'Only admins can message'
                          : 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(color: Colors.black),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: (!_onlyAdminCanMessage || _isAdmin) ? _sendMessage : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (!_onlyAdminCanMessage || _isAdmin)
                          ? const Color(0xFFFF8C00)
                          : Colors.grey[400],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _getUserInfo(String? userId) async {
    if (userId == null) return null;

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
    } catch (e) {
      // Error fetching user info
    }
    return null;
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
