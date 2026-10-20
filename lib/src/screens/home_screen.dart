import 'package:flutter/material.dart';
import 'package:sports_chat_app/src/widgets/bottom_navbar.dart';
import 'package:sports_chat_app/src/tabs/posted_tab.dart';
import 'package:sports_chat_app/src/tabs/temporary_tab.dart';
import 'package:sports_chat_app/src/tabs/suggested_tab.dart';
import 'package:sports_chat_app/src/screens/events_screen.dart';
import 'package:sports_chat_app/src/tabs/create_post_tab.dart';
import 'package:sports_chat_app/src/screens/discover_people_screen.dart';
import 'package:sports_chat_app/src/screens/map_screen_wrapper.dart';
import 'package:sports_chat_app/src/screens/profile_screen.dart';
import 'package:sports_chat_app/src/screens/messages_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  int _currentNavIndex = 0;

  Widget _getNavScreen() {
    switch (_currentNavIndex) {
      case 0:
        return _buildFeedScreen();
      case 1:
        return const DiscoverPeopleScreen();
      case 2:
        return _buildMapScreen();
      case 3:
        return _buildMessagesScreen();
      case 4:
        return _buildProfileScreen();
      default:
        return _buildFeedScreen();
    }
  }

  Widget _buildMapScreen() {
    return const MapScreenWrapper();
  }

  Widget _buildMessagesScreen() {
    return const MessagesScreen();
  }

  Widget _buildProfileScreen() {
    return const ProfileScreen();
  }

  Widget _buildFeedScreen() {
    return Column(
      children: [
        AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'lib/assets/logo1.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          title: RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(
                  text: 'Sprint',
                  style: TextStyle(color: Colors.black),
                ),
                TextSpan(
                  text: 'Index',
                  style: TextStyle(color: Color(0xFFFF8C00)),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today, color: Colors.black),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EventsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_circle_up_rounded, color: Colors.black, size: 32),
              padding: const EdgeInsets.only(right: 8, left: 16),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const CreatePostTab(),
                );
              },
            ),
          ],
        ),
        // Tab bar
        Container(
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTabItem('Posted', 0),
              _buildTabItem('Temporary', 1),
              _buildTabItem('Suggested', 2),
            ],
          ),
        ),
        // Content area
        Expanded(
          child: _getTabContent(_currentTabIndex),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: _getNavScreen(),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentNavIndex,
          onTap: (index) {
            setState(() {
              _currentNavIndex = index;
            });
          },
        ),
      ),
    );
  }

  Widget _buildTabItem(String label, int index) {
    final isSelected = _currentTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? const Color(0xFFFF8C00)
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            children: [
              if (index == 0)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFF8C00)
                        : Colors.grey[400],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 16,
                    color: Colors.white,
                  ),
                )
              else if (index == 1)
                Icon(
                  Icons.schedule,
                  color: isSelected
                      ? const Color(0xFFFF8C00)
                      : Colors.grey[400],
                  size: 24,
                )
              else
                Icon(
                  Icons.lightbulb_outline,
                  color: isSelected
                      ? const Color(0xFFFF8C00)
                      : Colors.grey[400],
                  size: 24,
                ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? const Color(0xFFFF8C00)
                      : Colors.grey[400],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getTabContent(int index) {
    switch (index) {
      case 0:
        return const PostedTab();
      case 1:
        return const TemporaryTab();
      case 2:
        return const SuggestedTab();
      default:
        return const PostedTab();
    }
  }
}
