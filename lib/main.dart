import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runners_rush/app_routes.dart';
import 'package:runners_rush/screens/consent_screen.dart';
import 'package:runners_rush/screens/game_over_screen.dart';
import 'package:runners_rush/screens/gameplay_screen.dart';
import 'package:runners_rush/screens/home_screen.dart';
import 'package:runners_rush/screens/onboarding_screen.dart';
import 'package:runners_rush/screens/scoreboard_screen.dart';
import 'package:runners_rush/screens/settings_screen.dart';
import 'package:runners_rush/screens/shop_screen.dart';
import 'package:runners_rush/screens/splash_screen.dart';
import 'package:runners_rush/services/audio_service.dart';
import 'package:runners_rush/services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } catch (_) {}
  await SettingsService.init();
  // Fire-and-forget: BGM must not block first frame (esp. Chrome/web).
  unawaited(AudioService.init());
  runApp(const RunnersRushApp());
}

class RunnersRushApp extends StatelessWidget {
  const RunnersRushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Runners Rush',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      onGenerateInitialRoutes: (initialRoute) {
        return [
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: AppRoutes.splash),
            builder: (context) => const SplashScreen(),
          ),
        ];
      },
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.onboarding: (context) => const OnboardingScreen(),
        AppRoutes.consent: (context) => const ConsentScreen(),
        AppRoutes.home: (context) => const HomeScreen(),
        AppRoutes.gameplay: (context) => const GameplayScreen(),
        AppRoutes.gameOver: (context) => const GameOverScreen(),
        AppRoutes.scoreboard: (context) => const ScoreboardScreen(),
        AppRoutes.shop: (context) => const ShopScreen(),
        AppRoutes.settings: (context) => const SettingsScreen(),
      },
    );
  }
}
