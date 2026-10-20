import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  static final CacheManager _cacheManager = CacheManager(
    Config(
      'sportsChatImageCache',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
    ),
  );

  factory ImageCacheService() {
    return _instance;
  }

  ImageCacheService._internal();

  /// Load a network image with caching
  static Widget loadNetworkImage({
    required String imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (imageUrl.isEmpty) {
      return errorWidget ?? _defaultErrorWidget(width, height);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheManager: _cacheManager,
      placeholder: (context, url) =>
          placeholder ?? _defaultPlaceholder(width, height),
      errorWidget: (context, url, error) =>
          errorWidget ?? _defaultErrorWidget(width, height),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
    );
  }

  /// Load a circular profile image with caching
  static Widget loadProfileImage({
    required String imageUrl,
    required double radius,
    required String fallbackInitial,
  }) {
    if (imageUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFFF8C00),
        child: Text(
          fallbackInitial,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: _cacheManager,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8C00)),
          ),
        ),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFFF8C00),
        child: Text(
          fallbackInitial,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
    );
  }

  static Widget _defaultPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8C00)),
          ),
        ),
      ),
    );
  }

  static Widget _defaultErrorWidget(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 30,
        ),
      ),
    );
  }

  /// Preload an image into cache
  static Future<void> preloadImage(String imageUrl) async {
    if (imageUrl.isEmpty) return;
    try {
      await _cacheManager.getSingleFile(imageUrl);
    } catch (e) {
      debugPrint('Error preloading image: $e');
    }
  }

  /// Preload multiple images
  static Future<void> preloadImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      await preloadImage(url);
    }
  }

  /// Get user profile picture URL from Firestore if not in post
  static Future<String> getUserProfilePictureUrl(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        return userDoc.data()?['profilePictureUrl']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('Error fetching user profile picture: $e');
    }
    return '';
  }

  /// Clear all cached images
  static Future<void> clearCache() async {
    await _cacheManager.emptyCache();
  }

  /// Clear specific image from cache
  static Future<void> clearImageCache(String imageUrl) async {
    try {
      await _cacheManager.removeFile(imageUrl);
    } catch (e) {
      debugPrint('Error clearing image cache: $e');
    }
  }
}
