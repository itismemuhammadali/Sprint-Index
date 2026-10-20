import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:sports_chat_app/src/services/club_service.dart';
import 'package:sports_chat_app/src/services/image_cache_service.dart';
import 'package:sports_chat_app/src/screens/osm_location_picker_screen.dart';

class ClubSettingsSheet extends StatefulWidget {
  final String clubId;
  final String clubName;
  final bool isAdmin;
  final VoidCallback onSettingsUpdated;

  const ClubSettingsSheet({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.isAdmin,
    required this.onSettingsUpdated,
  });

  @override
  State<ClubSettingsSheet> createState() => _ClubSettingsSheetState();
}

class _ClubSettingsSheetState extends State<ClubSettingsSheet> {
  final _clubService = ClubService();
  final _firestore = FirebaseFirestore.instance;
  final _clubNameController = TextEditingController();
  final _locationController = TextEditingController();
  late Map<String, dynamic> _clubData = {};
  bool _isLoading = true;
  bool _isSaving = false;
  static const List<String> _availableSports = [
    'Football',
    'Basketball',
    'Tennis',
    'Cricket',
    'Rugby',
    'Athletics/Track & Field',
  ];

  @override
  void initState() {
    super.initState();
    _loadClubData();
  }

  @override
  void dispose() {
    _clubNameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadClubData() async {
    final data = await _clubService.getClubDetails(widget.clubId);
    setState(() {
      _clubData = data ?? {};
      _clubNameController.text = _clubData['clubName'] ?? '';
      _locationController.text = _clubData['location'] ?? '';
      _isLoading = false;
    });
  }

  Future<void> _uploadClubPicture() async {
    if (!widget.isAdmin) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('club_pictures/${widget.clubId}');
        await storageRef.putFile(File(image.path));
        final url = await storageRef.getDownloadURL();

        await _clubService.updateClubSettings(
          clubId: widget.clubId,
          profilePictureUrl: url,
        );

        _loadClubData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading picture: $e')),
          );
        }
      }
    }
  }

  Future<void> _removeMember(String memberId) async {
    if (!widget.isAdmin) return;

    final error = await _clubService.removeMemberFromClub(widget.clubId, memberId);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  Future<void> _saveAllChanges() async {
    if (!widget.isAdmin) return;

    setState(() => _isSaving = true);

    try {
      final clubName = _clubNameController.text.trim();
      final location = _locationController.text.trim();

      if (clubName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Club name cannot be empty')),
        );
        setState(() => _isSaving = false);
        return;
      }

      await _clubService.updateClubSettings(
        clubId: widget.clubId,
        clubName: clubName,
        location: location,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully')),
        );
        setState(() => _isSaving = false);
        _loadClubData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving changes: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showSportSelector() async {
    if (!widget.isAdmin) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Sport',
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
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _availableSports.length,
                itemBuilder: (context, index) {
                  final sport = _availableSports[index];
                  final isSelected = _clubData['sport'] == sport;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () async {
                        await _clubService.updateClubSettings(
                          clubId: widget.clubId,
                          sport: sport,
                        );
                        if (mounted && context.mounted) {
                          _loadClubData();
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
          ],
        ),
      ),
    );
  }

  Future<void> _selectLocation() async {
    if (!widget.isAdmin) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OSMLocationPickerScreen(
          initialLatitude: _clubData['latitude'],
          initialLongitude: _clubData['longitude'],
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _locationController.text = result['locationName'] ?? '';
        _clubData['latitude'] = result['latitude'];
        _clubData['longitude'] = result['longitude'];
      });
    }
  }

  Future<void> _showAddMembersDialog() async {
    if (!widget.isAdmin) return;

    final allUsersSnapshot = await _firestore.collection('users').get();
    final currentMembers =
        List<String>.from(_clubData['memberIds'] ?? []);

    final availableUsers = allUsersSnapshot.docs
        .where((doc) => !currentMembers.contains(doc.id))
        .map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'fullName': data['fullName'] ?? 'Unknown',
            'username': data['username'] ?? 'unknown',
            'profilePictureUrl': data['profilePictureUrl'] ?? '',
          };
        })
        .toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddMembersSheet(
        clubId: widget.clubId,
        availableUsers: availableUsers,
        onMembersAdded: _loadClubData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Club Settings',
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
              const SizedBox(height: 24),
              if (widget.isAdmin)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Club Picture',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _uploadClubPicture,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _clubData['profilePictureUrl'] != null
                            ? NetworkImage(_clubData['profilePictureUrl'])
                            : null,
                        child: _clubData['profilePictureUrl'] == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.add_photo_alternate,
                                    size: 40,
                                    color: Color(0xFFFF8C00),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add Picture',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              const Text(
                'Club Name',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.isAdmin)
                TextField(
                  controller: _clubNameController,
                  decoration: InputDecoration(
                    hintText: 'Enter club name',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _clubData['clubName'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Sport',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.isAdmin)
                GestureDetector(
                  onTap: _showSportSelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFF8C00),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _clubData['sport'] ?? 'Select sport',
                          style: TextStyle(
                            fontSize: 14,
                            color: _clubData['sport'] != null
                                ? Colors.black
                                : Colors.grey[600],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFFFF8C00),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _clubData['sport'] ?? 'Not specified',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Location',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.isAdmin)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _selectLocation,
                        icon: const Icon(Icons.location_on, size: 20),
                        label: Text(
                          _locationController.text.isEmpty
                              ? 'Select Location'
                              : _locationController.text,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _locationController.text.isNotEmpty
                              ? const Color(0xFFFF8C00)
                              : Colors.grey[300],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _clubData['location'] ?? 'Not specified',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Members',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  if (widget.isAdmin)
                    ElevatedButton.icon(
                      onPressed: _showAddMembersDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8C00),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('clubs').doc(widget.clubId).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator(color: Color(0xFFFF8C00));
                  }

                  final memberIds =
                      List<String>.from(snapshot.data?.get('memberIds') ?? []);

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: memberIds.length,
                    itemBuilder: (context, index) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('users').doc(memberIds[index]).get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) {
                            return const SizedBox.shrink();
                          }

                          final userData = userSnapshot.data?.data() as Map?;
                          final userName = userData?['fullName'] ?? 'Unknown';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                ),
                                if (widget.isAdmin)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                    onPressed: () => _removeMember(memberIds[index]),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              if (widget.isAdmin)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Permissions',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<DocumentSnapshot>(
                      stream: _firestore.collection('clubs').doc(widget.clubId).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox.shrink();
                        }

                        final data = snapshot.data?.data() as Map<String, dynamic>?;
                        final onlyAdminCanMessage = data?['onlyAdminCanMessage'] as bool? ?? false;
                        final onlyAdminCanEditSettings = data?['onlyAdminCanEditSettings'] as bool? ?? true;

                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Only Admins Can Message',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: onlyAdminCanMessage,
                                    onChanged: (value) async {
                                      await _clubService.updateClubSettings(
                                        clubId: widget.clubId,
                                        onlyAdminCanMessage: value,
                                      );
                                      widget.onSettingsUpdated();
                                    },
                                    activeThumbColor: const Color(0xFFFF8C00),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Only Admins Can Edit Settings',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: onlyAdminCanEditSettings,
                                    onChanged: (value) async {
                                      await _clubService.updateClubSettings(
                                        clubId: widget.clubId,
                                        onlyAdminCanEditSettings: value,
                                      );
                                      widget.onSettingsUpdated();
                                    },
                                    activeThumbColor: const Color(0xFFFF8C00),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              if (widget.isAdmin)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveAllChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C00),
                      disabledBackgroundColor: Colors.grey[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
}

class AddMembersSheet extends StatefulWidget {
  final String clubId;
  final List<Map<String, dynamic>> availableUsers;
  final VoidCallback onMembersAdded;

  const AddMembersSheet({
    super.key,
    required this.clubId,
    required this.availableUsers,
    required this.onMembersAdded,
  });

  @override
  State<AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<AddMembersSheet> {
  final _clubService = ClubService();
  final _searchController = TextEditingController();
  late List<Map<String, dynamic>> _filteredUsers;
  final Set<String> _selectedUsers = {};

  @override
  void initState() {
    super.initState();
    _filteredUsers = widget.availableUsers;
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = widget.availableUsers;
      } else {
        _filteredUsers = widget.availableUsers.where((user) {
          final fullName = (user['fullName'] ?? '').toString().toLowerCase();
          final username = (user['username'] ?? '').toString().toLowerCase();
          return fullName.contains(query) || username.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _addSelectedMembers() async {
    for (final userId in _selectedUsers) {
      await _clubService.addMemberToClub(widget.clubId, userId);
    }
    if (mounted) {
      widget.onMembersAdded();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Members',
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filteredUsers.length,
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                final isSelected = _selectedUsers.contains(user['id']);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedUsers.remove(user['id']);
                        } else {
                          _selectedUsers.add(user['id']);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.orange[50] : Colors.white,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF8C00)
                              : Colors.grey[300]!,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          RepaintBoundary(
                            child: ImageCacheService.loadProfileImage(
                              imageUrl: user['profilePictureUrl']?.toString() ?? '',
                              radius: 20,
                              fallbackInitial: user['fullName'][0].toUpperCase(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['fullName'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  '@${user['username']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedUsers.add(user['id']);
                                } else {
                                  _selectedUsers.remove(user['id']);
                                }
                              });
                            },
                            activeColor: const Color(0xFFFF8C00),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedUsers.isEmpty ? null : _addSelectedMembers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C00),
                  disabledBackgroundColor: Colors.grey[400],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Add Members',
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
    );
  }
}
