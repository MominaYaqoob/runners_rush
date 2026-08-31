import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runners_rush/app_routes.dart';

class _ShopSkin {
  const _ShopSkin({
    required this.id,
    required this.name,
    required this.asset,
    required this.owned,
    this.price = 0,
  });

  final String id;
  final String name;
  final String asset;
  final bool owned;
  final int price;
}

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

  static const _skins = <_ShopSkin>[
    _ShopSkin(
      id: 'male',
      name: 'Explorer Male',
      asset: 'assets/images/male_run.png',
      owned: true,
    ),
    _ShopSkin(
      id: 'female',
      name: 'Explorer Female',
      asset: 'assets/images/female_run.png',
      owned: true,
    ),
  ];

  String _selectedId = 'male';

  void _onBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    nav.pushReplacementNamed(AppRoutes.home);
  }

  void _onSkinAction(_ShopSkin skin) {
    if (!skin.owned) return;
    setState(() => _selectedId = skin.id);
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
                    _TopBar(onBack: _onBack, coins: 0),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.05,
                            children: [
                              for (final skin in _skins)
                                _SkinCard(
                                  skin: skin,
                                  selected: _selectedId == skin.id,
                                  onPressed: () => _onSkinAction(skin),
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
    required this.selected,
    required this.onPressed,
  });

  final _ShopSkin skin;
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
              skin.asset,
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
              _StatusChip(owned: skin.owned, price: skin.price),
              const Spacer(),
              _ActionButton(
                owned: skin.owned,
                selected: selected,
                onPressed: onPressed,
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
  });

  final bool owned;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = !owned
        ? 'Unlock'
        : selected
            ? 'Selected'
            : 'Select';

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
