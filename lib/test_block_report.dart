import 'package:flutter/material.dart';
import 'package:sports_chat_app/src/widgets/report_dialog.dart';
import 'package:sports_chat_app/src/widgets/block_report_sheet.dart';

class TestBlockReportScreen extends StatelessWidget {
  const TestBlockReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Block & Report'),
        backgroundColor: const Color(0xFFFF8C00),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Block & Report Functionality Test',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const ReportDialog(
                    type: 'post',
                    postId: 'test_post_id',
                  ),
                );
              },
              child: const Text('Test Report Post Dialog'),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const ReportDialog(
                    type: 'user',
                    userId: 'test_user_id',
                    userName: 'TestUser',
                  ),
                );
              },
              child: const Text('Test Report User Dialog'),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const BlockReportSheet(
                    postId: 'test_post_id',
                    userId: 'test_user_id',
                    userName: 'TestUser',
                    fullName: 'Test User Full Name',
                    isPostOwner: false,
                  ),
                );
              },
              child: const Text('Test Block/Report Sheet (Other User\'s Post)'),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const BlockReportSheet(
                    postId: 'test_post_id',
                    userId: 'test_user_id',
                    isPostOwner: true,
                  ),
                );
              },
              child: const Text('Test Block/Report Sheet (Own Post)'),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const BlockReportSheet(
                    userId: 'test_user_id',
                    userName: 'TestUser',
                    fullName: 'Test User Full Name',
                    isPostOwner: false,
                  ),
                );
              },
              child: const Text('Test User Profile Block/Report'),
            ),
            
            const SizedBox(height: 20),
            
            const Text(
              'Features Added:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('✅ Report posts with multiple reasons'),
            const Text('✅ Report users with multiple reasons'),
            const Text('✅ Block users from posts and profiles'),
            const Text('✅ Block/Report sheet for posts'),
            const Text('✅ Block/Report options in user profiles'),
            const Text('✅ Delete post option for post owners'),
            const Text('✅ Reports stored in Firestore for moderation'),
            const Text('✅ Prevents duplicate reports'),
            const Text('✅ Removes follow relationships when blocking'),
          ],
        ),
      ),
    );
  }
}