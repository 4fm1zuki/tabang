import 'package:flutter/material.dart';

import '../core/image_credits.dart';
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
    this.creditLabel,
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

  /// Optional person/place name used to identify an avatar in its credit.
  final String? creditLabel;

  @override
  Widget build(BuildContext context) {
    final credit = creditForAsset(asset, label: creditLabel);
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

    // Hovering any credited photograph reveals the exact file credit. Original
    // TABANG artwork is skipped: there is no external source to reveal.
    final attributed = credit == null || credit.isOriginal
        ? clipped
        : Tooltip(
            message: '${credit.title}\n${credit.author} · ${credit.license}',
            waitDuration: const Duration(milliseconds: 350),
            child: clipped,
          );

    if (overlay == null) return attributed;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        attributed,
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

/// A compact, tappable per-image attribution chip.
///
/// The full source (file, creator, licence and, for photographs, a link) opens
/// on tap or long-press instead of printing a raw URL under every picture. The
/// author and licence still stay visible beneath the image, so attribution is
/// never hidden behind an interaction.
class PhotoCredit extends StatelessWidget {
  const PhotoCredit(
    this.asset, {
    super.key,
    this.label,
    this.onImage = false,
    this.alignment = TextAlign.start,
  });

  final String? asset;
  final String? label;

  /// Renders a translucent chip for use directly over a photograph.
  final bool onImage;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    final credit = creditForAsset(asset, label: label);
    // Original TABANG artwork (avatars, educational illustrations, the app
    // icon) has no external author to credit, so no chip is shown at all —
    // file paths and "TABANG original artwork" lines are noise for users.
    if (credit == null || credit.isOriginal) return const SizedBox.shrink();

    final prefix = switch (credit.kind) {
      'photo' => 'Photo',
      'avatar' => 'Illustration',
      'icon' => 'Icon',
      _ => 'Artwork',
    };
    final foreground = onImage ? Colors.white : context.textMuted;

    final chip = Material(
      color: onImage
          ? Colors.black.withValues(alpha: 0.34)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(TabangRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(TabangRadius.pill),
        onTap: () => showImageCreditDialog(context, credit),
        onLongPress: () => showImageCreditDialog(context, credit),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: onImage ? 10 : 6,
            vertical: onImage ? 5 : 3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                credit.isOriginal
                    ? Icons.brush_outlined
                    : Icons.photo_camera_outlined,
                size: 12,
                color: foreground,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '$prefix: ${credit.author} · ${credit.license}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.info_outline, size: 11, color: foreground),
            ],
          ),
        ),
      ),
    );

    return Align(
      alignment: alignment == TextAlign.center
          ? Alignment.center
          : alignment == TextAlign.end
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: chip,
    );
  }
}

/// Full provenance for one image.
///
/// Photographs show the exact Commons-style source link. Original TABANG
/// artwork has no external source to link to, so that row is omitted entirely
/// rather than showing an empty or misleading URL.
Future<void> showImageCreditDialog(BuildContext context, ImageCredit credit) {
  final prefix = switch (credit.kind) {
    'photo' => 'Photo',
    'avatar' => 'Illustration',
    'icon' => 'Icon',
    _ => 'Artwork',
  };
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('$prefix credit'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                credit.title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${credit.author} · ${credit.license}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: dialogContext.textMuted,
                ),
              ),
              // No asset path here: file directories are implementation
              // detail, not something a reader needs.
              if (credit.sourceUrl != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Source',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: dialogContext.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  credit.sourceUrl!,
                  style: const TextStyle(fontSize: 12, height: 1.45),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
