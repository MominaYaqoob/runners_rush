import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runners_rush/app_routes.dart';
import 'package:runners_rush/services/character_service.dart';
import 'package:runners_rush/services/shop_service.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static const _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  static const hudFill = Color(0x66000000);
  static const hudBorder = Color(0x26FFFFFF);

  String _selectedId = CharacterService.male;
  String _selectedBackgroundId = ShopService.eveningId;
  int _coins = 0;
  Set<String> _unlocked = {CharacterService.male};
  Set<String> _unlockedBackgrounds = {ShopService.eveningId};
  String? _toast;

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    final coins = await ShopService.getCoins();
    final unlocked = await ShopService.getUnlockedCharacters();
    final selected = await CharacterService.getSelectedCharacter();
    final unlockedBgs = await ShopService.getUnlockedBackgrounds();
    final selectedBg = await ShopService.getSelectedBackground();
    if (!mounted) return;
    final unlockedSet = unlocked.toSet();
    setState(() {
      _coins = coins;
      _unlocked = unlockedSet;
      _selectedId =
          unlockedSet.contains(selected) ? selected : CharacterService.male;
      _unlockedBackgrounds = unlockedBgs;
      _selectedBackgroundId = selectedBg;
    });
  }

  void _onBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    nav.pushReplacementNamed(AppRoutes.home);
  }

  Future<void> _onSkinAction(ShopCharacter skin) async {
    if (_unlocked.contains(skin.id)) {
      await CharacterService.setSelectedCharacter(skin.id);
      if (!mounted) return;
      setState(() => _selectedId = skin.id);
      return;
    }

    final ok = await ShopService.purchaseCharacter(skin.id, skin.price);
    if (!mounted) return;
    if (!ok) {
      _showToast('Not enough coins');
      return;
    }
    final coins = await ShopService.getCoins();
    final unlocked = await ShopService.getUnlockedCharacters();
    await CharacterService.setSelectedCharacter(skin.id);
    if (!mounted) return;
    setState(() {
      _coins = coins;
      _unlocked = unlocked.toSet();
      _selectedId = skin.id;
    });
  }

  Future<void> _onBackgroundAction(ShopBackground bg) async {
    if (_unlockedBackgrounds.contains(bg.id)) {
      await ShopService.setSelectedBackground(bg.id);
      if (!mounted) return;
      setState(() => _selectedBackgroundId = bg.id);
      return;
    }

    final ok = await ShopService.purchaseBackground(bg.id, bg.price);
    if (!mounted) return;
    if (!ok) {
      _showToast('Not enough coins');
      return;
    }
    final coins = await ShopService.getCoins();
    final unlocked = await ShopService.getUnlockedBackgrounds();
    await ShopService.setSelectedBackground(bg.id);
    if (!mounted) return;
    setState(() {
      _coins = coins;
      _unlockedBackgrounds = unlocked;
      _selectedBackgroundId = bg.id;
    });
  }

  void _showToast(String message) {
    setState(() => _toast = message);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_toast == message) setState(() => _toast = null);
    });
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
                    _TopBar(onBack: _onBack, coins: _coins),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: ListView(
                            children: [
                              _SectionTitle('Characters'),
                              const SizedBox(height: 8),
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.05,
                                children: [
                                  for (final skin in ShopService.characters)
                                    _SkinCard(
                                      skin: skin,
                                      owned: _unlocked.contains(skin.id),
                                      selected: _selectedId == skin.id,
                                      onPressed: () => _onSkinAction(skin),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _SectionTitle('Backgrounds'),
                              const SizedBox(height: 8),
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 3,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1.15,
                                children: [
                                  for (final bg in ShopService.backgrounds)
                                    _BackgroundCard(
                                      background: bg,
                                      owned: _unlockedBackgrounds.contains(
                                        bg.id,
                                      ),
                                      selected:
                                          _selectedBackgroundId == bg.id,
                                      onPressed: () =>
                                          _onBackgroundAction(bg),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_toast != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE6000000),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: hudBorder),
                    ),
                    child: Text(
                      _toast!,
                      style: GoogleFonts.baloo2(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.baloo2(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.1,
          shadows: const [
            Shadow(
              color: Color(0x99000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.coins});

  final VoidCallback onBack;
  final int coins;

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
                  color: _ShopScreenState.hudFill,
                  border: Border.all(color: _ShopScreenState.hudBorder),
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
            'Shop',
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
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
              decoration: BoxDecoration(
                color: _ShopScreenState.hudFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _ShopScreenState.hudBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/coin.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$coins',
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.owned,
    required this.selected,
    required this.onPressed,
  });

  final ShopCharacter skin;
  final bool owned;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0x73000000),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? const Color(0xFFFF8A3D)
              : _ShopScreenState.hudBorder,
          width: selected ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Image.asset(
              skin.assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            skin.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (owned)
                const _StatusChip(owned: true, price: 0)
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/coin.png',
                      width: 14,
                      height: 14,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${skin.price}',
                      style: GoogleFonts.baloo2(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFD27A),
                        height: 1,
                      ),
                    ),
                  ],
                ),
              const Spacer(),
              _ActionButton(
                owned: owned,
                selected: selected,
                onPressed: onPressed,
                buyLabel: 'Buy',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackgroundCard extends StatelessWidget {
  const _BackgroundCard({
    required this.background,
    required this.owned,
    required this.selected,
    required this.onPressed,
  });

  final ShopBackground background;
  final bool owned;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0x73000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? const Color(0xFFFF8A3D)
              : _ShopScreenState.hudBorder,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                background.flutterAsset,
                fit: BoxFit.cover,
                width: double.infinity,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            background.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.baloo2(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (owned)
                _StatusChip(owned: true, price: 0)
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/coin.png',
                      width: 14,
                      height: 14,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${background.price}',
                      style: GoogleFonts.baloo2(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFD27A),
                        height: 1,
                      ),
                    ),
                  ],
                ),
              const Spacer(),
              _ActionButton(
                owned: owned,
                selected: selected,
                onPressed: onPressed,
                buyLabel: 'Buy',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.owned, required this.price});

  final bool owned;
  final int price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: owned
            ? const Color(0x6632C48D)
            : const Color(0x66FF8A3D),
        border: Border.all(
          color: owned
              ? const Color(0x99A5F0D0)
              : const Color(0x99FF8A3D),
        ),
      ),
      child: Text(
        owned ? 'Owned' : '$price',
        style: GoogleFonts.baloo2(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.owned,
    required this.selected,
    required this.onPressed,
    this.buyLabel = 'Unlock',
  });

  final bool owned;
  final bool selected;
  final VoidCallback onPressed;
  final String buyLabel;

  @override
  Widget build(BuildContext context) {
    final label = !owned
        ? buyLabel
        : selected
            ? 'Selected'
            : 'Select';

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: selected || !owned
              ? const LinearGradient(
                  colors: [Color(0xFFFF8A3D), Color(0xFF6B3FA0)],
                )
              : null,
          color: selected || !owned ? null : Colors.white.withValues(alpha: 0.14),
          border: selected || !owned
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.baloo2(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
