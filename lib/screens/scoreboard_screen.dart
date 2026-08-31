import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runners_rush/app_routes.dart';

class _DummyScore {
  const _DummyScore({
    required this.rank,
    required this.name,
    required this.score,
    required this.icon,
  });

  final int rank;
  final String name;
  final int score;
  final IconData icon;
}

class ScoreboardScreen extends StatelessWidget {
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

  static const _entries = <_DummyScore>[
    _DummyScore(rank: 1, name: 'Explorer', score: 1250, icon: Icons.person_rounded),
    _DummyScore(rank: 2, name: 'Runner', score: 980, icon: Icons.directions_run_rounded),
    _DummyScore(rank: 3, name: 'Scout', score: 750, icon: Icons.explore_rounded),
    _DummyScore(rank: 4, name: 'Ranger', score: 620, icon: Icons.hiking_rounded),
    _DummyScore(rank: 5, name: 'Pathfinder', score: 540, icon: Icons.terrain_rounded),
    _DummyScore(rank: 6, name: 'Trailblazer', score: 410, icon: Icons.forest_rounded),
  ];

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
                          child: ListView.separated(
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: _entries.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              return _ScoreRow(entry: _entries[index]);
                            },
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
  const _ScoreRow({required this.entry});

  final _DummyScore entry;

  static const _medalColors = <int, Color>{
    1: Color(0xFFFFC857),
    2: Color(0xFFC5CDD8),
    3: Color(0xFFD0894B),
  };

  bool get _isPodium => entry.rank <= 3;

  Color get _medalColor => _medalColors[entry.rank] ?? const Color(0x66FFFFFF);

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
          _RankBadge(rank: entry.rank, color: _medalColor, featured: _isPodium),
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
              entry.icon,
              color: Colors.white,
              size: _isPodium ? 22 : 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.name,
              style: GoogleFonts.baloo2(
                fontSize: _isPodium ? 18 : 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ),
          Text(
            '${entry.score}',
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
          color: featured ? const Color(0xFF2A1A12) : Colors.white.withValues(alpha: 0.85),
          height: 1,
        ),
      ),
    );
  }
}
