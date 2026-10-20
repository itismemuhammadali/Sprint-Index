import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initialize() async {
    // Skip notification setup on web
    if (kIsWeb) {
      if (kDebugMode) {
        print('Notification service skipped on web');
      }
      return;
    }

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Request permissions for iOS
    if (!kIsWeb && Platform.isIOS) {
      await _requestIOSPermissions();
    }

    // Request permissions for Android 13+
    if (!kIsWeb && Platform.isAndroid) {
      await _requestAndroidPermissions();
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle terminated state messages (app was completely closed)
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        print('🔔 App opened from terminated state via notification');
      }
      _handleMessageOpenedApp(initialMessage);
    }

    // Handle notification taps from local notifications
    _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (kDebugMode) {
          print('🔔 Local notification tapped: ${response.payload}');
        }
      },
    );

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Get and log device token
    await getDeviceToken();

    if (kDebugMode) {
      print('Notification service initialized');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    // Create notification channels for Android
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Messages channel
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'messages',
          'Messages',
          description: 'Direct messages and club messages',
          importance: Importance.max,
          enableVibration: true,
          enableLights: true,
          showBadge: true,
        ),
      );

      // Social channel
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'social',
          'Social Activity',
          description: 'Likes, comments, and follows',
          importance: Importance.defaultImportance,
          enableVibration: true,
          enableLights: false,
          showBadge: true,
        ),
      );

      // Clubs channel
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'clubs',
          'Club Updates',
          description: 'Club posts, join requests, and member updates',
          importance: Importance.defaultImportance,
          enableVibration: true,
          enableLights: false,
          showBadge: true,
        ),
      );

      // Posts channel
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'posts',
          'New Posts',
          description: 'Posts from people you follow',
          importance: Importance.defaultImportance,
          enableVibration: false,
          enableLights: false,
          showBadge: true,
        ),
      );

      // System channel
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'system',
          'System Notifications',
          description: 'Upload status and system messages',
          importance: Importance.low,
          enableVibration: false,
          enableLights: false,
          showBadge: false,
        ),
      );
    }

    if (kDebugMode) {
      print('✅ Local notifications initialized');
      print('✅ All notification channels created');
    }
  }

  Future<void> _requestIOSPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('iOS notification permission status: ${settings.authorizationStatus}');
    }
  }

  Future<void> _requestAndroidPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('Android notification permission status: ${settings.authorizationStatus}');
    }
  }

  Future<String?> getDeviceToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print('✅ Device FCM Token: $token');
      }
      // Store token in Firestore for current user
      await _storeTokenInFirestore(token);
      return token;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error getting device token: $e');
        print('⚠️ This is normal on emulator without Google Play Services');
        print('⚠️ Retrying in 5 seconds...');
      }
      
      // Retry after delay for emulator
      await Future.delayed(const Duration(seconds: 5));
      try {
        final token = await _firebaseMessaging.getToken();
        if (token != null) {
          if (kDebugMode) {
            print('✅ Device FCM Token (retry): $token');
          }
          await _storeTokenInFirestore(token);
          return token;
        }
      } catch (retryError) {
        if (kDebugMode) {
          print('❌ Retry failed: $retryError');
        }
      }
      return null;
    }
  }

  Future<void> _storeTokenInFirestore(String? token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        if (kDebugMode) {
          print('✅ FCM token stored in Firestore for user: ${user.uid}');
          print('✅ Token: $token');
        }
      } else {
        if (kDebugMode) {
          print('❌ Cannot store token - User: $user, Token: $token');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error storing FCM token: $e');
      }
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Handling a foreground message: ${message.messageId}');
      print('Message data: ${message.data}');
      print('Message notification: ${message.notification?.title}');
    }

    // Show local notification
    _showLocalNotification(message);
    
    // Handle the notification - you can show a dialog, snackbar, or custom UI
    _processNotification(message);
  }

  String _getChannelIdForType(String? notificationType) {
    switch (notificationType) {
      case 'direct_message':
      case 'club_message':
        return 'messages';
      case 'new_follow':
      case 'like':
      case 'dislike':
      case 'comment':
      case 'profile_update':
        return 'social';
      case 'club_join_request':
      case 'club_join_approved':
      case 'club_join_rejected':
      case 'club_post':
      case 'club_created':
      case 'club_joined':
      case 'club_deleted':
      case 'club_removed':
      case 'club_exited':
        return 'clubs';
      case 'follower_post':
      case 'following_post':
      case 'new_post':
      case 'new_club_nearby':
      case 'nearby_club':
        return 'posts';
      case 'post_upload':
      default:
        return 'system';
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      final notificationType = message.data['type'];
      final channelId = _getChannelIdForType(notificationType);

      if (kDebugMode) {
        print('Showing local notification: ${notification.title}');
        print('Channel: $channelId, Type: $notificationType');
      }

      final androidDetails = AndroidNotificationDetails(
        channelId,
        _getChannelNameForId(channelId),
        channelDescription: _getChannelDescriptionForId(channelId),
        importance: _getImportanceForChannel(channelId),
        priority: _getPriorityForChannel(channelId),
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        notificationDetails,
        payload: message.data.toString(),
      );
    }
  }

  String _getChannelNameForId(String channelId) {
    switch (channelId) {
      case 'messages':
        return 'Messages';
      case 'social':
        return 'Social Activity';
      case 'clubs':
        return 'Club Updates';
      case 'posts':
        return 'New Posts';
      case 'system':
        return 'System Notifications';
      default:
        return 'Notifications';
    }
  }

  String _getChannelDescriptionForId(String channelId) {
    switch (channelId) {
      case 'messages':
        return 'Direct messages and club messages';
      case 'social':
        return 'Likes, comments, and follows';
      case 'clubs':
        return 'Club posts, join requests, and member updates';
      case 'posts':
        return 'Posts from people you follow';
      case 'system':
        return 'Upload status and system messages';
      default:
        return 'Notifications';
    }
  }

  Importance _getImportanceForChannel(String channelId) {
    switch (channelId) {
      case 'messages':
        return Importance.max;
      case 'social':
      case 'clubs':
      case 'posts':
        return Importance.defaultImportance;
      case 'system':
        return Importance.low;
      default:
        return Importance.defaultImportance;
    }
  }

  Priority _getPriorityForChannel(String channelId) {
    switch (channelId) {
      case 'messages':
        return Priority.high;
      case 'social':
      case 'clubs':
      case 'posts':
        return Priority.defaultPriority;
      case 'system':
        return Priority.low;
      default:
        return Priority.defaultPriority;
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      print('Message opened app: ${message.messageId}');
    }

    // Navigate to relevant screen based on notification data
    _navigateToScreen(message);
  }

  void _processNotification(RemoteMessage message) {
    final notification = message.notification;

    if (notification != null) {
      if (kDebugMode) {
        print('Title: ${notification.title}');
        print('Body: ${notification.body}');
        print('Data: ${message.data}');
      }
      // You can emit events or update state here
      // For example, using a stream or state management solution
    }
  }

  void _navigateToScreen(RemoteMessage message) {
    final notificationType = message.data['type'];

    if (kDebugMode) {
      print('Notification type: $notificationType');
    }

    // Handle navigation based on notification type
    switch (notificationType) {
      case 'message':
        // Navigate to chat screen
        break;
      case 'club':
        // Navigate to club screen
        break;
      case 'friend_request':
        // Navigate to profile or requests screen
        break;
      default:
        break;
    }
  }

  // Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      if (kDebugMode) {
        print('Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to topic: $e');
      }
    }
  }

  // Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        print('Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unsubscribing from topic: $e');
      }
    }
  }

  // For development/testing: manually set a test token
  Future<void> setTestToken(String testToken) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': testToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        if (kDebugMode) {
          print('✅ Test token set for user: ${user.uid}');
          print('✅ Token: $testToken');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error setting test token: $e');
      }
    }
  }

  // Send notification to a specific user via Cloud Function
  Future<bool> sendNotificationToUser({
    required String recipientUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get recipient's FCM token
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientUserId)
          .get();

      if (!userDoc.exists) {
        if (kDebugMode) {
          print('❌ User not found: $recipientUserId');
        }
        return false;
      }

      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      if (fcmToken == null) {
        if (kDebugMode) {
          print('❌ No FCM token for user: $recipientUserId');
          print('User data: ${userDoc.data()}');
        }
        return false;
      }

      // Call Cloud Function to send notification
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'recipientUserId': recipientUserId,
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      if (kDebugMode) {
        print('✅ Notification queued for user: $recipientUserId');
        print('✅ Title: $title');
        print('✅ Body: $body');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending notification: $e');
      }
      return false;
    }
  }

  // Send notification to multiple users
  Future<int> sendNotificationToUsers({
    required List<String> recipientUserIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    int successCount = 0;
    for (final userId in recipientUserIds) {
      final success = await sendNotificationToUser(
        recipientUserId: userId,
        title: title,
        body: body,
        data: data,
      );
      if (success) successCount++;
    }
    return successCount;
  }

  // Send notification to a topic
  Future<bool> sendNotificationToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('topicNotifications')
          .add({
        'topic': topic,
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      if (kDebugMode) {
        print('Topic notification queued for topic: $topic');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error sending topic notification: $e');
      }
      return false;
    }
  }
}

// Helper function to get channel ID for notification type
String _getChannelIdForNotificationType(String? notificationType) {
  switch (notificationType) {
    case 'direct_message':
    case 'club_message':
      return 'messages';
    case 'new_follow':
    case 'like':
    case 'dislike':
    case 'comment':
    case 'profile_update':
      return 'social';
    case 'club_join_request':
    case 'club_join_approved':
    case 'club_join_rejected':
    case 'club_post':
    case 'club_created':
    case 'club_joined':
    case 'club_deleted':
    case 'club_removed':
    case 'club_exited':
      return 'clubs';
    case 'follower_post':
    case 'following_post':
    case 'new_post':
    case 'new_club_nearby':
    case 'nearby_club':
      return 'posts';
    case 'post_upload':
    default:
      return 'system';
  }
}

// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('🔔 Handling a background message: ${message.messageId}');
    print('🔔 Message data: ${message.data}');
    print('🔔 Message notification: ${message.notification?.title}');
  }

  // Show local notification even when app is in background
  final notification = message.notification;
  if (notification != null) {
    try {
      final notificationType = message.data['type'];
      final channelId = _getChannelIdForNotificationType(notificationType);

      final androidDetails = AndroidNotificationDetails(
        channelId,
        _getChannelNameForNotificationId(channelId),
        channelDescription: _getChannelDescriptionForNotificationId(channelId),
        importance: _getImportanceForNotificationChannel(channelId),
        priority: _getPriorityForNotificationChannel(channelId),
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await FlutterLocalNotificationsPlugin().show(
        message.hashCode,
        notification.title,
        notification.body,
        notificationDetails,
        payload: message.data.toString(),
      );

      if (kDebugMode) {
        print('✅ Background notification shown: ${notification.title}');
        print('✅ Channel: $channelId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error showing background notification: $e');
      }
    }
  }
}

String _getChannelNameForNotificationId(String channelId) {
  switch (channelId) {
    case 'messages':
      return 'Messages';
    case 'social':
      return 'Social Activity';
    case 'clubs':
      return 'Club Updates';
    case 'posts':
      return 'New Posts';
    case 'system':
      return 'System Notifications';
    default:
      return 'Notifications';
  }
}

String _getChannelDescriptionForNotificationId(String channelId) {
  switch (channelId) {
    case 'messages':
      return 'Direct messages and club messages';
    case 'social':
      return 'Likes, comments, and follows';
    case 'clubs':
      return 'Club posts, join requests, and member updates';
    case 'posts':
      return 'Posts from people you follow';
    case 'system':
      return 'Upload status and system messages';
    default:
      return 'Notifications';
  }
}

Importance _getImportanceForNotificationChannel(String channelId) {
  switch (channelId) {
    case 'messages':
      return Importance.max;
    case 'social':
    case 'clubs':
    case 'posts':
      return Importance.defaultImportance;
    case 'system':
      return Importance.low;
    default:
      return Importance.defaultImportance;
  }
}

Priority _getPriorityForNotificationChannel(String channelId) {
  switch (channelId) {
    case 'messages':
      return Priority.high;
    case 'social':
    case 'clubs':
    case 'posts':
      return Priority.defaultPriority;
    case 'system':
      return Priority.low;
    default:
      return Priority.defaultPriority;
  }
}
