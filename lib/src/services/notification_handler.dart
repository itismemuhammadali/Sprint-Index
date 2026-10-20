import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationHandler {
  /// Handle different notification types and return navigation data
  static Map<String, dynamic> parseNotification(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;

    return {
      'type': data['type'] ?? 'default',
      'title': notification?.title ?? data['title'] ?? 'Notification',
      'body': notification?.body ?? data['body'] ?? '',
      'data': data,
      'messageId': message.messageId,
      'sentTime': message.sentTime,
    };
  }

  /// Handle message notification
  static void handleMessageNotification(Map<String, dynamic> notificationData) {
    final chatId = notificationData['data']['chatId'];
    final senderId = notificationData['data']['senderId'];

    if (kDebugMode) {
      print('Handling message notification from $senderId in chat $chatId');
    }

    // Emit event or update state to navigate to chat screen
    // Example: eventBus.fire(NavigateToChatEvent(chatId: chatId));
  }

  /// Handle club notification
  static void handleClubNotification(Map<String, dynamic> notificationData) {
    final clubId = notificationData['data']['clubId'];
    final action = notificationData['data']['action'];

    if (kDebugMode) {
      print('Handling club notification for club $clubId with action $action');
    }

    // Emit event or update state to navigate to club screen
    // Example: eventBus.fire(NavigateToClubEvent(clubId: clubId));
  }

  /// Handle friend request notification
  static void handleFriendRequestNotification(
      Map<String, dynamic> notificationData) {
    final userId = notificationData['data']['userId'];

    if (kDebugMode) {
      print('Handling friend request notification from $userId');
    }

    // Emit event or update state to navigate to profile screen
    // Example: eventBus.fire(NavigateToProfileEvent(userId: userId));
  }

  /// Handle sports update notification
  static void handleSportsUpdateNotification(
      Map<String, dynamic> notificationData) {
    final updateId = notificationData['data']['updateId'];

    if (kDebugMode) {
      print('Handling sports update notification: $updateId');
    }

    // Emit event or update state
    // Example: eventBus.fire(ShowSportsUpdateEvent(updateId: updateId));
  }

  /// Route notification to appropriate handler
  static void routeNotification(Map<String, dynamic> notificationData) {
    final type = notificationData['type'];

    switch (type) {
      case 'message':
        handleMessageNotification(notificationData);
        break;
      case 'club':
        handleClubNotification(notificationData);
        break;
      case 'friend_request':
        handleFriendRequestNotification(notificationData);
        break;
      case 'sports_update':
        handleSportsUpdateNotification(notificationData);
        break;
      default:
        if (kDebugMode) {
          print('Unknown notification type: $type');
        }
    }
  }
}
