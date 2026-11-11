import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../theme.dart';
import 'common.dart';
import 'digos_vector_map.dart';

/// The shared map surface behind both Find Donor and the staff Operations map.
///
/// One widget owns every piece of map chrome — the title card, the selected
/// barangay card, the filter chips, the zoom/fit/style/layers stack, the list
/// chevron, the legend and the attribution — so the community map and the
/// staff map cannot drift apart. Callers only supply their data, their chips
/// and their legend content.
class DigosMapPane extends StatefulWidget {
  const DigosMapPane({
    super.key,
    required this.controller,
    required this.donorCounts,
    required this.drives,
    required this.selectedBarangay,
    required this.mapDark,
    required this.onSelectBarangay,
    required this.onDriveTap,
    required this.onFacilityTap,
    required this.onToggleMapDark,
    required this.legend,
    required this.compact,
    this.requestCounts,
    this.title = 'Digos City Barangay Map',
    this.chips = const [],
    this.selectedSummary,
    this.onClearSelection,
    this.listCollapsed = false,
    this.onToggleList,
    this.listLabel = 'list',
    this.listIcon = Icons.people_outline,
  });

  final MapController controller;

  /// Canonical barangay name → eligible donors.
  final Map<String, int> donorCounts;

  /// Canonical barangay name → open requests. When supplied, the fill layer
  /// switches from the donor-density ramp to the staff request ramp; the
  /// caller supplies the matching legend.
  final Map<String, int>? requestCounts;

  final List<DigosDriveMarker> drives;
  final String? selectedBarangay;

  /// Title card text over the map.
  final String title;

  /// Extra explanation shown inside the selected-barangay card.
  final String? selectedSummary;

  final bool mapDark;
  final ValueChanged<String?> onSelectBarangay;
  final ValueChanged<String> onDriveTap;
  final ValueChanged<DigosFacilityPin> onFacilityTap;
  final VoidCallback onToggleMapDark;

  /// Legend card at the bottom-left, built by the page.
  final Widget legend;

  /// Filter chips for the horizontal row over the map.
  final List<Widget> chips;

  final bool compact;
  final VoidCallback? onClearSelection;

  /// True when the side list is collapsed ("map only"); the chevron flips
  /// back. On phones the chevron only appears in that state so it is never a
  /// trap.
  final bool listCollapsed;
  final VoidCallback? onToggleList;

  /// What the chevron is collapsing, for its tooltip ("donor list").
  final String listLabel;

  /// Icon drawn at the head of the restore bar shown while [listCollapsed].
  final IconData listIcon;

  @override
  State<DigosMapPane> createState() => _DigosMapPaneState();
}

class _DigosMapPaneState extends State<DigosMapPane> {
  static const Duration _fadeDuration = Duration(milliseconds: 380);

  /// Overlay visibility. Panels fade while the map is being touched and can be
  /// hidden entirely with the layers button, so the map can be read without
  /// chrome in the way.
  bool _overlaysHidden = false;

  /// Gesture state lives in a notifier, not page state: rebuilding the page on
  /// every pan frame also rebuilt the map itself, which made the fade stutter.
  final ValueNotifier<bool> _interacting = ValueNotifier<bool>(false);
  Timer? _interactionTimer;

  /// Horizontal scroll for the blood-type chips. A dedicated controller lets
  /// the row carry a visible scrollbar; Material only adds scrollbars to
  /// vertical lists automatically.
  final ScrollController _chipScroll = ScrollController();

  double _opacityFor(bool interacting, {required bool control}) {
    if (_overlaysHidden) return 0;
    return interacting ? (control ? 0.7 : 0.15) : 1;
  }

  void _startInteraction() {
    _interactionTimer?.cancel();
    _interacting.value = true;
  }

  void _endInteraction() {
    _interactionTimer?.cancel();
    _interactionTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _interacting.value = false;
    });
  }

  @override
  void dispose() {
    _interactionTimer?.cancel();
    _interacting.dispose();
    _chipScroll.dispose();
    super.dispose();
  }

  /// Zoom by whole steps around the current camera centre.
  void _zoomBy(double delta) {
    final camera = widget.controller.camera;
    // Same limits as the map widget: 10.5 frames the whole city and 18 is as
    // far as the OSM base has detail worth showing.
    widget.controller.move(
      camera.center,
      (camera.zoom + delta).clamp(10.5, 18),
    );
  }

  /// The map is always north-up and cannot rotate, so the fit control
  /// re-frames the whole city rather than re-centring an arbitrary zoom.
  void _fitCity() {
    DigosVectorMap.fitCity(widget.controller);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitted to the city · all 26 barangays')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: DigosVectorMap(
                  controller: widget.controller,
                  donorCounts: widget.donorCounts,
                  requestCounts: widget.requestCounts,
                  drives: widget.drives,
                  selectedBarangay: widget.selectedBarangay,
                  mapDark: widget.mapDark,
                  onSelectBarangay: widget.onSelectBarangay,
                  onDriveTap: widget.onDriveTap,
                  onFacilityTap: widget.onFacilityTap,
                  onInteractionStart: _startInteraction,
                  onInteractionEnd: _endInteraction,
                ),
              ),
            ),

            // Title + filter chips.
            //
            // `left` AND `right` must both be set: a Positioned with only one
            // horizontal edge gives its child unbounded width, and a
            // horizontal ListView with unbounded width fails layout.
            Positioned(
              top: TabangSpace.md,
              left: TabangSpace.md,
              right: TabangSpace.md,
              child: IgnorePointer(
                ignoring: _overlaysHidden,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _interacting,
                  builder: (context, interacting, child) => AnimatedOpacity(
                    opacity: _opacityFor(interacting, control: false),
                    duration: _fadeDuration,
                    curve: Curves.easeInOut,
                    child: child,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!compact)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SurfaceCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.map_outlined,
                                  size: 15,
                                  color: TabangColors.crimson,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                      color: context.textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (widget.selectedBarangay != null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SurfaceCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.place,
                                  size: 14,
                                  color: TabangColors.crimson,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    widget.selectedBarangay!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: context.textColor,
                                    ),
                                  ),
                                ),
                                if (widget.selectedSummary != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.selectedSummary!,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: context.textMuted,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 4),
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    widget.onSelectBarangay(null);
                                    widget.onClearSelection?.call();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: context.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (widget.chips.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        // Scrollable so every filter is reachable on a phone,
                        // with a bounded width from the Positioned above. The
                        // chip row stops short of the floating control stack.
                        // Material only auto-adds scrollbars to vertical lists,
                        // so this row carries its own: a thin track under the
                        // chips is the only cue that more types are off-screen.
                        SizedBox(
                          height: 36,
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 46),
                            child: Scrollbar(
                              key: const ValueKey('mapChipScrollbar'),
                              controller: _chipScroll,
                              thumbVisibility: true,
                              scrollbarOrientation: ScrollbarOrientation.bottom,
                              thickness: 3,
                              radius: const Radius.circular(3),
                              child: ListView(
                                controller: _chipScroll,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(bottom: 6),
                                children: widget.chips,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Zoom, fit, map-style, layers and list controls.
            Positioned(
              top: TabangSpace.md,
              right: TabangSpace.md,
              child: ValueListenableBuilder<bool>(
                valueListenable: _interacting,
                builder: (context, interacting, child) => AnimatedOpacity(
                  opacity: _opacityFor(interacting, control: true),
                  duration: _fadeDuration,
                  curve: Curves.easeInOut,
                  child: child,
                ),
                child: Column(
                  children: [
                    SurfaceCard(
                      padding: const EdgeInsets.all(3),
                      child: Column(
                        children: [
                          _mapButton(
                            context,
                            Icons.add,
                            () => _zoomBy(0.75),
                            tooltip: 'Zoom in',
                            size: compact ? 30 : 36,
                          ),
                          SizedBox(height: compact ? 4 : 6),
                          _mapButton(
                            context,
                            Icons.remove,
                            () => _zoomBy(-0.75),
                            tooltip: 'Zoom out',
                            size: compact ? 30 : 36,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 8),
                    // One fit control, not two. The map is always drawn
                    // north-up, so "zoom to fill the pane with the whole city"
                    // is the useful action; the corner-bracket icon says that
                    // without implying a rotation compass.
                    _mapButton(
                      context,
                      Icons.fit_screen,
                      _fitCity,
                      tooltip: 'Fit city · show all 26 barangays',
                      accent: true,
                      size: compact ? 30 : 36,
                    ),
                    // The light/dark switch is desktop-only: on a phone the
                    // extra button pushed the stack into the legend.
                    if (!compact) ...[
                      const SizedBox(height: 6),
                      _mapButton(
                        context,
                        widget.mapDark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        widget.onToggleMapDark,
                        tooltip: widget.mapDark
                            ? 'Use light map'
                            : 'Use dark map',
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(height: compact ? 4 : 0),
                    // Hides every map panel for an unobstructed view.
                    _mapButton(
                      context,
                      _overlaysHidden ? Icons.layers : Icons.layers_outlined,
                      () => setState(() => _overlaysHidden = !_overlaysHidden),
                      tooltip: _overlaysHidden
                          ? 'Show map panels'
                          : 'Hide map panels',
                      size: compact ? 30 : 36,
                    ),
                  ],
                ),
              ),
            ),

            // Always-visible restore control. It lives outside the faded
            // control stack, otherwise hiding the panels also hid the button
            // that brings them back.
            if (_overlaysHidden)
              Positioned(
                top: TabangSpace.md,
                right: TabangSpace.md,
                child: _mapButton(
                  context,
                  Icons.layers,
                  () => setState(() => _overlaysHidden = false),
                  tooltip: 'Show map panels',
                  accent: true,
                ),
              ),

            // The legend fades with the rest of the map panels while the map
            // is being touched.
            Positioned(
              left: TabangSpace.md,
              bottom: TabangSpace.md,
              // Compact maps keep the bottom-right corner free for the scale
              // bar and the required OSM credit.
              right: compact ? 140 : null,
              child: IgnorePointer(
                ignoring: _overlaysHidden,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _interacting,
                  builder: (context, interacting, child) => AnimatedOpacity(
                    opacity: _opacityFor(interacting, control: false),
                    duration: _fadeDuration,
                    curve: Curves.easeInOut,
                    child: child,
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: widget.legend,
                  ),
                ),
              ),
            ),

            // Tile attribution, required by the OpenStreetMap tile policy.
            // Pinned to the very bottom edge, below the scale bar, so it reads
            // as a map credit rather than another panel.
            Positioned(
              right: 8,
              bottom: 4,
              child: IgnorePointer(
                ignoring: _overlaysHidden,
                child: AnimatedOpacity(
                  opacity: _overlaysHidden ? 0 : 1,
                  duration: const Duration(milliseconds: 240),
                  child: const DigosMapAttribution(),
                ),
              ),
            ),

            // Restore bar while the side list is collapsed: a single action
            // that names the hidden list ("Show donor list") and brings it
            // back with one tap. The list's own heading and count are not
            // repeated here, which read as a duplicated title next to the
            // button.
            if (widget.listCollapsed &&
                widget.onToggleList != null &&
                !_overlaysHidden)
              Positioned(
                // On a wide map the legend hugs the bottom-left and the tile
                // credit the bottom-right, so the restore bar keeps clear of
                // both instead of covering them.
                left: compact ? TabangSpace.md : 180,
                right: compact ? TabangSpace.md : 180,
                bottom: compact ? 62 : TabangSpace.md,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Tooltip(
                    message: 'Show ${widget.listLabel}',
                    child: Material(
                      color: context.surface.withValues(alpha: 0.97),
                      borderRadius: BorderRadius.circular(TabangRadius.pill),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(TabangRadius.pill),
                        onTap: widget.onToggleList,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 420),
                          padding: const EdgeInsets.fromLTRB(12, 8, 9, 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              TabangRadius.pill,
                            ),
                            border: Border.all(color: context.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.listIcon,
                                size: 15,
                                color: TabangColors.crimson,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Show ${widget.listLabel}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.textColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_up,
                                size: 17,
                                color: TabangColors.crimson,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _mapButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap, {
    String? tooltip,
    bool accent = false,
    double size = 36,
  }) {
    final button = Material(
      color: accent
          ? TabangColors.crimson
          : context.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(TabangRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(TabangRadius.sm),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TabangRadius.sm),
            border: Border.all(
              color: accent ? TabangColors.crimson : context.border,
            ),
          ),
          child: Icon(
            icon,
            size: size < 36 ? 15 : 17,
            color: accent ? Colors.white : context.textColor,
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }
}

/// One coloured swatch and its label inside a map legend.
class DigosLegendEntry {
  const DigosLegendEntry({required this.color, required this.label});

  final Color color;
  final String label;
}

/// The map legend card, shared by Find Donor and the staff Operations map.
///
/// [compact] renders a single wrapped row for phones; otherwise the entries
/// stack under the title with an optional [footer] (a drive count or the
/// chapter pin).
class DigosLegendPanel extends StatelessWidget {
  const DigosLegendPanel({
    super.key,
    required this.title,
    required this.entries,
    this.header,
    this.footer,
    this.compact = false,
  });

  final String title;
  final List<DigosLegendEntry> entries;

  /// Optional control shown under the title, such as the staff layer switch.
  final Widget? header;
  final Widget? footer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Wrap(
          spacing: 8,
          runSpacing: 3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: context.textColor,
                ),
              ),
            if (header != null) header!,
            for (final entry in entries) _swatch(context, entry, small: true),
            if (footer != null) footer!,
          ],
        ),
      );
    }

    return SurfaceCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: context.textMuted,
              ),
            ),
          ],
          if (header != null) ...[
            if (title.isNotEmpty) const SizedBox(height: 4),
            header!,
          ],
          if (title.isNotEmpty || header != null) const SizedBox(height: 5),
          for (final entry in entries) _swatch(context, entry),
          if (footer != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: footer!),
        ],
      ),
    );
  }

  Widget _swatch(
    BuildContext context,
    DigosLegendEntry entry, {
    bool small = false,
  }) {
    return Padding(
      padding: small ? EdgeInsets.zero : const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: small ? 12 : 15,
            height: small ? 12 : 15,
            decoration: BoxDecoration(
              color: entry.color,
              border: Border.all(
                color: context.isDark
                    ? Colors.white.withValues(alpha: 0.28)
                    : TabangColors.crimson.withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            entry.label,
            style: TextStyle(
              fontSize: small ? 11 : 11.5,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
