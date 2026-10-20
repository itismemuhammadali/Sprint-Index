import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PlatformService {
  static const MethodChannel _channel = MethodChannel('com.sprintindex.app/maps');

  static Future<void> setMapsApiKey(String apiKey) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('setMapsApiKey', {'apiKey': apiKey});
        debugPrint('Android Maps API key set successfully');
      } else if (Platform.isIOS) {
        await _channel.invokeMethod('setMapsApiKey', {'apiKey': apiKey});
        debugPrint('iOS Maps API key set successfully');
      }
    } catch (e) {
      debugPrint('Error setting Maps API key: $e');
    }
  }
}