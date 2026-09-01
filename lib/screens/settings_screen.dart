import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runners_rush/app_routes.dart';
import 'package:runners_rush/services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
  static const _accentOrange = Color(0xFFFF8A3D);
  static const _accentPurple = Color(0xFF6B3FA0);

  bool _soundEffects = true;
  bool _backgroundMusic = true;
  bool _vibration = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final sound = await SettingsService.getSoundEnabled();
    final music = await SettingsService.getMusicEnabled();
    final vibration = await SettingsService.getVibrationEnabled();
    if (!mounted) return;
    setState(() {
      _soundEffects = sound;
      _backgroundMusic = music;
      _vibration = vibration;
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

  void _openAbout() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => const _AboutDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyle,
      child: Theme(
        data: Theme.of(context).copyWith(
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return _accentOrange;
              }
              return Colors.white;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return _accentPurple;
              }
              return Colors.white.withValues(alpha: 0.22);
            }),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
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
                      _TopBar(onBack: _onBack),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: ListView(
                              children: [
                                _ToggleRow(
                                  icon: Icons.volume_up_rounded,
                                  label: 'Sound Effects',
                                  value: _soundEffects,
                                  onChanged: (value) {
                                    setState(() => _soundEffects = value);
                                    SettingsService.setSoundEnabled(value);
                                  },
                                ),
                                const SizedBox(height: 10),
                                _ToggleRow(
                                  icon: Icons.music_note_rounded,
                                  label: 'Background Music',
                                  value: _backgroundMusic,
                                  onChanged: (value) {
                                    setState(() => _backgroundMusic = value);
                                    SettingsService.setMusicEnabled(value);
                                  },
                                ),
                                const SizedBox(height: 10),
                                _ToggleRow(
                                  icon: Icons.vibration_rounded,
                                  label: 'Vibration',
                                  value: _vibration,
                                  onChanged: (value) {
                                    setState(() => _vibration = value);
                                    SettingsService.setVibrationEnabled(value);
                                  },
                                ),
                                const SizedBox(height: 10),
                                _AboutRow(onTap: _openAbout),
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
                  color: _SettingsScreenState.hudFill,
                  border: Border.all(color: _SettingsScreenState.hudBorder),
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
            'Settings',
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _SettingsScreenState.hudFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _SettingsScreenState.hudBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.info_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'About',
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: 0.7),
            size: 26,
          ),
        ],
      ),
    );
  }
}

class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 380,
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
        decoration: BoxDecoration(
          color: const Color(0xE62A1A3A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Runners Rush',
              style: GoogleFonts.baloo2(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Version 1.0.0',
              style: GoogleFonts.baloo2(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Run. Jump. Survive.\nA jungle-ruins endless runner.',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Credits: Runners Rush team',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8A3D), Color(0xFF6B3FA0)],
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.baloo2(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
