import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/eligibility.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/digos_vector_map.dart';
import '../../widgets/illustrations.dart';
import '../../widgets/layout.dart';
import '../../widgets/photo.dart';

/// Find Donor: Digos City vector map plus the donor directory.
///
/// The map itself is the standalone `digos_barangay_map` implementation
/// ([DigosVectorMap]): OpenStreetMap tiles behind an inverse city mask, with
/// the barangay topology from `lib/core/digos_geodata.dart`. TABANG layers —
/// donor-density fills, selection, drive pins and labels — are drawn locally,
/// so the map still reads offline. The palette was re-coloured from the
/// project's green/teal scheme to the app's crimson, maroon and gold set.
///
/// Tapping a barangay filters the donor list; tapping a drive pin opens that
/// barangay's drives.
class FindDonorPage extends StatefulWidget {
  const FindDonorPage({
    super.key,
    required this.user,
    this.onOpenRequests,
    this.onOpenChat,
    this.onOpenDiscover,
  });

  /// Jumps to Discover, where the drive cards and the visit planner live.
  final VoidCallback? onOpenDiscover;

  final AppUser user;

  /// Shell-level navigation hooks. The map never pushes another shell page
  /// directly, so the bottom bar and rail keep their active destination in sync.
  final VoidCallback? onOpenRequests;
  final VoidCallback? onOpenChat;

  @override
  State<FindDonorPage> createState() => _FindDonorPageState();
}

class _FindDonorPageState extends State<FindDonorPage> {
  final TabangRepository _repo = TabangRepository.instance;

  /// Drives the map camera; the page owns it so its buttons can zoom and
  /// re-frame the city.
  final MapController _mapController = MapController();

  Map<String, int> _donorCounts = {};

  BloodType? _bloodType;
  String? _selectedBarangay;
  String _query = '';
  bool _donorsCollapsed = false;

  /// The map starts light even when the app is in dark mode. Cartography is
  /// easier to read on a light base, and the checklist explicitly asks for a
  /// light default. The toggle lets a dark-mode user dim it without changing
  /// the whole application theme.
  bool _mapDark = false;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_refresh);
    _refreshCounts();
  }

  @override
  void dispose() {
    _repo.removeListener(_refresh);
    _mapController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    _refreshCounts();
    setState(() {});
  }

  void _refreshCounts() {
    _donorCounts = _repo.donorCountsByBarangay(bloodType: _bloodType);
  }

  List<AppUser> get _visibleDonors {
    return _repo.findDonors(
      bloodType: _bloodType,
      barangay: _selectedBarangay,
    ).where((donor) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return donor.alias.toLowerCase().contains(q) ||
          (donor.shareBarangay &&
              donor.barangay.toLowerCase().contains(q)) ||
          (donor.bloodType?.label.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<BloodDrive> _drivesIn(String barangay) => _repo.drives
      .where((d) => d.barangay == barangay && d.status != 'Completed')
      .toList(growable: false);

  /// Drives at a barangay pin: the map's route into the drive details.
  void _showDriveSheet(String barangay) {
    final drives = _drivesIn(barangay);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(TabangRadius.lg)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: context.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Blood drives · $barangay',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: context.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Walk in or book a slot with the chapter. Bring a valid ID.',
                style: TextStyle(fontSize: 12.5, color: context.textMuted),
              ),
              const SizedBox(height: TabangSpace.md),
              if (drives.isEmpty)
                Text(
                  'No active drive is scheduled here right now.',
                  style: TextStyle(fontSize: 13, color: context.textMuted),
                )
              else
                for (final drive in drives)
                  Padding(
                    padding: const EdgeInsets.only(bottom: TabangSpace.sm),
                    child: SurfaceCard(
                      padding: const EdgeInsets.all(TabangSpace.md),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showDriveDetails(drive);
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.place,
                            size: 18,
                            color: TabangColors.crimson,
                          ),
                          const SizedBox(width: TabangSpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  drive.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${drive.venue} · '
                                  '${formatDateTime(drive.startsAt)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: context.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
              if (widget.onOpenDiscover != null) ...[
                const SizedBox(height: TabangSpace.xs),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      widget.onOpenDiscover!.call();
                    },
                    icon: const Icon(Icons.explore_outlined, size: 16),
                    label: const Text('See all drives in Discover'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Drive details mirrored from the Discover card, reachable from the pin.
  void _showDriveDetails(BloodDrive drive) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(drive.title),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _driveDetail(dialogContext, 'Venue', drive.venue),
              _driveDetail(dialogContext, 'Barangay', drive.barangay),
              _driveDetail(
                dialogContext,
                'Starts',
                formatDateTime(drive.startsAt),
              ),
              _driveDetail(
                dialogContext,
                'Ends',
                formatDateTime(drive.endsAt),
              ),
              _driveDetail(
                dialogContext,
                'Expected donors',
                '${drive.expectedDonors}',
              ),
              _driveDetail(dialogContext, 'Status', drive.status),
              const SizedBox(height: 6),
              Text(
                'Walk-ins are welcome while slots last. Chapter staff screen '
                'every donor on site; bringing a valid ID speeds up the '
                'interview.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: dialogContext.textMuted,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (widget.onOpenDiscover != null)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                widget.onOpenDiscover!.call();
              },
              icon: const Icon(Icons.explore_outlined, size: 16),
              label: const Text('Open in Discover'),
            ),
        ],
      ),
    );
  }

  Widget _driveDetail(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: context.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Zoom by whole steps around the current camera centre.
  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(
      camera.center,
      (camera.zoom + delta).clamp(9.5, 18.0),
    );
  }

  /// The map is always north-up and cannot rotate, so the compass control
  /// re-frames the whole city rather than re-centring an arbitrary zoom.
  void _resetNorth() {
    DigosVectorMap.fitCity(_mapController);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('North up · showing all 26 barangays')),
    );
  }

  Map<String, int> get _driveCounts {
    final counts = <String, int>{};
    for (final drive in _repo.drives) {
      if (drive.status == 'Completed') continue;
      counts.update(drive.barangay, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Only phones stack the map above the donor list. A 760 px window has
        // enough room for a 430 px map plus the 330 px donor pane, and keeping
        // them side by side is what makes desktop labels readable.
        final narrow = constraints.maxWidth < 760;
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        if (narrow) {
          final mapHeight = _donorsCollapsed
              ? math.max(200.0, height - 46)
              : math.max(220.0, height * 0.52);
          return Column(
            children: [
              SizedBox(
                height: mapHeight,
                width: width,
                child: _buildMapPane(context, compact: true),
              ),
              if (_donorsCollapsed)
                _buildCollapsedDonorBar(context)
              else ...[
                Divider(height: 1, color: context.border),
                Expanded(child: _buildDonorPane(context, compact: true)),
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _buildMapPane(context, compact: false)),
            if (!_donorsCollapsed)
              Container(
                width: 330,
                decoration: BoxDecoration(
                  color: context.surface,
                  border: Border(left: BorderSide(color: context.border)),
                ),
                child: _buildDonorPane(context, compact: false),
              ),
          ],
        );
      },
    );
  }

  /// Tap bar that brings the donor list back on a phone.
  Widget _buildCollapsedDonorBar(BuildContext context) {
    final donors = _visibleDonors;
    return Material(
      color: context.surface,
      child: InkWell(
        onTap: () => setState(() => _donorsCollapsed = false),
        child: Container(
          height: 46,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: TabangSpace.lg),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.border)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.people_outline,
                size: 16,
                color: TabangColors.crimson,
              ),
              const SizedBox(width: 8),
              // Flexible label: at 320–390 px, or when the platform falls back
              // to a wider font, the title ellipsizes instead of pushing the
              // "Show list" affordance off the bar.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Available donors',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    StatusPill(
                      '${donors.length}',
                      tone: Tone.brand,
                      dense: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Show list',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textMuted,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_up,
                size: 22,
                color: TabangColors.crimson,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapPane(BuildContext context, {required bool compact}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // The Digos vector map (OSM tiles behind an inverse city mask,
            // with all TABANG layers drawn locally).
            Positioned.fill(
              child: DigosVectorMap(
                controller: _mapController,
                donorCounts: _donorCounts,
                driveCounts: _driveCounts,
                selectedBarangay: _selectedBarangay,
                mapDark: _mapDark,
                onSelectBarangay: (name) =>
                    setState(() => _selectedBarangay = name),
                onDriveTap: _showDriveSheet,
              ),
            ),

            // Title + blood type filter.
            //
            // `left` AND `right` must both be set: a Positioned with only one
            // horizontal edge gives its child unbounded width, and a
            // horizontal ListView with unbounded width fails layout, which
            // takes the whole page's render tree down with it.
            Positioned(
              top: TabangSpace.md,
              left: TabangSpace.md,
              right: TabangSpace.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header format mirrors the approved simplified vector map:
                  // eyebrow, map title, one-line description and a format tag.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: SurfaceCard(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'DAVAO DEL SUR · PHILIPPINES',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                      color: context.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Digos City Barangay Map',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                      color: context.textColor,
                                    ),
                                  ),
                                  if (!compact) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'A simplified, interactive map of local '
                                      'areas and infrastructure',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: context.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: TabangSpace.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: context.isDark
                                    ? const Color(0xFF3A1917)
                                    : TabangColors.crimsonSoft,
                                borderRadius:
                                    BorderRadius.circular(TabangRadius.pill),
                                border: Border.all(
                                  color: TabangColors.crimson
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: const Text(
                                '2D VECTOR MAP',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: TabangColors.crimsonDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_selectedBarangay != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SurfaceCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TabangSpace.md,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.place,
                              size: 15,
                              color: TabangColors.crimson,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _selectedBarangay!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: context.textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_donorCounts[_selectedBarangay] ?? 0} donor'
                              '${(_donorCounts[_selectedBarangay] ?? 0) == 1 ? '' : 's'}'
                              ' · ${_drivesIn(_selectedBarangay!).length} '
                              'drive'
                              '${_drivesIn(_selectedBarangay!).length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.textMuted,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () =>
                                  setState(() => _selectedBarangay = null),
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
                  const SizedBox(height: 6),
                  // Scrollable so every blood type is reachable on a phone,
                  // now with a bounded width from the Positioned above.
                  // The chip row stops short of the floating control stack.
                  // Padding *inside* the ListView only extends the scrollable
                  // content, so the last chips still painted underneath the
                  // buttons; shrinking the viewport is what actually keeps
                  // them clear.
                  SizedBox(
                    height: 34,
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 52),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _typeChip(context, null, 'ALL'),
                          ...BloodType.values.map(
                            (t) => _typeChip(context, t, t.label),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Zoom, compass, map-style and donor-pane controls.
            Positioned(
              top: TabangSpace.md,
              right: TabangSpace.md,
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
                        ),
                        const SizedBox(height: 6),
                        _mapButton(
                          context,
                          Icons.remove,
                          () => _zoomBy(-0.75),
                          tooltip: 'Zoom out',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // One reset control, not two. The map is always drawn
                  // north-up, so a compass is the honest affordance for
                  // "return to the full, north-up city".
                  _mapButton(
                    context,
                    Icons.explore_outlined,
                    _resetNorth,
                    tooltip: 'Compass · north up, show all 26 barangays',
                    accent: true,
                  ),
                  const SizedBox(height: 6),
                  _mapButton(
                    context,
                    _mapDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    () => setState(() => _mapDark = !_mapDark),
                    tooltip: _mapDark
                        ? 'Use light map'
                        : 'Use dark map',
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 12),
                    _mapButton(
                      context,
                      _donorsCollapsed
                          ? Icons.chevron_left
                          : Icons.chevron_right,
                      () => setState(
                        () => _donorsCollapsed = !_donorsCollapsed,
                      ),
                      tooltip: _donorsCollapsed
                          ? 'Show donor list'
                          : 'Hide donor list',
                    ),
                  ],
                ],
              ),
            ),

            // The legend is essential on every viewport. Compact mode used to
            // hide it entirely, leaving phone users with coloured shapes and
            // no key; it is now a single compact row.
            Positioned(
              left: TabangSpace.md,
              bottom: TabangSpace.md,
              right: compact ? TabangSpace.md : null,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: _buildLegend(context, compact: compact),
              ),
            ),

            // Tile attribution, required by the OpenStreetMap tile policy.
            // Compact maps put the legend across the whole bottom edge, so the
            // credit sits above it there.
            Positioned(
              right: TabangSpace.md,
              bottom: compact ? 66 : 8,
              child: const DigosMapAttribution(),
            ),
          ],
        );
      },
    );
  }

  Color _fillFor(int count, bool selected) =>
      digosHeatColor(count, dark: _mapDark, selected: selected);

  Widget _typeChip(BuildContext context, BloodType? type, String label) {
    final selected = _bloodType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(TabangRadius.pill),
        onTap: () {
          setState(() {
            _bloodType = type;
            _refreshCounts();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? TabangColors.crimson : context.surface,
            borderRadius: BorderRadius.circular(TabangRadius.pill),
            border: Border.all(
              color: selected ? TabangColors.crimson : context.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : context.textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _mapButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap, {
    String? tooltip,
    bool accent = false,
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
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TabangRadius.sm),
            border: Border.all(
              color: accent ? TabangColors.crimson : context.border,
            ),
          ),
          child: Icon(
            icon,
            size: 19,
            color: accent ? Colors.white : context.textColor,
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }

  Widget _buildLegend(BuildContext context, {required bool compact}) {
    // Sum, not barangay count: three drives in Zone 1 is three active drives.
    final driveCount =
        _driveCounts.values.fold<int>(0, (total, count) => total + count);
    if (compact) {
      return SurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: TabangSpace.sm,
          vertical: 7,
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Donors',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: context.textColor,
              ),
            ),
            _legendSwatch(context, 0, '0', small: true),
            _legendSwatch(context, 1, '1–2', small: true),
            _legendSwatch(context, 4, '3–5', small: true),
            _legendSwatch(context, 7, '6+', small: true),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.place,
                  size: 14,
                  color: TabangColors.crimson,
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    '$driveCount drive${driveCount == 1 ? '' : 's'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: context.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SurfaceCard(
      padding: const EdgeInsets.all(TabangSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'MAP LAYERS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 7),
          _layerRow(context, DigosMapColors.cityBorder, 'Digos City boundary',
              lineWidth: 3),
          _layerRow(context, DigosMapColors.internalBorder,
              'Barangay boundaries',
              lineWidth: 2),
          const SizedBox(height: 6),
          Divider(height: 1, color: context.border),
          const SizedBox(height: 8),
          Text(
            'DONOR DENSITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 7),
          _legendRow(context, 0, 'No available donors'),
          _legendRow(context, 1, '1–2 donors'),
          _legendRow(context, 4, '3–5 donors'),
          _legendRow(context, 7, '6+ donors'),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.place,
                  size: 15,
                  color: TabangColors.crimson,
                ),
                const SizedBox(width: 4),
                Text(
                  '$driveCount active drive${driveCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendSwatch(
    BuildContext context,
    int count,
    String label, {
    bool small = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: small ? 12 : 15,
          height: small ? 12 : 15,
          decoration: BoxDecoration(
            color: _fillFor(count, false),
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
          label,
          style: TextStyle(
            fontSize: small ? 11.5 : 12.5,
            color: context.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _legendRow(BuildContext context, int count, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Stack(
        children: [
          _legendSwatch(context, count, label),
        ],
      ),
    );
  }

  /// A legend row for the base map layers: a coloured line for the city and
  /// barangay boundaries, or a filled box for anything added later.
  Widget _layerRow(
    BuildContext context,
    Color color,
    String label, {
    bool bordered = false,
    double? lineWidth,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lineWidth != null)
            Container(
              width: 20,
              height: lineWidth,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(lineWidth / 2),
              ),
            )
          else
            Container(
              width: 20,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                border: bordered
                    ? Border.all(color: context.border)
                    : Border.all(color: color.withValues(alpha: 0.6)),
              ),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorPane(BuildContext context, {required bool compact}) {
    final donors = _visibleDonors;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(TabangSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedBarangay == null
                          ? 'Available donors'
                          : 'Available donors in $_selectedBarangay',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusPill('${donors.length}', tone: Tone.brand, dense: true),
                  if (_selectedBarangay != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => setState(() => _selectedBarangay = null),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: context.textMuted,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Hide donor list',
                    child: InkWell(
                      onTap: () => setState(() => _donorsCollapsed = true),
                      borderRadius: BorderRadius.circular(TabangRadius.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.surfaceAlt,
                          borderRadius:
                              BorderRadius.circular(TabangRadius.pill),
                          border: Border.all(color: context.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Hide',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.textMuted,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: context.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TabangSpace.sm),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Search alias or barangay',
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 16),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: context.border),
        Expanded(
          child: donors.isEmpty
              ? const EmptyState(
                  art: TabangArt.donors,
                  title: 'No eligible donors',
                  message:
                      'No donor matches this filter right now. Donors in '
                      'cooldown are hidden automatically.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(TabangSpace.md),
                  itemCount: donors.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: TabangSpace.sm),
                  itemBuilder: (context, i) =>
                      _buildDonorCard(context, donors[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildDonorCard(BuildContext context, AppUser donor) {
    final eligibility = EligibilityEngine.evaluate(donor);

    return SurfaceCard(
      padding: const EdgeInsets.all(TabangSpace.lg),
      onTap: donor.shareBarangay
          ? () => setState(() => _selectedBarangay = donor.barangay)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: TabangPhoto(
                    donor.photoAsset,
                    semanticLabel: '${donor.alias} profile illustration',
                    creditLabel: donor.alias,
                    fallbackIcon: Icons.person_outline,
                    fallbackIconSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: TabangSpace.sm),
              BloodTypeChip(donor.bloodType ?? BloodType.oPos, size: 30),
              const SizedBox(width: TabangSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donor.alias,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                    Text(
                      donor.shareBarangay ? donor.barangay : 'Barangay hidden',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                eligibility.isEligible ? 'Eligible' : 'Cooldown',
                tone: toneForEligibility(eligibility),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.sm),
          Row(
            children: [
              Icon(Icons.favorite_border, size: 14, color: context.textMuted),
              const SizedBox(width: 4),
              Text(
                '${donor.totalDonations} donations',
                style: TextStyle(fontSize: 12.5, color: context.textMuted),
              ),
              const SizedBox(width: TabangSpace.md),
              Icon(Icons.schedule, size: 14, color: context.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  donor.lastDonationDate == null
                      ? 'First-time donor'
                      : 'Last ${formatDate(donor.lastDonationDate!)}',
                  style: TextStyle(fontSize: 12.5, color: context.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (widget.onOpenRequests != null)
                TextButton.icon(
                  onPressed: widget.onOpenRequests,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.assignment_outlined, size: 16),
                  label: const Text(
                    'Requests',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              TextButton.icon(
                onPressed: donor.id == widget.user.id
                    ? null
                    : () => _contactDonor(context, donor),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.forum_outlined, size: 16),
                label: const Text(
                  'Message',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _contactDonor(BuildContext context, AppUser donor) async {
    final controller = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Message ${donor.alias}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat before choosing a donor. Real names stay hidden until both '
              'of you accept a reveal.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: context.textMuted,
              ),
            ),
            const SizedBox(height: TabangSpace.md),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Introduce yourself and ask about availability…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.send_outlined, size: 16),
            label: const Text('Send'),
          ),
        ],
      ),
    );

    if (send != true || !context.mounted) return;
    final thread = _repo.startConversation(
      initiatorId: widget.user.id,
      otherId: donor.id,
      firstMessage: controller.text,
    );
    controller.dispose();
    if (thread == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This conversation is unavailable right now.'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conversation with ${donor.alias} is ready.'),
        action: widget.onOpenChat == null
            ? null
            : SnackBarAction(
                label: 'Open',
                onPressed: widget.onOpenChat!,
              ),
      ),
    );
  }
}

