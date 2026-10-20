import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sports_chat_app/src/screens/splash_screen.dart';
import 'package:sports_chat_app/src/screens/login_screen.dart';
import 'package:sports_chat_app/src/screens/home_screen.dart';
import 'package:sports_chat_app/src/services/notification_service.dart';
import 'package:sports_chat_app/src/services/remote_config_service.dart';
import 'package:sports_chat_app/src/services/admob_service.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize AdMob
  await AdMobService().initializeMobileAds();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  // Initialize Remote Config
  await RemoteConfigService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SprintIndex',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
