import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runners_rush/app_routes.dart';
import 'package:runners_rush/services/audio_service.dart';
import 'package:runners_rush/services/character_service.dart';
import 'package:runners_rush/services/daily_reward_service.dart';
import 'package:runners_rush/services/score_service.dart';
import 'package:runners_rush/services/settings_service.dart';
import 'package:runners_rush/services/shop_service.dart';
import 'package:runners_rush/ui/hud_style.dart';
import 'package:runners_rush/widgets/themed_background.dart';

/// Home hero preview for [characterId] (`CharacterService.male` / `female`).
String _homePreviewAsset(String characterId) {
  return characterId == CharacterService.female
      ? 'assets/images/home_female_hero.png'
      : 'assets/images/home_male_hero.png';
}

/// Character-select dialog thumbnail for [characterId].
String _dialogPreviewAsset(String characterId) {
  return characterId == CharacterService.female
      ? 'assets/images/female_idle_1.png'
      : 'assets/images/male_idle_1.png';
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

  String _selectedCharacter = CharacterService.male;
  int _themeReloadToken = 0;
  bool _soundOn = true;
  bool _dailyAvailable = false;
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
    final dailyAvailable = await DailyRewardService.canClaim();
    if (!mounted) return;
    final femaleOk = unlocked.contains(CharacterService.female);
    final useFemale =
        character == CharacterService.female && femaleOk;
    setState(() {
      _highScore = highScore;
      _coins = coins;
      _soundOn = SettingsService.soundEffectsEnabled;
      _dailyAvailable = dailyAvailable;
      _selectedCharacter =
          useFemale ? CharacterService.female : CharacterService.male;
      _themeReloadToken++;
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
        return _CharacterSelectDialog(selectedId: _selectedCharacter);
      },
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedCharacter = picked);
    await CharacterService.setSelectedCharacter(picked);
  }

  Future<void> _onDailyRewardTap() async {
    if (!_dailyAvailable) return;

    final result = await DailyRewardService.claim();
    if (!mounted || result == null) {
      if (mounted) {
        setState(() => _dailyAvailable = false);
      }
      return;
    }

    final coins = await ShopService.getCoins();
    if (!mounted) return;
    setState(() {
      _coins = coins;
      _dailyAvailable = false;
    });

    AudioService.playCoin();
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => _DailyRewardDialog(claim: result),
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
            ThemedBackground(
              reloadToken: _themeReloadToken,
              child: const ColoredBox(color: Color(0x4D000000)),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  HudStyle.space16,
                  HudStyle.space8,
                  HudStyle.space16,
                  HudStyle.space8,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 620 ||
                        constraints.maxHeight < 340;
                    final sideGap = compact ? 4.0 : HudStyle.space8;
                    final leftMax = constraints.maxWidth * (compact ? 0.26 : 0.28);
                    final rightMax =
                        constraints.maxWidth * (compact ? 0.30 : 0.32);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: leftMax),
                          child: _LeftColumn(
                            coins: _coins,
                            soundOn: _soundOn,
                            dailyAvailable: _dailyAvailable,
                            compact: compact,
                            onDaily: _onDailyRewardTap,
                            onSound: () {
                              final next = !_soundOn;
                              setState(() => _soundOn = next);
                              SettingsService.setSoundEnabled(next);
                            },
                          ),
                        ),
                        SizedBox(width: sideGap),
                        Expanded(
                          child: _CharacterPreview(
                            characterId: _selectedCharacter,
                            onTap: _openCharacterSelect,
                          ),
                        ),
                        SizedBox(width: sideGap),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: rightMax),
                          child: _RightColumn(
                            highScore: _highScore,
                            compact: compact,
                            onHighScore: () =>
                                _openAndRefresh(AppRoutes.scoreboard),
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
                            onShop: () => _openAndRefresh(AppRoutes.shop),
                            onSettings: () =>
                                _openAndRefresh(AppRoutes.settings),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({
    required this.coins,
    required this.soundOn,
    required this.dailyAvailable,
    required this.compact,
    required this.onDaily,
    required this.onSound,
  });

  final int coins;
  final bool soundOn;
  final bool dailyAvailable;
  final bool compact;
  final VoidCallback onDaily;
  final VoidCallback onSound;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BrandLockup(),
        SizedBox(height: compact ? HudStyle.space8 : HudStyle.space12),
        _CoinsBadge(coins: coins),
        const Spacer(),
        _DailyGiftButton(
          available: dailyAvailable,
          onPressed: onDaily,
        ),
        SizedBox(height: compact ? HudStyle.space8 : HudStyle.space12),
        _SoundToggle(soundOn: soundOn, onPressed: onSound),
      ],
    );
  }
}

class _RightColumn extends StatelessWidget {
  const _RightColumn({
    required this.highScore,
    required this.compact,
    required this.onHighScore,
    required this.onPlay,
    required this.onCharacter,
    required this.onShop,
    required this.onSettings,
  });

  final int highScore;
  final bool compact;
  final VoidCallback onHighScore;
  final VoidCallback onPlay;
  final VoidCallback onCharacter;
  final VoidCallback onShop;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _HighScoreBadge(highScore: highScore, onTap: onHighScore),
        SizedBox(height: compact ? HudStyle.space8 : HudStyle.space12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: _ActionStack(
                onPlay: onPlay,
                onCharacter: onCharacter,
                onShop: onShop,
                onSettings: onSettings,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      decoration: HudStyle.panel(),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/app_icon.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(width: 6),
            Text('Runners Rush', style: HudStyle.title(size: 18)),
          ],
        ),
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
    return HudPressable(
      onPressed: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: HudStyle.minTap),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: HudStyle.panel(radius: 20),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: HudStyle.accentGold,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text('High Score: $highScore', style: HudStyle.body(size: 13)),
            ],
          ),
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
      decoration: HudStyle.panel(radius: 20),
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
            style: HudStyle.body(weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CharacterPreview extends StatelessWidget {
  const _CharacterPreview({
    required this.characterId,
    required this.onTap,
  });

  final String characterId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = _homePreviewAsset(characterId);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: HudPressable(
                onPressed: onTap,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned(
                      bottom: 6,
                      child: IgnorePointer(
                        child: Container(
                          width: (constraints.maxWidth * 0.55).clamp(70, 180),
                          height: 22,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: const Color(0xFF6B3FA0)
                                    .withValues(alpha: 0.28),
                                blurRadius: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Image.asset(
                        asset,
                        key: const ValueKey('home-character-preview'),
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: HudStyle.space8),
            _SelectCharacterChip(onTap: onTap),
          ],
        );
      },
    );
  }
}

class _SelectCharacterChip extends StatelessWidget {
  const _SelectCharacterChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HudPressable(
      onPressed: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: HudStyle.fill,
          borderRadius: BorderRadius.circular(20),
          border: HudStyle.border,
          boxShadow: HudStyle.shadow,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Tap to select character',
                style: HudStyle.caption(size: 12),
              ),
            ],
          ),
        ),
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
        const SizedBox(height: HudStyle.space16),
        _HudAction(
          icon: Icons.person_rounded,
          label: 'Character',
          onPressed: onCharacter,
        ),
        const SizedBox(height: HudStyle.space12),
        _HudAction(
          icon: Icons.shopping_bag_rounded,
          label: 'Shop',
          onPressed: onShop,
        ),
        const SizedBox(height: HudStyle.space12),
        _HudAction(
          icon: Icons.settings_rounded,
          label: 'Settings',
          onPressed: onSettings,
        ),
      ],
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    final inTest = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    if (!inTest) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = 0.97 + (_pulse.value * 0.03);
        return Transform.scale(scale: t, child: child);
      },
      child: HudPressable(
        onPressed: widget.onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: HudStyle.minTap),
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: HudStyle.playGradient,
            boxShadow: [
              BoxShadow(
                color: HudStyle.accentPurple.withValues(alpha: 0.55),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 34,
              ),
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
    return HudPressable(
      onPressed: onPressed,
      child: Container(
        width: HudStyle.sideButton,
        height: HudStyle.sideButton,
        decoration: HudStyle.panel(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 2),
            Text(label, style: HudStyle.caption()),
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
    return HudPressable(
      onPressed: onPressed,
      child: Container(
        width: HudStyle.minTap,
        height: HudStyle.minTap,
        decoration: HudStyle.panel(),
        child: Icon(
          soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

class _DailyGiftButton extends StatelessWidget {
  const _DailyGiftButton({
    required this.available,
    required this.onPressed,
  });

  final bool available;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HudPressable(
      onPressed: onPressed,
      child: SizedBox(
        width: HudStyle.minTap,
        height: HudStyle.minTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: HudStyle.minTap,
              height: HudStyle.minTap,
              decoration: available
                  ? BoxDecoration(
                      color: HudStyle.fill,
                      borderRadius: BorderRadius.circular(HudStyle.radius),
                      border: Border.all(
                        color: HudStyle.accentGold.withValues(alpha: 0.9),
                        width: 1.5,
                      ),
                      boxShadow: [
                        ...HudStyle.shadow,
                        BoxShadow(
                          color: HudStyle.accentGold.withValues(alpha: 0.45),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    )
                  : HudStyle.panel(),
              child: Icon(
                available
                    ? Icons.card_giftcard_rounded
                    : Icons.check_rounded,
                color: available
                    ? HudStyle.accentGold
                    : Colors.white.withValues(alpha: 0.55),
                size: 24,
              ),
            ),
            if (available)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyRewardDialog extends StatelessWidget {
  const _DailyRewardDialog({required this.claim});

  final DailyRewardClaim claim;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 320,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Daily Reward!', style: HudStyle.title()),
                const SizedBox(height: 6),
                Text(
                  'Day ${claim.streakDay} streak',
                  style: HudStyle.caption(size: 14),
                ),
                const SizedBox(height: 16),
                Image.asset(
                  'assets/images/coin.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(height: 10),
                Text(
                  '+${claim.coins} coins',
                  style: GoogleFonts.baloo2(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: HudStyle.accentGold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 18),
                HudPressable(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: HudStyle.playGradient,
                      boxShadow: [
                        BoxShadow(
                          color: HudStyle.accentPurple.withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'Nice!',
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
    );
  }
}

class _CharacterSelectDialog extends StatefulWidget {
  const _CharacterSelectDialog({required this.selectedId});

  final String selectedId;

  @override
  State<_CharacterSelectDialog> createState() => _CharacterSelectDialogState();
}

class _CharacterSelectDialogState extends State<_CharacterSelectDialog> {
  late String _pendingId = widget.selectedId;
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
      if (!femaleOk && _pendingId == CharacterService.female) {
        _pendingId = CharacterService.male;
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
      _pendingId = CharacterService.female;
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
                  Text('Choose Character', style: HudStyle.title()),
                  const SizedBox(height: HudStyle.space12),
                  Row(
                    children: [
                      Expanded(
                        child: _CharacterOption(
                          asset: _dialogPreviewAsset(CharacterService.male),
                          label: 'Explorer Male',
                          selected: _pendingId == CharacterService.male,
                          locked: false,
                          onTap: () {
                            setState(() {
                              _hint = null;
                              _pendingId = CharacterService.male;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _CharacterOption(
                          asset: _dialogPreviewAsset(CharacterService.female),
                          label: 'Explorer Female',
                          selected: _pendingId == CharacterService.female,
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
                  HudPressable(
                    onPressed: () => Navigator.of(context).pop(_pendingId),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: HudStyle.playGradient,
                        boxShadow: [
                          BoxShadow(
                            color:
                                HudStyle.accentPurple.withValues(alpha: 0.45),
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

  @override
  Widget build(BuildContext context) {
    return HudPressable(
      onPressed: onTap,
      child: Opacity(
        opacity: locked ? 0.5 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HudStyle.radius),
            color: Colors.white.withValues(alpha: selected ? 0.12 : 0.08),
            border: Border.all(
              color: selected
                  ? HudStyle.accentOrange
                  : Colors.white.withValues(alpha: 0.2),
              width: selected ? 3 : 1,
            ),
            boxShadow: selected && !locked
                ? [
                    BoxShadow(
                      color: HudStyle.accentOrange.withValues(alpha: 0.55),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : HudStyle.shadow,
          ),
          child: Column(
            children: [
              SizedBox(
                height: 110,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            asset,
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        if (locked)
                          Center(
                            child: Container(
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
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: HudStyle.body(weight: FontWeight.w700),
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
