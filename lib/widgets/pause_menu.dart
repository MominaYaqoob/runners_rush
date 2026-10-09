import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runners_rush/ui/hud_style.dart';

class PauseMenu extends StatelessWidget {
  const PauseMenu({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onHome,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              decoration: BoxDecoration(
                color: const Color(0xE62A1A3A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x73000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Paused', style: HudStyle.title(size: 24)),
                  const SizedBox(height: 20),
                  _PauseActionButton(
                    label: 'Resume',
                    icon: Icons.play_arrow_rounded,
                    prominent: true,
                    onPressed: onResume,
                  ),
                  const SizedBox(height: HudStyle.space12),
                  _PauseActionButton(
                    label: 'Restart',
                    icon: Icons.replay_rounded,
                    onPressed: onRestart,
                  ),
                  const SizedBox(height: HudStyle.space12),
                  _PauseActionButton(
                    label: 'Home',
                    icon: Icons.home_rounded,
                    onPressed: onHome,
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

class _PauseActionButton extends StatelessWidget {
  const _PauseActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.prominent = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return HudPressable(
      onPressed: onPressed,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: HudStyle.minTap),
        padding: EdgeInsets.symmetric(
          vertical: prominent ? 12 : 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: prominent ? HudStyle.playGradient : null,
          color: prominent ? null : Colors.white.withValues(alpha: 0.10),
          border: prominent
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.32)),
          boxShadow: prominent
              ? [
                  BoxShadow(
                    color: HudStyle.accentPurple.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: prominent ? 26 : 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.baloo2(
                fontSize: prominent ? 18 : 15,
                fontWeight: FontWeight.w800,
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
