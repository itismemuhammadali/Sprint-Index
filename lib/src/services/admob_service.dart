import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();

  factory AdMobService() {
    return _instance;
  }

  AdMobService._internal();

  // Your AdMob Ad Unit IDs
  static const String bannerAdUnitId = 'ca-app-pub-9854588468192765~8042102356';
  static const String interstitialAdUnitId = 'ca-app-pub-9854588468192765~4737958578';

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;

  Future<void> initializeMobileAds() async {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('Error initializing MobileAds: $e');
    }
  }

  // Load banner ad
  Future<BannerAd?> loadBannerAd() async {
    try {
      _bannerAd = BannerAd(
        adUnitId: bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            debugPrint('Banner ad loaded');
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('Banner ad failed to load: $error');
            ad.dispose();
          },
          onAdClicked: (ad) {
            debugPrint('Banner ad clicked');
          },
          onAdImpression: (ad) {
            debugPrint('Banner ad impression');
          },
        ),
      );

      await _bannerAd?.load();
      return _bannerAd;
    } catch (e) {
      debugPrint('Error loading banner ad: $e');
      return null;
    }
  }

  // Load interstitial ad
  Future<InterstitialAd?> loadInterstitialAd() async {
    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            debugPrint('Interstitial ad loaded');
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('Interstitial ad failed to load: $error');
          },
        ),
      );
      return _interstitialAd;
    } catch (e) {
      debugPrint('Error loading interstitial ad: $e');
      return null;
    }
  }

  // Show interstitial ad
  Future<void> showInterstitialAd() async {
    if (_interstitialAd != null) {
      _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('Interstitial ad dismissed');
          ad.dispose();
          _interstitialAd = null;
          // Reload for next time
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('Interstitial ad failed to show: $error');
          ad.dispose();
          _interstitialAd = null;
        },
        onAdShowedFullScreenContent: (ad) {
          debugPrint('Interstitial ad showed');
        },
      );
      await _interstitialAd?.show();
    }
  }

  // Get banner ad
  BannerAd? getBannerAd() => _bannerAd;

  // Dispose ads
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  void disposeInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  void disposeAll() {
    disposeBannerAd();
    disposeInterstitialAd();
  }
}
