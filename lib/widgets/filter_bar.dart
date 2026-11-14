import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Responsive filter toolbar shared by the Blood Bank, Inventory and User
/// management screens.
///
/// A bare [Wrap] of fixed-width fields left ragged rows: the search sat beside
/// one dropdown, the remaining fields dropped to the next line at their own
/// widths, and the last filter stranded alone. This lays the search out on its
/// own line and the filters on an evenly divided grid, so every row has the
/// same rhythm at every window width.
class TabangFilterBar extends StatelessWidget {
  const TabangFilterBar({
    super.key,
    this.search,
    this.filters = const [],
    this.trailing,
    this.minFilterWidth = 165,
    this.maxFilterWidth = 220,
    this.gap = TabangSpace.md,
  });

  /// Search field (or any full-width lead control).
  final Widget? search;

  /// Dropdowns and other filters, distributed evenly.
  final List<Widget> filters;

  /// Optional action at the right of the search row (for example “Clear”).
  final Widget? trailing;

  /// Narrowest a filter cell may become before the grid drops a column.
  final double minFilterWidth;

  /// Widest a filter cell may grow; keeps two filters from becoming huge
  /// full-width dropdowns on a desktop window.
  final double maxFilterWidth;

  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = filters.isEmpty
            ? 0
            : math.max(
                1,
                math.min(
                  filters.length,
                  (width + gap) ~/ (minFilterWidth + gap),
                ),
              );
        final cellWidth = columns == 0
            ? 0.0
            : math.min(maxFilterWidth, (width - gap * (columns - 1)) / columns);

        final rows = <Widget>[];
        for (var start = 0; start < filters.length; start += columns) {
          final end = math.min(start + columns, filters.length);
          rows.add(
            Row(
              children: [
                for (var index = 0; index < columns; index++) ...[
                  if (index > 0) SizedBox(width: gap),
                  SizedBox(
                    width: cellWidth,
                    child: index < end - start
                        ? filters[start + index]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (search != null || trailing != null)
              Row(
                children: [
                  if (search != null) Expanded(child: search!),
                  if (search != null && trailing != null)
                    const SizedBox(width: TabangSpace.sm),
                  if (trailing != null) ...[
                    // With no search field the trailing action starts on the
                    // left, which put a lone guide button above the first
                    // dropdown instead of at the end of the toolbar. Push it
                    // to the right edge so every filter bar reads the same.
                    if (search == null) const Spacer(),
                    trailing!,
                  ],
                ],
              ),
            if (search != null && filters.isNotEmpty) SizedBox(height: gap),
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) SizedBox(height: gap),
              rows[index],
            ],
          ],
        );
      },
    );
  }
}
