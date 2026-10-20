import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sports_chat_app/src/services/poll_service.dart';
import 'package:sports_chat_app/src/services/image_cache_service.dart';

class PollsTab extends StatefulWidget {
  const PollsTab({super.key});

  @override
  State<PollsTab> createState() => _PollsTabState();
}

class _PollsTabState extends State<PollsTab> {
  final _pollService = PollService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _pollService.getActivePolls(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
          );
        }

        var polls = snapshot.data?.docs ?? [];
        
        // Filter out expired polls client-side
        polls = polls.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final endTime = data['endTime'] as Timestamp?;
          if (endTime == null) return true; // No limit polls always show
          return endTime.toDate().isAfter(DateTime.now());
        }).toList();

        if (polls.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bar_chart,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Polls',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No polls available at the moment',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: polls.length,
          itemBuilder: (context, index) {
            final poll = polls[index].data() as Map<String, dynamic>;
            final pollId = polls[index].id;
            return _buildPollCard(pollId, poll);
          },
        );
      },
    );
  }

  Widget _buildPollCard(String pollId, Map<String, dynamic> poll) {
    final question = poll['question'] ?? 'Poll';
    final options = List<String>.from(poll['options'] ?? []);
    final votes = Map<String, int>.from(poll['votes'] ?? {});
    final userName = poll['userName'] ?? 'Unknown';
    final userProfilePic = poll['userProfilePic'] ?? '';

    final totalVotes = votes.values.fold<int>(0, (total, voteCount) => total + voteCount);

    return FutureBuilder<String?>(
      future: _pollService.getUserVote(pollId),
      builder: (context, userVoteSnapshot) {
        final userVote = userVoteSnapshot.data;
        return _buildPollCardContent(
          pollId,
          question,
          options,
          votes,
          userName,
          userProfilePic,
          totalVotes,
          userVote,
        );
      },
    );
  }

  Widget _buildPollCardContent(
    String pollId,
    String question,
    List<String> options,
    Map<String, int> votes,
    String userName,
    String userProfilePic,
    int totalVotes,
    String? userVote,
  ) {

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info
          Row(
            children: [
              RepaintBoundary(
                child: ImageCacheService.loadProfileImage(
                  imageUrl: userProfilePic,
                  radius: 20,
                  fallbackInitial: userName[0].toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Question
          Text(
            question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          // Options
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Builder(
                builder: (context) {
                  final voteCount = votes[option] ?? 0;
                  final percentage = totalVotes > 0 ? (voteCount / totalVotes * 100) : 0;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                option,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF8C00),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            minHeight: 6,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF8C00),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          Text(
            '$totalVotes votes',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          if (userVote != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _removeVote(pollId, userVote),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Remove Vote',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Show option selection dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Select an option'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options[index];
                            return ListTile(
                              title: Text(option),
                              onTap: () {
                                Navigator.pop(context);
                                _votePoll(pollId, option);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C00),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Vote',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _votePoll(String pollId, String option) async {
    try {
      await _pollService.voteOnPoll(
        pollId: pollId,
        selectedOption: option,
      );
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vote recorded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error voting: $e')),
        );
      }
    }
  }

  Future<void> _removeVote(String pollId, String option) async {
    try {
      await _pollService.removeVoteFromPoll(
        pollId: pollId,
        selectedOption: option,
      );
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vote removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing vote: $e')),
        );
      }
    }
  }
}
