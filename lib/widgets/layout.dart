import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared responsive breakpoints.
///
/// The paper's users are community members on whatever phone or tablet they
/// own, so every surface has to survive a 320–430 logical-pixel portrait
/// width and a landscape tablet. These cutoffs are deliberately coarse:
///
///  * [phone]: under 600 — one column, stacked panes, 16 px page padding.
///  * [tablet]: 600–1024 — two panes where useful, denser grids.
///  * [desktop]: 1024 and up — the classic side-by-side layouts.
class TabangBreakpoints {
  const TabangBreakpoints._();

  static const double phone = 600;
  static const double tablet = 1024;

  /// Below this width the sidebar becomes a bottom navigation bar. This is the
  /// same 1024 px line as [tablet]: anything that Desktop Chrome would open
  /// maximised on gets the persistent sidebar the desktop layout expects,
  /// while tablets and split windows keep the bottom bar.
  static const double navigationRail = 1024;
}

extension TabangLayout on BuildContext {
  double get width => MediaQuery.sizeOf(this).width;

  bool get isPhone => width < TabangBreakpoints.phone;

  bool get isTablet =>
      width >= TabangBreakpoints.phone && width < TabangBreakpoints.tablet;

  bool get isDesktop => width >= TabangBreakpoints.tablet;

  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;

  /// Page padding that thins out on phones so content keeps its width.
  EdgeInsets get pagePadding => EdgeInsets.all(isPhone ? 16.0 : TabangSpace.xl);

  /// A content column that stops growing on very wide monitors.
  double get readableMaxWidth => 1200;
}
