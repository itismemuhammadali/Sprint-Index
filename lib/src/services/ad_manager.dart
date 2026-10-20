import 'package:flutter/foundation.dart';
import 'package:sports_chat_app/src/services/admob_service.dart';

class AdManager {
  static final AdManager _instance = AdManager._internal();
  
  factory AdManager() {
    return _instance;
  }
  
  AdManager._internal();

  int _postViewCount = 0;
  static const int _interstitialShowInterval = 5; // Show interstitial every 5 posts viewed

  /// Track post views and show interstitial ads strategically
  Future<void> trackPostView() async {
    _postViewCount++;
    
    // Show interstitial ad every 5 posts viewed
    if (_postViewCount % _interstitialShowInterval == 0) {
      await _showInterstitialAd();
    }
  }

  /// Show interstitial ad
  Future<void> _showInterstitialAd() async {
    try {
      await AdMobService().loadInterstitialAd();
      await Future.delayed(const Duration(milliseconds: 500));
      await AdMobService().showInterstitialAd();
    } catch (e) {
      debugPrint('Error showing interstitial ad: $e');
    }
  }

  /// Reset post view counter
  void resetPostViewCount() {
    _postViewCount = 0;
  }

  /// Get current post view count
  int getPostViewCount() => _postViewCount;
}
