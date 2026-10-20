import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sports_chat_app/src/services/admob_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  late Future<BannerAd?> _bannerAdFuture;

  @override
  void initState() {
    super.initState();
    _bannerAdFuture = AdMobService().loadBannerAd();
  }

  @override
  void dispose() {
    AdMobService().disposeBannerAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BannerAd?>(
      future: _bannerAdFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return Container(
            alignment: Alignment.center,
            width: snapshot.data!.size.width.toDouble(),
            height: snapshot.data!.size.height.toDouble(),
            child: AdWidget(ad: snapshot.data!),
          );
        }
        // Return empty container if ad is not loaded
        return const SizedBox.shrink();
      },
    );
  }
}
