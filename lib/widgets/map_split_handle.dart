import 'package:flutter/material.dart';

import '../theme.dart';

/// Draggable divider between a map and its list panel.
///
/// Replaces the old Expand / Collapse and panel-chevron buttons. On a phone the
/// handle is a horizontal grab bar between the stacked map and list; on a wide
/// window it is a vertical grab bar between the map and the side panel.
///
/// The page owns the split state (snap points, restore bubble); this widget
/// only reports drag deltas in logical pixels.
class MapSplitHandle extends StatelessWidget {
  const MapSplitHandle({
    super.key,
    required this.vertical,
    required this.onDelta,
    required this.onDragEnd,
    required this.tooltip,
  });

  /// Thickness of the handle along the drag axis.
  static const double extent = 18;

  /// Length of the visible grip along the drag axis. Long enough to read as a
  /// grab handle at a glance, on both the wide side bar and the phone bar.
  static const double gripLength = 84;

  /// True for the vertical bar used beside a side panel (drag left/right);
  /// false for the horizontal bar between stacked map and list (drag up/down).
  final bool vertical;

  final ValueChanged<double> onDelta;
  final VoidCallback onDragEnd;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final grip = Container(
      width: vertical ? 4 : gripLength,
      height: vertical ? gripLength : 4,
      decoration: BoxDecoration(
        color: context.textMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(TabangRadius.pill),
      ),
    );
    return MouseRegion(
      cursor: vertical
          ? SystemMouseCursors.resizeLeftRight
          : SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: vertical
            ? (details) => onDelta(details.delta.dx)
            : null,
        onVerticalDragUpdate: vertical
            ? null
            : (details) => onDelta(details.delta.dy),
        onHorizontalDragEnd: vertical ? (_) => onDragEnd() : null,
        onVerticalDragEnd: vertical ? null : (_) => onDragEnd(),
        onHorizontalDragCancel: vertical ? onDragEnd : null,
        onVerticalDragCancel: vertical ? null : onDragEnd,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: vertical ? extent : double.infinity,
            height: vertical ? double.infinity : extent,
            child: ColoredBox(
              color: context.surface,
              child: Center(child: grip),
            ),
          ),
        ),
      ),
    );
  }
}
