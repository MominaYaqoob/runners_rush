import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runners_rush/ads/ads_service.dart';
import 'package:runners_rush/app_routes.dart';
import 'package:runners_rush/game/runners_rush_game.dart';
import 'package:runners_rush/game/shield_painter.dart';
import 'package:runners_rush/services/audio_service.dart';
import 'package:runners_rush/widgets/pause_menu.dart';

class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key});

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen>
    with WidgetsBindingObserver {
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
  static const _countdownStep = Duration(milliseconds: 700);
  static const _countdownLabels = ['3', '2', '1'];

  late RunnersRushGame _game;
  Key _gameWidgetKey = UniqueKey();
  bool _isPaused = false;
  int? _countdownIndex;
  Timer? _countdownTimer;

  bool get _isCountingDown => _countdownIndex != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(_overlayStyle);
    AdsService.gameplayActive = true;
    _createGame();
    unawaited(AudioService.playGameplayMusic());
    unawaited(AdsService.prepareInterstitialIfDue());
  }

  @override
  void dispose() {
    AdsService.gameplayActive = false;
    WidgetsBinding.instance.removeObserver(this);
    _stopCountdown(notify: false);
    unawaited(AudioService.playMenuMusic());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Interrupted by background, system dialog, or phone call — show pause
    // menu and keep the engine paused. Do not auto-resume on return.
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _onPause();
      case AppLifecycleState.resumed:
        break;
    }
  }

  void _createGame() {
    _stopCountdown(notify: false);
    _game = RunnersRushGame();
    _gameWidgetKey = UniqueKey();
    _isPaused = false;
  }

  void _stopCountdown({bool notify = true}) {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdownIndex == null) return;
    _countdownIndex = null;
    if (notify && mounted) {
      setState(() {});
    }
  }

  void _onPause() {
    if (_game.isGameOver) return;
    _clearJumpBuffer();
    final wasCounting = _isCountingDown;
    _stopCountdown(notify: false);
    if (_isPaused && !wasCounting) return;
    _game.pauseEngine();
    setState(() {
      _isPaused = true;
      _countdownIndex = null;
    });
  }

  void _onResume() {
    if (!_isPaused || _game.isGameOver) return;
    // Drop any buffered jump so countdown end cannot fire an instant jump.
    _clearJumpBuffer();
    // Keep engine paused through the countdown.
    setState(() {
      _isPaused = false;
      _countdownIndex = 0;
    });
    _scheduleCountdownTick();
  }

  void _clearJumpBuffer() {
    if (!_game.isLoaded) return;
    _game.player.clearJumpBuffer();
  }

  void _scheduleCountdownTick() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer(_countdownStep, () {
      if (!mounted || _countdownIndex == null) return;
      final next = _countdownIndex! + 1;
      if (next >= _countdownLabels.length) {
        setState(() {
          _countdownIndex = null;
          _countdownTimer = null;
        });
        if (!_game.isGameOver) {
          _game.resumeEngine();
        }
        return;
      }
      setState(() => _countdownIndex = next);
      _scheduleCountdownTick();
    });
  }

  void _onRestart() {
    _stopCountdown(notify: false);
    _game.pauseEngine();
    setState(_createGame);
  }

  void _onHome() {
    _stopCountdown(notify: false);
    _game.pauseEngine();
    unawaited(AudioService.playMenuMusic());
    setState(() {
      _isPaused = false;
      _countdownIndex = null;
    });
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
    );
  }

  void _onSystemBack() {
    if (_game.isGameOver) return;
    if (_isPaused) {
      _onResume();
    } else {
      _onPause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _onSystemBack();
        },
        child: Scaffold(
          backgroundColor: RunnersRushGame.placeholderColor,
          body: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                ignoring: _isCountingDown,
                child: GameWidget<RunnersRushGame>(
                  key: _gameWidgetKey,
                  game: _game,
                  loadingBuilder: (context) => const ColoredBox(
                    color: RunnersRushGame.placeholderColor,
                  ),
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
                        const SizedBox(width: 10),
                        ValueListenableBuilder<int>(
                          valueListenable: _game.coinsCollected,
                          builder: (context, value, child) {
                            return _CoinBadge(count: value);
                          },
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _game.shieldActive,
                          builder: (context, active, child) {
                            if (!active) return const SizedBox.shrink();
                            return const Padding(
                              padding: EdgeInsets.only(left: 10),
                              child: _ShieldBadge(),
                            );
                          },
                        ),
                        const Spacer(),
                        _PauseButton(onPressed: _onPause),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isPaused)
                Positioned.fill(
                  child: PauseMenu(
                    onResume: _onResume,
                    onRestart: _onRestart,
                    onHome: _onHome,
                  ),
                ),
              if (_isCountingDown)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey<int>(_countdownIndex!),
                        tween: Tween(begin: 0.72, end: 1),
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) {
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Text(
                          _countdownLabels[_countdownIndex!],
                          style: GoogleFonts.baloo2(
                            fontSize: 80,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                            shadows: const [
                              Shadow(
                                color: Color(0x99000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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

class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('hud-coin-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/coin.png',
            width: 22,
            height: 22,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(width: 4),
          Text(
            '×$count',
            style: GoogleFonts.baloo2(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShieldBadge extends StatelessWidget {
  const _ShieldBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('hud-shield-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CustomPaint(painter: ShieldIconPainter()),
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
