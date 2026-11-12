import 'package:flutter/material.dart';

import '../core/eligibility.dart';
import '../core/models.dart';
import '../theme.dart';
import 'illustrations.dart';
import 'layout.dart';
import 'photo.dart';

/// Small, reusable building blocks shared by both dashboards.
///
/// The previous build re-implemented a stat card, a status pill and a section
/// header in nearly every page with slightly different padding and colours.
/// These are the single versions.

/// The TABANG mark used by every shell header.
///
/// One widget so the phone bar, the donor rail and the staff rail cannot drift
/// apart again. The artwork is transparent, so it is drawn directly on the
/// surface with no plate and no frame — the old white tile and its border are
/// gone, which also lets the drop, heart and hand fill the space. Surfaces
/// where the red-and-blue mark would disappear (the crimson About panel, the
/// dark theme) pass [plate] to add the white circular backdrop.
class TabangLogo extends StatelessWidget {
  const TabangLogo({super.key, this.size = 44, this.plate = false});

  static const String asset = 'assets/branding/app_icon.png';

  /// Width and height of the mark.
  final double size;

  /// Draws a white circular plate behind the mark. The artwork is red and blue
  /// on transparency, so it disappears against a crimson panel and reads muddy
  /// on a dark surface; the plate keeps it legible in both.
  final bool plate;

  @override
  Widget build(BuildContext context) {
    final art = SizedBox(
      width: size,
      height: size,
      child: TabangPhoto(
        asset,
        semanticLabel: 'TABANG',
        creditLabel: 'TABANG logo',
        fallbackIcon: Icons.water_drop,
        fallbackIconSize: size * 0.7,
      ),
    );
    if (!plate) return art;
    // The source PNG is square, but the visible drop-and-hand mark only fills
    // about 89% of its height and 74% of its width, so a padded plate would
    // frame a mostly empty transparent square. Clip the artwork to a circle the
    // same size as the requested mark instead. The art is not scaled up past
    // 1.0: the mark's tall drop tip and the hand's right edge would be cut by
    // the circular clip, which read as a chipped logo on the dark surface.
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: art,
    );
  }
}

/// Gap between the TABANG mark and its wordmark across the app lockup.
///
/// The login screen and both shell headers share it so the same header reads
/// identically on every entry point instead of drifting a couple of pixels.
const double kTabangWordmarkGap = 6;

/// Every snackbar in the app, so behaviour is uniform: it clears itself after
/// three seconds instead of four, and it can be swiped away in either
/// direction instead of only downward — a message that lingers under a thumb
/// is in the way.
class TabangSnackBar extends SnackBar {
  const TabangSnackBar({
    super.key,
    required super.content,
    super.action,
    super.duration = const Duration(seconds: 3),
    super.dismissDirection = DismissDirection.horizontal,
  });
}

/// Branded confirmation for actions that are hard to undo: signing out,
/// leaving a blood drive's chapter list, or closing the app from a phone.
///
/// Returns true only when the user picks [confirmLabel]; dismissing the dialog
/// counts as "no", so callers can always `if (!await confirmAction(...)) return;`.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(
        message,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.5,
          color: dialogContext.textMuted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: TabangColors.crimson,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A bordered surface used for every panel in the app.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TabangSpace.lg),
    this.onTap,
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(TabangRadius.md),
        border: Border.all(
          color: highlighted ? TabangColors.crimson : context.border,
          width: highlighted ? 1.6 : 1,
        ),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(TabangRadius.md),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Small contextual help affordance: a "?" that opens a short explanation.
///
/// Used beside settings sections and guide titles so help lives next to the
/// control it explains instead of being buried in a separate manual.
class HelpTip extends StatelessWidget {
  const HelpTip({
    super.key,
    required this.title,
    required this.message,
    this.size = 17,
  });

  final String title;
  final String message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'What is this?',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(Icons.help_outline, size: size, color: context.textMuted),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 380,
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.65,
                color: context.textColor,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One-line page toolbar: title on the left, actions on the right.
///
/// The tab bar and sidebar already name every page, so the previous two-line
/// title + grey description block was redundant: it pushed real content below
/// the fold and made every tab open with the same-looking heading. The
/// description is still available on hover and to screen readers.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      style: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: context.textColor,
      ),
    );

    final heading = subtitle == null
        ? titleText
        : Tooltip(
            message: subtitle!,
            waitDuration: const Duration(milliseconds: 400),
            child: Semantics(
              header: true,
              label: '$title. ${subtitle!}',
              child: ExcludeSemantics(child: titleText),
            ),
          );

    if (actions.isEmpty) return heading;

    final actionWrap = Wrap(
      spacing: TabangSpace.sm,
      runSpacing: TabangSpace.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );

    // On phones a fixed-width action (the Discover search box, for example)
    // would otherwise squeeze the title into a few characters. Stack the
    // actions under the title instead of shrinking it.
    if (context.isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: TabangSpace.md),
          actionWrap,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: heading),
        const SizedBox(width: TabangSpace.lg),
        actionWrap,
      ],
    );
  }
}

/// Section label above a group of cards.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TabangSpace.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: context.textColor,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Semantic tone for pills and badges.
enum Tone { neutral, success, warning, danger, info, brand }

/// Foreground for a [Tone]. [onLight] keeps the light-theme values when the
/// pill paints its own white [`onImage`] chip, even if the app is in dark mode.
Color _toneFg(BuildContext context, Tone tone, {bool onLight = false}) {
  final dark = context.isDark && !onLight;
  switch (tone) {
    case Tone.success:
      return dark ? TabangColors.successOnDark : TabangColors.success;
    case Tone.warning:
      return dark ? TabangColors.warningOnDark : TabangColors.warning;
    case Tone.danger:
      return dark ? TabangColors.dangerOnDark : TabangColors.danger;
    case Tone.info:
      return dark ? TabangColors.infoOnDark : TabangColors.info;
    case Tone.brand:
      return dark ? TabangColors.brandOnDark : TabangColors.crimson;
    case Tone.neutral:
      return context.textMuted;
  }
}

Color _toneBg(BuildContext context, Tone tone) {
  switch (tone) {
    case Tone.success:
      return context.successBg;
    case Tone.warning:
      return context.warningBg;
    case Tone.danger:
      return context.dangerBg;
    case Tone.info:
      return context.infoBg;
    case Tone.brand:
      return context.isDark
          ? const Color(0xFF3A1917)
          : TabangColors.crimsonSoft;
    case Tone.neutral:
      return context.surfaceAlt;
  }
}

/// Compact status chip.
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.tone = Tone.neutral,
    this.icon,
    this.dense = false,
    this.onImage = false,
  });

  final String label;
  final Tone tone;
  final IconData? icon;
  final bool dense;

  /// Paints a near-opaque light chip instead of the themed soft tint, so the
  /// label keeps its contrast over a photograph.
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final fg = onImage
        ? (tone == Tone.neutral
              ? TabangColors.crimsonDark
              : _toneFg(context, tone, onLight: true))
        : _toneFg(context, tone);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: onImage
            ? Colors.white.withValues(alpha: 0.94)
            : _toneBg(context, tone),
        borderRadius: BorderRadius.circular(TabangRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 10 : 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: dense ? 9.5 : 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact, filled count marker for panel headers.
///
/// Counts are numbers, not statuses, so this deliberately uses the solid brand
/// fill instead of [StatusPill]'s soft tint: the tinted version blended into the
/// dark map panel and read as an unlabelled notification dot. The zero state
/// falls back to the quiet surface colour so an empty queue does not look like
/// an alert.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.semanticLabel});

  final int count;

  /// Spoken description, such as "14 available donors".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final empty = count == 0;
    final dark = context.isDark;
    final background = empty
        ? context.surfaceAlt
        : (dark ? TabangColors.brandOnDark : TabangColors.crimson);
    final foreground = empty
        ? context.textMuted
        : (dark ? const Color(0xFF56100B) : Colors.white);
    return Semantics(
      label: semanticLabel ?? '$count',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 22),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(TabangRadius.pill),
          border: empty ? Border.all(color: context.border) : null,
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1.1,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

/// Blood type rendered as a compact token.
class BloodTypeChip extends StatelessWidget {
  const BloodTypeChip(this.type, {super.key, this.size = 34});

  final BloodType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.isDark
            ? const Color(0xFF3A1917)
            : TabangColors.crimsonSoft,
        borderRadius: BorderRadius.circular(TabangRadius.xs),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          // The chip's own background is maroon in dark mode; the brand
          // crimson text nearly vanished into it.
          color: context.isDark
              ? TabangColors.brandOnDark
              : TabangColors.crimson,
        ),
      ),
    );
  }
}

/// A single metric with label and optional delta/sub-label.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tone = Tone.brand,
    this.footnote,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Tone tone;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final fg = _toneFg(context, tone);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _toneBg(context, tone),
                    borderRadius: BorderRadius.circular(TabangRadius.xs),
                  ),
                  child: Icon(icon, size: 14, color: fg),
                ),
                const SizedBox(width: TabangSpace.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.md),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: context.textColor,
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: 2),
            Text(
              footnote!,
              style: TextStyle(fontSize: 10.5, color: context.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty-state block.
///
/// Prefer [art] for full illustrations; [icon] remains for compact, dense
/// surfaces such as admin tables. The artwork is drawn from theme colours so
/// it blends into the surrounding card in both light and dark mode.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon,
    this.art,
    required this.title,
    this.message,
    this.action,
  }) : assert(icon != null || art != null, 'Provide an icon or art.');

  final IconData? icon;
  final TabangArt? art;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // In a short pane (the donor list on a phone, a split chat column)
        // the full-size illustration overflows. Shrink it and let the whole
        // block scroll instead of pushing striped error bars.
        final boundedHeight = constraints.hasBoundedHeight;
        final compact = boundedHeight && constraints.maxHeight < 340;
        final padding = compact ? TabangSpace.lg : TabangSpace.xxxl;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: boundedHeight ? constraints.maxHeight : 0,
            ),
            child: Center(
              child: Container(
                margin: EdgeInsets.all(compact ? 0 : TabangSpace.md),
                padding: EdgeInsets.all(padding),
                constraints: const BoxConstraints(maxWidth: 560),
                decoration: BoxDecoration(
                  gradient: TabangGradients.empty(context),
                  borderRadius: BorderRadius.circular(TabangRadius.lg),
                  border: Border.all(
                    color: context.border.withValues(alpha: 0.55),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (art != null)
                      TabangIllustration(art!, size: compact ? 96 : 132)
                    else
                      Container(
                        width: compact ? 56 : 72,
                        height: compact ? 56 : 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              TabangColors.crimson.withValues(
                                alpha: context.isDark ? 0.22 : 0.12,
                              ),
                              TabangColors.crimson.withValues(alpha: 0),
                            ],
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: compact ? 26 : 34,
                          color: context.textMuted,
                        ),
                      ),
                    const SizedBox(height: TabangSpace.md),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textColor,
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                    if (action != null) ...[
                      const SizedBox(height: TabangSpace.lg),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Horizontal proportional bar used in analytics panels.
class ProportionBar extends StatelessWidget {
  const ProportionBar({
    super.key,
    required this.value,
    required this.max,
    this.color = TabangColors.crimson,
    this.height = 8,
    this.trackColor,
  });

  final double value;
  final double max;
  final Color color;
  final double height;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(TabangRadius.pill),
      child: Stack(
        children: [
          Container(height: height, color: trackColor ?? context.surfaceAlt),
          FractionallySizedBox(
            widthFactor: fraction,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(TabangRadius.pill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Maps an eligibility result to a display tone.
Tone toneForEligibility(EligibilityResult result) {
  if (result.isEligible) return Tone.success;
  if (result.blocker == EligibilityBlocker.cooldown) return Tone.warning;
  return Tone.danger;
}

/// Maps an account status to a display tone.
Tone toneForAccount(AccountStatus status) {
  switch (status) {
    case AccountStatus.verified:
      return Tone.success;
    case AccountStatus.unverified:
      return Tone.info;
    case AccountStatus.warned:
      return Tone.warning;
    case AccountStatus.suspended:
      return Tone.danger;
  }
}

/// Maps request urgency to a display tone.
Tone toneForUrgency(RequestUrgency urgency) {
  switch (urgency) {
    case RequestUrgency.critical:
      return Tone.danger;
    case RequestUrgency.urgent:
      return Tone.warning;
    case RequestUrgency.routine:
      return Tone.info;
  }
}

/// Maps a request status to a display tone.
Tone toneForRequest(RequestStatus status) {
  switch (status) {
    case RequestStatus.pendingReview:
      return Tone.warning;
    case RequestStatus.open:
      return Tone.info;
    case RequestStatus.matched:
      return Tone.brand;
    case RequestStatus.fulfilled:
      return Tone.success;
    case RequestStatus.rejected:
      return Tone.danger;
    case RequestStatus.cancelled:
      return Tone.neutral;
  }
}

/// Maps unit status to a display tone.
Tone toneForUnit(UnitStatus status) {
  switch (status) {
    case UnitStatus.available:
      return Tone.success;
    case UnitStatus.reserved:
      return Tone.info;
    case UnitStatus.quarantined:
      return Tone.warning;
    case UnitStatus.dispatched:
      return Tone.neutral;
    case UnitStatus.expired:
      return Tone.danger;
  }
}

/// Formats a date as `12 Oct 2026`.
String formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Formats a date and time as `12 Oct 2026 · 09:30`.
String formatDateTime(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  return '${formatDate(date)} · $h:$m';
}

/// `12 Oct 2026 · 5 days ago` - a calendar date plus how long ago it was.
///
/// Used where the age of a record matters as much as the date itself (when a
/// unit was collected, when an account registered). Unlike [formatRelative] it
/// keeps counting past a month, so an old record still reads as an age instead
/// of repeating the date: days, then weeks, then months.
String formatDateWithAge(DateTime date, {DateTime? now}) {
  final delta = (now ?? DateTime.now()).difference(date);
  final days = delta.inDays;
  final String age;
  if (delta.inMinutes < 1) {
    age = 'just now';
  } else if (delta.inMinutes < 60) {
    age = '${delta.inMinutes} min ago';
  } else if (delta.inHours < 24) {
    age = '${delta.inHours}h ago';
  } else if (days < 14) {
    age = '$days ${days == 1 ? 'day' : 'days'} ago';
  } else if (days < 60) {
    final weeks = days ~/ 7;
    age = '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
  } else {
    final months = days ~/ 30;
    age = '$months ${months == 1 ? 'month' : 'months'} ago';
  }
  return '${formatDate(date)} · $age';
}

/// Relative time such as `3h ago`, `2d ago`.
String formatRelative(DateTime date, {DateTime? now}) {
  final delta = (now ?? DateTime.now()).difference(date);
  if (delta.inMinutes < 1) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  if (delta.inDays < 30) return '${delta.inDays}d ago';
  return formatDate(date);
}
