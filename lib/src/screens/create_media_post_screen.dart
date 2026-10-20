import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sports_chat_app/src/services/post_service.dart';

class CreateMediaPostScreen extends StatefulWidget {
  final XFile mediaFile;
  final bool isVideo;
  final String? clubId;

  const CreateMediaPostScreen({
    super.key,
    required this.mediaFile,
    required this.isVideo,
    this.clubId,
  });

  @override
  State<CreateMediaPostScreen> createState() => _CreateMediaPostScreenState();
}

class _CreateMediaPostScreenState extends State<CreateMediaPostScreen> {
  final TextEditingController _captionController = TextEditingController();
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  
  // Post options
  bool _isPermanent = true;
  String _selectedDuration = '24h';
  bool _allowComments = true;
  bool _allowDislikes = true;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initializeVideoPlayer();
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (kIsWeb) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.mediaFile.path),
      );
    } else {
      _videoController = VideoPlayerController.file(File(widget.mediaFile.path));
    }
    await _videoController!.initialize();
    setState(() {});
    _videoController!.setLooping(true);
    _videoController!.play();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    setState(() => _isLoading = true);
    
    try {
      String mediaUrl;
      
      // For web development, use a placeholder URL since CORS blocks Firebase Storage uploads
      // On mobile or production, this will upload properly
      if (kIsWeb) {
        // Use the local blob URL as placeholder for web testing
        mediaUrl = widget.mediaFile.path;
        
        // Show info that this is a test post
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note: Using local URL for web testing. Deploy to mobile for full functionality.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Upload media to Firebase Storage for mobile
        try {
          final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${widget.mediaFile.name}';
          final String mediaType = widget.isVideo ? 'videos' : 'images';
          final Reference storageRef = FirebaseStorage.instance
              .ref()
              .child('posts')
              .child(mediaType)
              .child(fileName);
          
          final uploadTask = await storageRef.putFile(File(widget.mediaFile.path));
          mediaUrl = await uploadTask.ref.getDownloadURL();
        } catch (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload error: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
      
      // Create post in Firestore
      final postService = PostService();
      final error = await postService.createMediaPost(
        mediaUrl: mediaUrl,
        mediaType: widget.isVideo ? 'video' : 'photo',
        caption: _captionController.text.trim(),
        isPermanent: _isPermanent,
        duration: _isPermanent ? null : _selectedDuration,
        allowComments: _allowComments,
        allowDislikes: _allowDislikes,
        clubId: widget.clubId,
      );
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'New Post',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _createPost,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF8C00),
                          ),
                        )
                      : const Text(
                          'Post',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF8C00),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Media Preview
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: widget.isVideo
                          ? _videoController != null && _videoController!.value.isInitialized
                              ? AspectRatio(
                                  aspectRatio: _videoController!.value.aspectRatio,
                                  child: VideoPlayer(_videoController!),
                                )
                              : Container(
                                  height: 300,
                                  color: Colors.black,
                                  child: const Center(
                                    child: CircularProgressIndicator(color: Colors.white),
                                  ),
                                )
                          : kIsWeb
                              ? Image.network(
                                  widget.mediaFile.path,
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
                                )
                              : Image.file(
                                  File(widget.mediaFile.path),
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Caption field
                    TextField(
                      controller: _captionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add a caption...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF8C00)),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Post Type Section
                    const Text(
                      'Post Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPostTypeButton(
                            'Permanent',
                            Icons.push_pin,
                            _isPermanent,
                            () => setState(() => _isPermanent = true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPostTypeButton(
                            'Temporary',
                            Icons.access_time,
                            !_isPermanent,
                            () => setState(() => _isPermanent = false),
                          ),
                        ),
                      ],
                    ),
                    
                    // Duration selector for temporary posts
                    if (!_isPermanent) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Duration',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['6h', '12h', '24h', '48h'].map((duration) {
                          return ChoiceChip(
                            label: Text(duration),
                            selected: _selectedDuration == duration,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedDuration = duration);
                              }
                            },
                            selectedColor: const Color(0xFFFF8C00),
                            labelStyle: TextStyle(
                              color: _selectedDuration == duration
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Post Settings
                    const Text(
                      'Post Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildToggleOption(
                      'Allow Comments',
                      Icons.comment,
                      _allowComments,
                      (value) => setState(() => _allowComments = value),
                    ),
                    const SizedBox(height: 12),
                    _buildToggleOption(
                      'Allow Dislikes',
                      Icons.thumb_down,
                      _allowDislikes,
                      (value) => setState(() => _allowDislikes = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostTypeButton(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF8C00) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[700], size: 24),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFFFF8C00),
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
