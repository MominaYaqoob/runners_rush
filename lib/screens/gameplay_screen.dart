import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runners_rush/app_routes.dart';
import 'package:runners_rush/game/runners_rush_game.dart';
import 'package:runners_rush/widgets/pause_menu.dart';

class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key});

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  static const _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  static const _hudFill = Color(0x66000000);
  static const _hudBorder = Color(0x26FFFFFF);
  static const _defaultCharacter = 'assets/images/male_run.png';

  late final RunnersRushGame _game;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(_overlayStyle);
    _game = RunnersRushGame();
  }

  String _characterAsset() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) return args;
    return _defaultCharacter;
  }

  void _onPause() {
    _game.paused = true;
    final gameplayContext = context;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Paused',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return PauseMenu(
          onResume: () {
            Navigator.of(dialogContext).pop();
            _game.paused = false;
          },
          onRestart: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(gameplayContext).pushReplacementNamed(
              AppRoutes.gameplay,
              arguments: _characterAsset(),
            );
          },
          onHome: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(gameplayContext).pushReplacementNamed(AppRoutes.home);
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle,
      child: Scaffold(
        backgroundColor: RunnersRushGame.placeholderColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GameWidget<RunnersRushGame>(
              game: _game,
              loadingBuilder: (context) => const ColoredBox(
                color: RunnersRushGame.placeholderColor,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: _game.score,
                        builder: (context, value, child) {
                          return _ScoreBadge(score: value);
                        },
                      ),
                      const Spacer(),
                      _PauseButton(onPressed: _onPause),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _GameplayScreenState._hudFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _GameplayScreenState._hudBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '$score',
        style: GoogleFonts.baloo2(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.05,
        ),
      ),
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _GameplayScreenState._hudFill,
          border: Border.all(color: _GameplayScreenState._hudBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.pause_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
