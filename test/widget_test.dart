import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runners_rush/app_routes.dart';
import 'package:runners_rush/game/runners_rush_game.dart';
import 'package:runners_rush/main.dart';
import 'package:runners_rush/screens/consent_screen.dart';
import 'package:runners_rush/screens/settings_screen.dart';
import 'package:runners_rush/screens/shop_screen.dart';
import 'package:runners_rush/screens/scoreboard_screen.dart';
import 'package:runners_rush/screens/game_over_screen.dart';
import 'package:runners_rush/screens/gameplay_screen.dart';
import 'package:runners_rush/screens/home_screen.dart';
import 'package:runners_rush/screens/onboarding_screen.dart';
import 'package:runners_rush/services/settings_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SettingsService.resetForTests();
  });

  Future<void> setLandscape(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('app starts on splash screen', (WidgetTester tester) async {
    await setLandscape(tester);
    await tester.pumpWidget(const RunnersRushApp());
    await tester.pump();

    expect(find.text('Runners Rush'), findsOneWidget);
    expect(find.text('Run. Jump. Survive.'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('navigates to onboarding after 5 seconds', (WidgetTester tester) async {
    await setLandscape(tester);
    await tester.pumpWidget(const RunnersRushApp());
    await tester.pump();
    expect(find.text('Runners Rush'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Run & Escape'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);
  });

  testWidgets('splash goes home when first launch already completed', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'consent_accepted': true,
    });
    await setLandscape(tester);
    await tester.pumpWidget(const RunnersRushApp());
    await tester.pump();

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Run & Escape'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('splash goes consent when onboarding done but consent pending', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'consent_accepted': false,
    });
    await setLandscape(tester);
    await tester.pumpWidget(const RunnersRushApp());
    await tester.pump();

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Before You Start'), findsOneWidget);
  });

  testWidgets('skip from first slide goes to consent', (WidgetTester tester) async {
    await setLandscape(tester);
    await tester.pumpWidget(_onboardingApp());
    await tester.pump();

    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Before You Start'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('PLAY'), findsNothing);
  });

  testWidgets('swiping shows last slide Get Started and opens consent', (WidgetTester tester) async {
    await setLandscape(tester);
    await tester.pumpWidget(_onboardingApp());
    await tester.pump();

    expect(find.text('Run & Escape'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Jump at the Right Time'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Beat Your High Score'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);

    await tester.tap(find.text('Get Started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Before You Start'), findsOneWidget);
    expect(find.text('PLAY'), findsNothing);
  });

  testWidgets('home play shop settings and character select', (WidgetTester tester) async {
    await setLandscape(tester);
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (context) => const HomeScreen(),
          AppRoutes.gameplay: (context) => const GameplayScreen(),
          AppRoutes.gameOver: (context) => const GameOverScreen(),
          AppRoutes.scoreboard: (context) => const ScoreboardScreen(),
          AppRoutes.shop: (context) => const Scaffold(body: Text('Shop Screen')),
          AppRoutes.settings: (context) => const Scaffold(body: Text('Settings Screen')),
          AppRoutes.home: (context) => const HomeScreen(),
        },
      ),
    );
    await tester.pump();

    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('Tap to select character'), findsOneWidget);
    expect(_homePreviewAsset(tester), 'assets/images/male_run.png');

    await tester.tap(find.textContaining('High Score'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leaderboard'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Character'));
    await tester.pump();
    expect(find.text('Choose Character'), findsOneWidget);
    expect(find.text('Explorer Male'), findsOneWidget);
    expect(find.text('Explorer Female'), findsOneWidget);
    await tester.tap(find.text('Explorer Female'));
    await tester.pump();
    expect(find.text('Choose Character'), findsOneWidget);
    expect(_homePreviewAsset(tester), 'assets/images/male_run.png');
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(find.text('Choose Character'), findsNothing);
    expect(_homePreviewAsset(tester), 'assets/images/female_run.png');

    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GameWidget<RunnersRushGame>), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Paused'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Paused'), findsNothing);
    expect(find.byType(GameWidget<RunnersRushGame>), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('Paused'), findsNothing);
  });

  testWidgets('gameplay embeds Flame game under hud overlay', (WidgetTester tester) async {
    await setLandscape(tester);
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (context) => const GameplayScreen(),
          AppRoutes.home: (context) => const Scaffold(body: Text('PLAY')),
          AppRoutes.gameplay: (context) => const GameplayScreen(),
          AppRoutes.gameOver: (context) => const GameOverScreen(),
        },
      ),
    );
    await tester.pump();

    expect(find.byType(GameWidget<RunnersRushGame>), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('PLAY'), findsOneWidget);
  });

  testWidgets('game over restart and home navigation', (WidgetTester tester) async {
    await setLandscape(tester);
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (context) => const GameOverScreen(),
          AppRoutes.gameplay: (context) =>
              const Scaffold(body: Text('Gameplay Screen')),
          AppRoutes.home: (context) => const Scaffold(body: Text('PLAY')),
        },
      ),
    );
    await tester.pump();

    expect(find.text('GAME OVER'), findsOneWidget);
    expect(find.text('Score: 0'), findsOneWidget);
    expect(find.text('Best: 0'), findsOneWidget);
    expect(find.text('New High Score! 🎉'), findsNothing);

    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();
    expect(find.text('Gameplay Screen'), findsOneWidget);
  });

  testWidgets('game over home button and new high score badge', (WidgetTester tester) async {
    await setLandscape(tester);
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (context) => const GameOverScreen(isNewHighScore: true),
          AppRoutes.home: (context) => const Scaffold(body: Text('PLAY')),
        },
      ),
    );
    await tester.pump();

    expect(find.text('New High Score! 🎉'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('PLAY'), findsOneWidget);
  });

  testWidgets('game over shows score from route arguments', (WidgetTester tester) async {
    await setLandscape(tester);
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (context) => const SizedBox.shrink(),
          AppRoutes.gameOver: (context) => const GameOverScreen(),
        },
      ),
    );
    await tester.pump();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(
      AppRoutes.gameOver,
      arguments: {
        'score': 128,
        'best': 200,
        'coinsEarned': 12,
        'isNewHighScore': false,
        'character': 'male',
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('GAME OVER'), findsOneWidget);
    expect(find.text('Score: 128'), findsOneWidget);
    expect(find.text('Best: 200'), findsOneWidget);
    expect(find.text('+12 coins'), findsOneWidget);
  });

  testWidgets('scoreboard shows local high score and recent runs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'high_score': 1250,
      'recent_runs': '[1250,980,410]',
    });
    await setLandscape(tester);
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (context) => const ScoreboardScreen(),
          AppRoutes.home: (context) => const Scaffold(body: Text('PLAY')),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('Best score'), findsOneWidget);
    expect(find.text('1250'), findsWidgets);
    expect(find.text('Recent runs'), findsOneWidget);
    expect(find.text('Run 1'), findsOneWidget);
    expect(find.text('980'), findsOneWidget);
    expect(find.text('410'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('PLAY'), findsOneWidget);
  });

  testWidgets('shop shows skins coins and select', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'coins': 500,
      'unlocked_characters': ['male'],
    });
    await setLandscape(tester);
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (context) => const ShopScreen(),
          AppRoutes.home: (context) => const Scaffold(body: Text('PLAY')),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Characters'), findsOneWidget);
    expect(find.text('Explorer Male'), findsOneWidget);
    expect(find.text('Explorer Female'), findsOneWidget);
    expect(find.text('Owned'), findsAtLeastNWidgets(1));
    expect(find.text('Selected'), findsAtLeastNWidgets(1));
    expect(find.text('Buy'), findsWidgets);
    expect(find.text('275'), findsOneWidget);

    await tester.ensureVisible(find.text('275'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy').first);
    await tester.pumpAndSettle();
    expect(find.text('Selected'), findsAtLeastNWidgets(1));
    expect(find.text('Owned'), findsAtLeastNWidgets(2));
    expect(find.text('275'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('PLAY'), findsOneWidget);
  });

  testWidgets('settings toggles about dialog and back', (WidgetTester tester) async {
    await setLandscape(tester);
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (context) => const SettingsScreen(),
          AppRoutes.home: (context) => const Scaffold(body: Text('PLAY')),
        },
      ),
    );
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sound Effects'), findsOneWidget);
    expect(find.text('Background Music'), findsOneWidget);
    expect(find.text('Vibration'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(3));

    await tester.tap(find.text('About'));
    await tester.pump();
    expect(find.text('Version 1.0.0'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump();
    expect(find.text('Version 1.0.0'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('PLAY'), findsOneWidget);
  });

  testWidgets('consent requires checkbox then continues home', (WidgetTester tester) async {
    await setLandscape(tester);
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (context) => const ConsentScreen(),
          AppRoutes.home: (context) => const Scaffold(body: Text('PLAY')),
        },
      ),
    );
    await tester.pump();

    expect(find.text('Before You Start'), findsOneWidget);
    expect(find.text('I have read and agree to the above'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('PLAY'), findsNothing);

    await tester.tap(find.text('Terms of Service'));
    await tester.pump();
    expect(find.text('Coming soon'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('PLAY'), findsOneWidget);
  });
}

String _homePreviewAsset(WidgetTester tester) {
  final image = tester.widget<Image>(
    find.byKey(const ValueKey('home-character-preview')),
  );
  final provider = image.image;
  expect(provider, isA<AssetImage>());
  return (provider as AssetImage).assetName;
}

Widget _onboardingApp() {
  return const MaterialApp(
    home: OnboardingScreen(),
  );
}
