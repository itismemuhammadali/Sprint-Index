import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  late FirebaseRemoteConfig _remoteConfig;
  bool _initialized = false;

  // API Keys - Platform specific
  String get googleMapsApiKey {
    if (Platform.isIOS) {
      return _remoteConfig.getString('google_maps_api_key_ios');
    } else if (Platform.isAndroid) {
      return _remoteConfig.getString('google_maps_api_key_android');
    }
    return _remoteConfig.getString('google_maps_api_key');
  }
  
  String get emailApiKey => _remoteConfig.getString('email_api_key');
  
  // Email service configuration
  String get emailServiceUrl => _remoteConfig.getString('email_service_url');
  String get emailFromAddress => _remoteConfig.getString('email_from_address');

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Set default values
      await _remoteConfig.setDefaults({
        'google_maps_api_key': '',
        'google_maps_api_key_ios': '',
        'google_maps_api_key_android': '',
        'email_api_key': '',
        'email_service_url': '',
        'email_from_address': 'noreply@yourapp.com',
      });

      // Configure settings with shorter timeout
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 30),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      // Fetch and activate
      await _remoteConfig.fetchAndActivate();
      
      _initialized = true;
      debugPrint('✅ Remote Config initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Remote Config: $e');
      // Continue with default values if Remote Config fails
      _initialized = true;
    }
  }

  Future<void> refresh() async {
    if (!_initialized) return;
    
    try {
      await _remoteConfig.fetchAndActivate();
      debugPrint('✅ Remote Config refreshed');
    } catch (e) {
      debugPrint('⚠️ Error refreshing Remote Config: $e');
    }
  }

  bool get isInitialized => _initialized;
}