import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Hand-built vector illustrations used in empty states and onboarding.
///
/// They are drawn from theme colours instead of shipped as bitmaps so they
/// blend into light and dark surfaces, stay crisp at any density, and add no
/// download weight. The soft radial wash has a fully transparent edge, which
/// is what makes the art sit in the card rather than on top of it.
enum TabangArt {
  requests,
  donors,
  messages,
  inventory,
  welcome,
  search,
}

class TabangIllustration extends StatelessWidget {
  const TabangIllustration(this.art, {super.key, this.size = 132});

  final TabangArt art;
  final double size;

  _ArtConfig get _config {
    switch (art) {
      case TabangArt.requests:
        return const _ArtConfig(
          main: Icons.bloodtype_outlined,
          accent: Icons.event_available_outlined,
        );
      case TabangArt.donors:
        return const _ArtConfig(
          main: Icons.person_search_outlined,
          accent: Icons.location_on_outlined,
        );
      case TabangArt.messages:
        return const _ArtConfig(
          main: Icons.forum_outlined,
          accent: Icons.favorite_outline,
        );
      case TabangArt.inventory:
        return const _ArtConfig(
          main: Icons.inventory_2_outlined,
          accent: Icons.water_drop_outlined,
        );
      case TabangArt.welcome:
        return const _ArtConfig(
          main: Icons.volunteer_activism_outlined,
          accent: Icons.people_outline,
        );
      case TabangArt.search:
        return const _ArtConfig(
          main: Icons.search_outlined,
          accent: Icons.filter_alt_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final accentBg = context.isDark
        ? const Color(0xFF3A1917)
        : TabangColors.crimsonSoft;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft wash that fades to fully transparent at the edges so the
          // illustration blends into whatever surface it is placed on.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    TabangColors.crimson.withValues(
                      alpha: context.isDark ? 0.22 : 0.14,
                    ),
                    TabangColors.crimson.withValues(alpha: 0),
                  ],
                  stops: const [0.35, 1],
                ),
              ),
            ),
          ),
          CustomPaint(
            size: Size.square(size * 0.92),
            painter: _DotRingPainter(
              color: TabangColors.crimson.withValues(
                alpha: context.isDark ? 0.35 : 0.22,
              ),
            ),
          ),
          Container(
            width: size * 0.52,
            height: size * 0.52,
            decoration: BoxDecoration(
              color: context.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: TabangColors.crimson.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: context.isDark ? 0.35 : 0.06,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              config.main,
              size: size * 0.26,
              color: TabangColors.crimson,
            ),
          ),
          Positioned(
            top: size * 0.12,
            right: size * 0.1,
            child: Container(
              width: size * 0.26,
              height: size * 0.26,
              decoration: BoxDecoration(
                color: accentBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.surface,
                  width: 2,
                ),
              ),
              child: Icon(
                config.accent,
                size: size * 0.13,
                color: TabangColors.crimsonDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtConfig {
  const _ArtConfig({required this.main, required this.accent});

  final IconData main;
  final IconData accent;
}

/// A sparse dotted ring around the main badge. Purely decorative.
class _DotRingPainter extends CustomPainter {
  _DotRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    const dotCount = 26;
    for (var i = 0; i < dotCount; i++) {
      // Leave a gap at the top right where the accent badge sits.
      final angle = (i / dotCount) * 2 * math.pi;
      if (angle > 5.0 && angle < 6.1) continue;
      final dotRadius = i % 4 == 0 ? 1.8 : 1.1;
      final offset = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawCircle(offset, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_DotRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
