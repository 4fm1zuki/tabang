import 'package:flutter/material.dart';

import '../core/eligibility.dart';
import '../core/models.dart';
import '../theme.dart';
import 'illustrations.dart';
import 'layout.dart';

/// Small, reusable building blocks shared by both dashboards.
///
/// The previous build re-implemented a stat card, a status pill and a section
/// header in nearly every page with slightly different padding and colours.
/// These are the single versions.

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

/// Page title + optional subtitle + trailing actions.
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
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 12.5, color: context.textMuted),
          ),
        ],
      ],
    );

    if (actions.isEmpty) return heading;

    final actionWrap = Wrap(
      spacing: TabangSpace.sm,
      runSpacing: TabangSpace.sm,
      children: actions,
    );

    // On phones a fixed-width action (the Discover search box, for example)
    // would otherwise squeeze the title into a few characters. Stack the
    // actions under the heading instead of shrinking it.
    if (context.isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: TabangSpace.lg),
          actionWrap,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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

Color _toneFg(BuildContext context, Tone tone) {
  switch (tone) {
    case Tone.success:
      return TabangColors.success;
    case Tone.warning:
      return TabangColors.warning;
    case Tone.danger:
      return TabangColors.danger;
    case Tone.info:
      return TabangColors.info;
    case Tone.brand:
      return TabangColors.crimson;
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
      return context.isDark ? const Color(0xFF3A1917) : TabangColors.crimsonSoft;
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
            : _toneFg(context, tone))
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
        color: context.isDark ? const Color(0xFF3A1917) : TabangColors.crimsonSoft,
        borderRadius: BorderRadius.circular(TabangRadius.xs),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          color: TabangColors.crimson,
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
              child: Padding(
                padding: EdgeInsets.all(padding),
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
          Container(
            height: height,
            color: trackColor ?? context.surfaceAlt,
          ),
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
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Formats a date and time as `12 Oct 2026 · 09:30`.
String formatDateTime(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  return '${formatDate(date)} · $h:$m';
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
