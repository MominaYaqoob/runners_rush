import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runners_rush/app_routes.dart';
import 'package:runners_rush/services/audio_service.dart';
import 'package:runners_rush/services/character_service.dart';
import 'package:runners_rush/services/score_service.dart';
import 'package:runners_rush/services/settings_service.dart';
import 'package:runners_rush/services/shop_service.dart';

class _Hud {
  static const fill = Color(0x66000000);
  static const borderColor = Color(0x26FFFFFF);
  static const radius = 16.0;

  static Border get border => Border.all(color: borderColor, width: 1);

  static List<BoxShadow> get shadow => const [
        BoxShadow(
          color: Color(0x59000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];

  static BoxDecoration card({double radius = _Hud.radius}) {
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      border: border,
      boxShadow: shadow,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  static const _maleAsset = 'assets/images/male_run.png';
  static const _femaleAsset = 'assets/images/female_run.png';
  static const _defaultBackgroundAsset =
      'assets/images/background_evening.png';

  String _selectedCharacter = _maleAsset;
  String _backgroundAsset = _defaultBackgroundAsset;
  bool _soundOn = true;
  int _highScore = 0;
  int _coins = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(_overlayStyle);
    _soundOn = SettingsService.soundEffectsEnabled;
    _loadPersistedState();
  }

  Future<void> _loadPersistedState() async {
    final highScore = await ScoreService.getHighScore();
    final coins = await ShopService.getCoins();
    await SettingsService.init();
    await AudioService.init();
    final character = await CharacterService.getSelectedCharacter();
    final unlocked = await ShopService.getUnlockedCharacters();
    final backgroundPath =
        await ShopService.getSelectedBackgroundAssetPath();
    if (!mounted) return;
    final femaleOk = unlocked.contains(CharacterService.female);
    final useFemale =
        character == CharacterService.female && femaleOk;
    setState(() {
      _highScore = highScore;
      _coins = coins;
      _soundOn = SettingsService.soundEffectsEnabled;
      _selectedCharacter = useFemale ? _femaleAsset : _maleAsset;
      _backgroundAsset = 'assets/images/$backgroundPath';
    });
    if (character == CharacterService.female && !femaleOk) {
      await CharacterService.setSelectedCharacter(CharacterService.male);
    }
  }

  Future<void> _openAndRefresh(String routeName) async {
    await Navigator.pushNamed(context, routeName);
    if (!mounted) return;
    await _loadPersistedState();
  }

  Future<void> _openCharacterSelect() async {
    final picked = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        return _CharacterSelectDialog(selectedAsset: _selectedCharacter);
      },
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedCharacter = picked);
    await CharacterService.setSelectedCharacter(
      picked == _femaleAsset ? CharacterService.female : CharacterService.male,
    );
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
              _backgroundAsset,
              fit: BoxFit.cover,
            ),
            const ColoredBox(color: Color(0x4D000000)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 48,
                      child: _CharacterPreview(
                        selectedAsset: _selectedCharacter,
                        onTap: _openCharacterSelect,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _BrandLockup(),
                            const Spacer(),
                            _SoundToggle(
                              soundOn: _soundOn,
                              onPressed: () {
                                final next = !_soundOn;
                                setState(() => _soundOn = next);
                                SettingsService.setSoundEnabled(next);
                              },
                            ),
                          ],
                        ),
                        const Expanded(
                          child: IgnorePointer(child: SizedBox.expand()),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _HighScoreBadge(
                              highScore: _highScore,
                              onTap: () => _openAndRefresh(AppRoutes.scoreboard),
                            ),
                            const SizedBox(height: 8),
                            _CoinsBadge(coins: _coins),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: _ActionStack(
                                    onPlay: () async {
                                      await Navigator.pushNamed(
                                        context,
                                        AppRoutes.gameplay,
                                        arguments: _selectedCharacter,
                                      );
                                      if (!mounted) return;
                                      await _loadPersistedState();
                                    },
                                    onCharacter: _openCharacterSelect,
                                    onShop: () =>
                                        _openAndRefresh(AppRoutes.shop),
                                    onSettings: () =>
                                        _openAndRefresh(AppRoutes.settings),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      decoration: _Hud.card(radius: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/app_icon.png',
            width: 56,
            height: 56,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 10),
          Text(
            'Runners Rush',
            style: GoogleFonts.baloo2(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighScoreBadge extends StatelessWidget {
  const _HighScoreBadge({
    required this.highScore,
    required this.onTap,
  });

  final int highScore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: _Hud.card(radius: 22),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFFFC857),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'High Score: $highScore',
              style: GoogleFonts.baloo2(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinsBadge extends StatelessWidget {
  const _CoinsBadge({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: _Hud.card(radius: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/coin.png',
            width: 18,
            height: 18,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: GoogleFonts.baloo2(
              fontSize: 14,
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

class _CharacterPreview extends StatelessWidget {
  const _CharacterPreview({
    required this.selectedAsset,
    required this.onTap,
  });

  final String selectedAsset;
  final VoidCallback onTap;

  static const _maleHero = 'assets/images/home_male_hero.png';
  static const _femaleIdle = 'assets/images/female_idle_1.png';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMale = selectedAsset.contains('male_');
    final asset = isMale ? _maleHero : _femaleIdle;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: size.height * 0.72,
              maxWidth: size.width * 0.42,
            ),
            child: Image.asset(
              asset,
              key: const ValueKey('home-character-preview'),
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              filterQuality:
                  isMale ? FilterQuality.high : FilterQuality.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to select character',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionStack extends StatelessWidget {
  const _ActionStack({
    required this.onPlay,
    required this.onCharacter,
    required this.onShop,
    required this.onSettings,
  });

  final VoidCallback onPlay;
  final VoidCallback onCharacter;
  final VoidCallback onShop;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlayButton(onPressed: onPlay),
        const SizedBox(height: 20),
        _HudAction(
          icon: Icons.person_rounded,
          label: 'Character',
          onPressed: onCharacter,
        ),
        const SizedBox(height: 16),
        _HudAction(
          icon: Icons.shopping_bag_rounded,
          label: 'Shop',
          onPressed: onShop,
        ),
        const SizedBox(height: 16),
        _HudAction(
          icon: Icons.settings_rounded,
          label: 'Settings',
          onPressed: onSettings,
        ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.playButtonTap();
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8A3D), Color(0xFF6B3FA0)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B3FA0).withValues(alpha: 0.55),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
            const SizedBox(width: 8),
            Text(
              'PLAY',
              style: GoogleFonts.baloo2(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.4,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudAction extends StatelessWidget {
  const _HudAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.playButtonTap();
        onPressed();
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: _Hud.card(radius: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.baloo2(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoundToggle extends StatelessWidget {
  const _SoundToggle({
    required this.soundOn,
    required this.onPressed,
  });

  final bool soundOn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 52,
        height: 52,
        decoration: _Hud.card(radius: 16),
        child: Icon(
          soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

class _CharacterSelectDialog extends StatefulWidget {
  const _CharacterSelectDialog({required this.selectedAsset});

  final String selectedAsset;

  static const maleAsset = 'assets/images/male_run.png';
  static const femaleAsset = 'assets/images/female_run.png';
  static const malePreview = 'assets/images/male_idle_1.png';
  static const femalePreview = 'assets/images/female_idle_1.png';

  @override
  State<_CharacterSelectDialog> createState() => _CharacterSelectDialogState();
}

class _CharacterSelectDialogState extends State<_CharacterSelectDialog> {
  late String _pendingAsset = widget.selectedAsset;
  bool _femaleUnlocked = false;
  bool _loaded = false;
  String? _hint;

  int get _femalePrice =>
      ShopService.characterById(CharacterService.female).price;

  @override
  void initState() {
    super.initState();
    _loadUnlocks();
  }

  Future<void> _loadUnlocks() async {
    final unlocked = await ShopService.getUnlockedCharacters();
    if (!mounted) return;
    final femaleOk = unlocked.contains(CharacterService.female);
    setState(() {
      _femaleUnlocked = femaleOk;
      _loaded = true;
      if (!femaleOk &&
          _pendingAsset == _CharacterSelectDialog.femaleAsset) {
        _pendingAsset = _CharacterSelectDialog.maleAsset;
      }
    });
  }

  void _onFemaleTap() {
    if (!_femaleUnlocked) {
      setState(() => _hint = 'Unlock in Shop first');
      return;
    }
    setState(() {
      _hint = null;
      _pendingAsset = _CharacterSelectDialog.femaleAsset;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 460,
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            decoration: BoxDecoration(
              color: const Color(0xE62A1A3A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose Character',
                  style: GoogleFonts.baloo2(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _CharacterOption(
                        asset: _CharacterSelectDialog.malePreview,
                        label: 'Explorer Male',
                        selected:
                            _pendingAsset == _CharacterSelectDialog.maleAsset,
                        locked: false,
                        onTap: () {
                          setState(() {
                            _hint = null;
                            _pendingAsset = _CharacterSelectDialog.maleAsset;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _CharacterOption(
                        asset: _CharacterSelectDialog.femalePreview,
                        label: 'Explorer Female',
                        selected: _pendingAsset ==
                            _CharacterSelectDialog.femaleAsset,
                        locked: _loaded && !_femaleUnlocked,
                        priceLabel: _loaded && !_femaleUnlocked
                            ? '$_femalePrice 🪙'
                            : null,
                        onTap: _onFemaleTap,
                      ),
                    ),
                  ],
                ),
                if (_hint != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _hint!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFFD27A),
                      height: 1.2,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(_pendingAsset),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8A3D), Color(0xFF6B3FA0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF6B3FA0).withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'Confirm',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.6,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacterOption extends StatelessWidget {
  const _CharacterOption({
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
    this.locked = false,
    this.priceLabel,
  });

  final String asset;
  final String label;
  final bool selected;
  final bool locked;
  final String? priceLabel;
  final VoidCallback onTap;

  static const _glow = Color(0xFFFF8A3D);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.5 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: selected ? 0.12 : 0.08),
            border: Border.all(
              color: selected ? _glow : Colors.white.withValues(alpha: 0.2),
              width: selected ? 3 : 1,
            ),
            boxShadow: selected && !locked
                ? [
                    BoxShadow(
                      color: _glow.withValues(alpha: 0.62),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFC857).withValues(alpha: 0.28),
                      blurRadius: 28,
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      asset,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      height: 96,
                    ),
                    if (locked)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              if (priceLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  priceLabel!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFFD27A),
                    height: 1.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
