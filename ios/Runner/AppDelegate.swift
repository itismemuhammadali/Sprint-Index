import Flutter
import UIKit
import UserNotifications
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Setup method channels for platform communication
    setupMethodChannels()
    
    // Setup notification categories and permissions
    setupNotificationCategories()
    requestNotificationPermissions()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupMethodChannels() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    
    let mapsChannel = FlutterMethodChannel(
      name: "com.sprintindex.app/maps",
      binaryMessenger: controller.binaryMessenger
    )
    
    mapsChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "setMapsApiKey":
        if let args = call.arguments as? [String: Any],
           let apiKey = args["apiKey"] as? String,
           !apiKey.isEmpty {
          GMSServices.provideAPIKey(apiKey)
          print("✅ Google Maps API Key set successfully: \(apiKey.prefix(10))...")
          result(true)
        } else {
          print("❌ API key is null or empty")
          result(FlutterError(code: "INVALID_ARGUMENT", message: "API key is null or empty", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func setupNotificationCategories() {
    let center = UNUserNotificationCenter.current()
    
    // Messages category
    let messagesCategory = UNNotificationCategory(
      identifier: "MESSAGES_CATEGORY",
      actions: [
        UNNotificationAction(identifier: "REPLY_ACTION", title: "Reply", options: [.foreground]),
        UNNotificationAction(identifier: "MARK_READ_ACTION", title: "Mark as Read", options: [])
      ],
      intentIdentifiers: [],
      hiddenPreviewsBodyPlaceholder: "New message",
      options: [.customDismissAction, .allowInCarPlay]
    )
    
    // Social category (likes, comments, follows)
    let socialCategory = UNNotificationCategory(
      identifier: "SOCIAL_CATEGORY",
      actions: [
        UNNotificationAction(identifier: "VIEW_ACTION", title: "View", options: [.foreground]),
        UNNotificationAction(identifier: "DISMISS_ACTION", title: "Dismiss", options: [])
      ],
      intentIdentifiers: [],
      hiddenPreviewsBodyPlaceholder: "Social activity",
      options: [.customDismissAction]
    )
    
    // Clubs category
    let clubsCategory = UNNotificationCategory(
      identifier: "CLUBS_CATEGORY",
      actions: [
        UNNotificationAction(identifier: "VIEW_CLUB_ACTION", title: "View Club", options: [.foreground]),
        UNNotificationAction(identifier: "APPROVE_ACTION", title: "Approve", options: [.foreground]),
        UNNotificationAction(identifier: "REJECT_ACTION", title: "Reject", options: [])
      ],
      intentIdentifiers: [],
      hiddenPreviewsBodyPlaceholder: "Club update",
      options: [.customDismissAction]
    )
    
    // Posts category
    let postsCategory = UNNotificationCategory(
      identifier: "POSTS_CATEGORY",
      actions: [
        UNNotificationAction(identifier: "VIEW_POST_ACTION", title: "View Post", options: [.foreground]),
        UNNotificationAction(identifier: "DISMISS_POST_ACTION", title: "Dismiss", options: [])
      ],
      intentIdentifiers: [],
      hiddenPreviewsBodyPlaceholder: "New post",
      options: [.customDismissAction]
    )
    
    // System category
    let systemCategory = UNNotificationCategory(
      identifier: "SYSTEM_CATEGORY",
      actions: [
        UNNotificationAction(identifier: "DISMISS_SYSTEM_ACTION", title: "Dismiss", options: [])
      ],
      intentIdentifiers: [],
      hiddenPreviewsBodyPlaceholder: "System notification",
      options: [.customDismissAction]
    )
    
    center.setNotificationCategories([
      messagesCategory,
      socialCategory,
      clubsCategory,
      postsCategory,
      systemCategory
    ])
  }
  
  private func requestNotificationPermissions() {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if granted {
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }
        print("✅ Notification permissions granted")
      } else if let error = error {
        print("❌ Notification permission error: \(error.localizedDescription)")
      }
    }
  }
}
