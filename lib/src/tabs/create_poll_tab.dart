import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sports_chat_app/src/services/poll_service.dart';

class CreatePollTab extends StatefulWidget {
  const CreatePollTab({super.key});

  @override
  State<CreatePollTab> createState() => _CreatePollTabState();
}

class _CreatePollTabState extends State<CreatePollTab> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  String? _selectedTimeLimit;
  final _pollService = PollService();
  bool _isLoading = false;
  List<String> _taggedUserIds = [];
  List<String> _taggedClubIds = [];

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 32,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Text(
                  'Create Poll',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _createPoll,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8C00)),
                          ),
                        )
                      : const Text(
                          'Create',
                          style: TextStyle(
                            color: Color(0xFFFF8C00),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // Question
            const Text(
              'Question *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _questionController,
              decoration: InputDecoration(
                hintText: 'e.g., What\'s your favorite sport?',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            // Options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Options (2-6) *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                if (_optionControllers.length < 6)
                  GestureDetector(
                    onTap: _addOption,
                    child: const Row(
                      children: [
                        Icon(Icons.add_circle, color: Color(0xFFFF8C00), size: 20),
                        SizedBox(width: 4),
                        Text(
                          'Add Option',
                          style: TextStyle(
                            color: Color(0xFFFF8C00),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _optionControllers.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _optionControllers[index],
                          decoration: InputDecoration(
                            hintText: 'Option ${index + 1}',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      if (_optionControllers.length > 2)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: GestureDetector(
                            onTap: () => _removeOption(index),
                            child: Icon(
                              Icons.cancel,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Poll Time Limit
            const Text(
              'Poll Time Limit (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _buildTimeLimitOption('No Limit', 'Poll stays open', null),
                _buildTimeLimitOption('6 Hours', 'Closes in 6h', '6h'),
                _buildTimeLimitOption('24 Hours', 'Closes in 1 day', '24h'),
                _buildTimeLimitOption('72 Hours', 'Closes in 3 days', '72h'),
              ],
            ),
            const SizedBox(height: 16),
            // Tag People/Clubs
            const Text(
              'Tag People or Clubs (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showUserTagPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_add, color: const Color(0xFFFF8C00), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Tag People (${_taggedUserIds.length})',
                            style: const TextStyle(fontSize: 13, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _showClubTagPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.groups_2, color: const Color(0xFFFF8C00), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Tag Clubs (${_taggedClubIds.length})',
                            style: const TextStyle(fontSize: 13, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Poll Visibility Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Poll Visibility',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All users who follow you will see this poll in their calendar.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _createPoll() async {
    // Validate required fields
    if (_questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a question')),
      );
      return;
    }

    // Check if all options are filled
    final options = _optionControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide at least 2 options')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _pollService.createPoll(
        question: _questionController.text,
        options: options,
        timeLimit: _selectedTimeLimit,
        taggedUserIds: _taggedUserIds,
        taggedClubIds: _taggedClubIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poll created successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating poll: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showUserTagPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => UserTagPickerSheet(
        selectedUserIds: _taggedUserIds,
        onUsersSelected: (userIds) {
          setState(() => _taggedUserIds = userIds);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showClubTagPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ClubTagPickerSheet(
        selectedClubIds: _taggedClubIds,
        onClubsSelected: (clubIds) {
          setState(() => _taggedClubIds = clubIds);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildTimeLimitOption(String title, String subtitle, String? value) {
    final isSelected = _selectedTimeLimit == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeLimit = value;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF8C00).withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF8C00) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (value == null)
              Icon(
                Icons.all_inclusive,
                color: isSelected ? const Color(0xFFFF8C00) : Colors.grey[400],
                size: 28,
              )
            else
              Icon(
                Icons.schedule,
                color: isSelected ? const Color(0xFFFF8C00) : Colors.grey[400],
                size: 28,
              ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFFFF8C00) : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class UserTagPickerSheet extends StatefulWidget {
  final List<String> selectedUserIds;
  final Function(List<String>) onUsersSelected;

  const UserTagPickerSheet({
    super.key,
    required this.selectedUserIds,
    required this.onUsersSelected,
  });

  @override
  State<UserTagPickerSheet> createState() => _UserTagPickerSheetState();
}

class _UserTagPickerSheetState extends State<UserTagPickerSheet> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late List<String> _selectedUsers;

  @override
  void initState() {
    super.initState();
    _selectedUsers = List.from(widget.selectedUserIds);
  }

  Future<List<String>> _getFilteredUsers() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    // Get clubs current user is in
    final clubsSnapshot = await _firestore
        .collection('clubs')
        .where('memberIds', arrayContains: currentUserId)
        .get();

    final clubIds = clubsSnapshot.docs.map((doc) => doc.id).toSet();

    // Get all users in those clubs
    final usersInClubs = <String>{};
    for (final clubId in clubIds) {
      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      final memberIds = List<String>.from(clubDoc.data()?['memberIds'] ?? []);
      usersInClubs.addAll(memberIds);
    }

    // Filter users: only those who are in shared clubs
    final filteredUsers = <String>[];
    for (final userId in usersInClubs) {
      if (userId == currentUserId) continue;
      filteredUsers.add(userId);
    }

    return filteredUsers;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tag People',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: FutureBuilder<List<String>>(
                future: _getFilteredUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data == null) {
                    return const Center(child: Text('No users found'));
                  }

                  final filteredUserIds = snapshot.data!;

                  if (filteredUserIds.isEmpty) {
                    return const Center(
                      child: Text('No users available to tag'),
                    );
                  }

                  return FutureBuilder<QuerySnapshot>(
                    future: _firestore.collection('users').get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allUsers = userSnapshot.data!.docs;
                      final usersToShow = allUsers
                          .where((doc) => filteredUserIds.contains(doc.id))
                          .toList();

                      if (usersToShow.isEmpty) {
                        return const Center(child: Text('No users available'));
                      }

                      return ListView.builder(
                        itemCount: usersToShow.length,
                        itemBuilder: (context, index) {
                          final user = usersToShow[index].data() as Map<String, dynamic>;
                          final userId = usersToShow[index].id;
                          final isSelected = _selectedUsers.contains(userId);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedUsers.add(userId);
                                } else {
                                  _selectedUsers.remove(userId);
                                }
                              });
                            },
                            title: Text(user['fullName'] ?? 'Unknown'),
                            subtitle: Text('@${user['username'] ?? 'unknown'}'),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onUsersSelected(_selectedUsers),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C00),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClubTagPickerSheet extends StatefulWidget {
  final List<String> selectedClubIds;
  final Function(List<String>) onClubsSelected;

  const ClubTagPickerSheet({
    super.key,
    required this.selectedClubIds,
    required this.onClubsSelected,
  });

  @override
  State<ClubTagPickerSheet> createState() => _ClubTagPickerSheetState();
}

class _ClubTagPickerSheetState extends State<ClubTagPickerSheet> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late List<String> _selectedClubs;

  @override
  void initState() {
    super.initState();
    _selectedClubs = List.from(widget.selectedClubIds);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tag Clubs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('clubs')
                .where('memberIds', arrayContains: _auth.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data == null) {
                return const Center(child: Text('No clubs found'));
              }

              final clubs = snapshot.data!.docs;

              if (clubs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('You are not a member of any clubs'),
                );
              }

              return SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: clubs.length,
                  itemBuilder: (context, index) {
                    final club = clubs[index].data() as Map<String, dynamic>;
                    final clubId = clubs[index].id;
                    final isSelected = _selectedClubs.contains(clubId);
                    final memberCount = (club['memberIds'] as List?)?.length ?? 0;

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedClubs.add(clubId);
                          } else {
                            _selectedClubs.remove(clubId);
                          }
                        });
                      },
                      title: Text(club['clubName'] ?? 'Unknown Club'),
                      subtitle: Text('$memberCount members'),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onClubsSelected(_selectedClubs),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C00),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
