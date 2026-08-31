import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runners_rush/app_routes.dart';

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({
    super.key,
    this.score = 0,
    this.best = 0,
    this.isNewHighScore = false,
  });

  final int score;
  final int best;
  final bool isNewHighScore;

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

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final resolvedScore = args is int ? args : score;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/background_evening.png',
              fit: BoxFit.cover,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0x80000000),
                    Color(0xB3000000),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 24, 14),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Align(
                        alignment: const Alignment(-0.15, 0.15),
                        child: Image.asset(
                          'assets/images/male_fall.png',
                          height: MediaQuery.sizeOf(context).height * 0.78,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: _ResultsPanel(
                        score: resolvedScore,
                        best: best,
                        isNewHighScore: isNewHighScore,
                        onRestart: () {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.gameplay,
                          );
                        },
                        onHome: () {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.home,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel({
    required this.score,
    required this.best,
    required this.isNewHighScore,
    required this.onRestart,
    required this.onHome,
  });

  final int score;
  final int best;
  final bool isNewHighScore;
  final VoidCallback onRestart;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GAME OVER',
          style: GoogleFonts.baloo2(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFFFE4DC),
            height: 1.05,
            letterSpacing: 1.2,
            shadows: const [
              Shadow(
                color: Color(0xCCB71C1C),
                blurRadius: 16,
                offset: Offset(0, 2),
              ),
              Shadow(
                color: Color(0x99000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
        if (isNewHighScore) ...[
          const SizedBox(height: 10),
          const _NewHighScoreBadge(),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: GameOverScreen._hudFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GameOverScreen._hudBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'Score: $score',
            style: GoogleFonts.baloo2(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFFFC857),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Best: $best',
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.80),
                height: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            _RestartButton(onPressed: onRestart),
            const SizedBox(width: 12),
            _HomeButton(onPressed: onHome),
          ],
        ),
      ],
    );
  }
}

class _NewHighScoreBadge extends StatelessWidget {
  const _NewHighScoreBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8A3D), Color(0xFF6B3FA0)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8A3D).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        'New High Score! 🎉',
        style: GoogleFonts.baloo2(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}

class _RestartButton extends StatelessWidget {
  const _RestartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8A3D), Color(0xFF6B3FA0)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B3FA0).withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.replay_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              'Restart',
              style: GoogleFonts.baloo2(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.4,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  const _HomeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: GameOverScreen._hudFill,
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.home_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              'Home',
              style: GoogleFonts.baloo2(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
