import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runners_rush/app_routes.dart';
import 'package:runners_rush/services/score_service.dart';

class ScoreboardScreen extends StatefulWidget {
  const ScoreboardScreen({super.key});

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
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  int _highScore = 0;
  List<int> _recentRuns = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    final highScore = await ScoreService.getHighScore();
    final recent = await ScoreService.getRecentRuns();
    if (!mounted) return;
    setState(() {
      _highScore = highScore;
      _recentRuns = recent;
      _loaded = true;
    });
  }

  void _onBack(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    nav.pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ScoreboardScreen._overlayStyle,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/background_evening.png',
              fit: BoxFit.cover,
            ),
            const ColoredBox(color: Color(0x66000000)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    _TopBar(onBack: () => _onBack(context)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: !_loaded
                              ? const SizedBox.shrink()
                              : ListView(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  children: [
                                    _BestScoreCard(score: _highScore),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Recent runs',
                                      style: GoogleFonts.baloo2(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (_recentRuns.isEmpty)
                                      const _EmptyRuns()
                                    else
                                      ...List.generate(_recentRuns.length, (
                                        index,
                                      ) {
                                        final rank = index + 1;
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            bottom: index ==
                                                    _recentRuns.length - 1
                                                ? 0
                                                : 8,
                                          ),
                                          child: _ScoreRow(
                                            rank: rank,
                                            score: _recentRuns[index],
                                            label: 'Run $rank',
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                        ),
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

class _BestScoreCard extends StatelessWidget {
  const _BestScoreCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x73000000),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFC857).withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC857).withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFC857).withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFC857).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFF2A1A12),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Best score',
              style: GoogleFonts.baloo2(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ),
          Text(
            '$score',
            style: GoogleFonts.baloo2(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRuns extends StatelessWidget {
  const _EmptyRuns();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: ScoreboardScreen._hudFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ScoreboardScreen._hudBorder),
      ),
      child: Text(
        'No runs yet — play a game!',
        textAlign: TextAlign.center,
        style: GoogleFonts.baloo2(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.75),
          height: 1.2,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ScoreboardScreen._hudFill,
                  border: Border.all(color: ScoreboardScreen._hudBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          Text(
            'Leaderboard',
            style: GoogleFonts.baloo2(
              fontSize: 24,
              fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.rank,
    required this.score,
    required this.label,
  });

  final int rank;
  final int score;
  final String label;

  static const _medalColors = <int, Color>{
    1: Color(0xFFFFC857),
    2: Color(0xFFC5CDD8),
    3: Color(0xFFD0894B),
  };

  bool get _isPodium => rank <= 3;

  Color get _medalColor => _medalColors[rank] ?? const Color(0x66FFFFFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isPodium ? 16 : 14,
        vertical: _isPodium ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: _isPodium ? const Color(0x73000000) : ScoreboardScreen._hudFill,
        borderRadius: BorderRadius.circular(_isPodium ? 18 : 14),
        border: Border.all(
          color: _isPodium
              ? _medalColor.withValues(alpha: 0.55)
              : ScoreboardScreen._hudBorder,
          width: _isPodium ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _isPodium
                ? _medalColor.withValues(alpha: 0.18)
                : const Color(0x40000000),
            blurRadius: _isPodium ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _RankBadge(rank: rank, color: _medalColor, featured: _isPodium),
          const SizedBox(width: 12),
          Container(
            width: _isPodium ? 40 : 34,
            height: _isPodium ? 40 : 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Icon(
              Icons.directions_run_rounded,
              color: Colors.white,
              size: _isPodium ? 22 : 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.baloo2(
                fontSize: _isPodium ? 18 : 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ),
          Text(
            '$score',
            style: GoogleFonts.baloo2(
              fontSize: _isPodium ? 22 : 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({
    required this.rank,
    required this.color,
    required this.featured,
  });

  final int rank;
  final Color color;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final size = featured ? 36.0 : 28.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: featured ? color : Colors.white.withValues(alpha: 0.12),
        boxShadow: featured
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        '$rank',
        style: GoogleFonts.baloo2(
          fontSize: featured ? 18 : 13,
          fontWeight: FontWeight.w800,
          color: featured
              ? const Color(0xFF2A1A12)
              : Colors.white.withValues(alpha: 0.85),
          height: 1,
        ),
      ),
    );
  }
}
