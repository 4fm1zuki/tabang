import 'package:flutter/material.dart';

import '../theme.dart';

/// A locally bundled TABANG photograph with a themed fallback.
///
/// Every photo ships in `assets/images`, so the widget never makes a network
/// request. If an asset is missing from a stripped-down build, the fallback
/// keeps the layout stable and on-brand instead of showing Flutter's red
/// error box. The brief fade-in only affects paint, not layout.
class TabangPhoto extends StatelessWidget {
  const TabangPhoto(
    this.asset, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.borderRadius,
    this.overlay,
    this.fallbackIcon = Icons.volunteer_activism_outlined,
    this.fallbackIconSize = 28,
    this.width,
    this.height,
  });

  /// Bundled asset path, or `null` to render the fallback directly.
  final String? asset;
  final BoxFit fit;
  final Alignment alignment;
  final String? semanticLabel;
  final BorderRadius? borderRadius;

  /// Painted above the photo, normally a scrim that keeps text readable.
  final Widget? overlay;

  final IconData fallbackIcon;
  final double fallbackIconSize;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final image = asset == null
        ? _fallback(context)
        : Image.asset(
            asset!,
            fit: fit,
            alignment: alignment,
            width: width,
            height: height,
            semanticLabel: semanticLabel,
            filterQuality: FilterQuality.medium,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) => _fallback(context),
          );

    final clipped = borderRadius == null
        ? image
        : ClipRRect(borderRadius: borderRadius!, child: image);

    if (overlay == null) return clipped;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        clipped,
        Positioned.fill(child: overlay!),
      ],
    );
  }

  Widget _fallback(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel ?? 'Photo unavailable',
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: context.isDark
                ? const [Color(0xFF3A1917), Color(0xFF241110)]
                : const [TabangColors.crimsonSoft, Color(0xFFFDF0EF)],
          ),
        ),
        child: Icon(
          fallbackIcon,
          size: fallbackIconSize,
          color: TabangColors.crimson.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
