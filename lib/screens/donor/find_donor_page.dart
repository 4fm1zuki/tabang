import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/eligibility.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/digos_map_pane.dart';
import '../../widgets/digos_vector_map.dart';
import '../../widgets/illustrations.dart';
import '../../widgets/layout.dart';
import '../../widgets/map_split_handle.dart';
import '../../widgets/photo.dart';

/// How the map and donor directory share a screen.
///
/// The draggable divider between them snaps between three states: [mapOnly]
/// (the list steps aside and its restore bubble appears), [half] (the default
/// 50/50 split) and [hidden] (the map steps aside and the directory fills the
/// page).
enum _DonorMapMode { mapOnly, half, hidden }

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
    this.onOpenBloodBank,
  });

  /// Jumps to Discover, where the drive cards and the visit planner live.
  final VoidCallback? onOpenDiscover;

  /// Jumps to the Blood Bank tab; used by the PRC chapter pin.
  final VoidCallback? onOpenBloodBank;

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
  _DonorMapMode _mapMode = _DonorMapMode.half;

  /// Fraction of the phone's body height given to the map (0–1). The draggable
  /// divider updates it live; on release it snaps to 0, 0.52 or 1.
  double _mapFraction = 0.52;

  /// Width of the desktop donor panel. Dragging the vertical divider left
  /// shrinks it to zero (map only), showing the same restore bubble.
  double _panelWidth = _widePanelWidth;
  bool _draggingSplit = false;

  /// The map style follows the app's effective theme, so it darkens with the
  /// system as soon as the theme does. The style button sets a per-visit
  /// override; without one, [didChangeDependencies] re-syncs on every theme
  /// change.
  bool _mapDark = false;
  bool? _mapDarkOverride;

  /// Donor pane tab: 0 donors, 1 facilities, 2 drives.
  int _paneTab = 0;

  void _focusFacility(DigosFacilityPin pin) {
    // The pin is drawn in the map frame, so the camera must target the same
    // rebased point or "show on map" would centre half a kilometre away.
    _mapController.move(DigosVectorMap.toMapFrame(pin.point), 15);
  }

  void _focusBarangay(String canonical) {
    final point = DigosVectorMap.centroidOf(canonical);
    if (point == null) return;
    _mapController.move(point, 13.5);
  }

  /// Tapping a donor card takes the map to the barangay that donor is from,
  /// instead of only filtering/highlighting the list.
  void _focusDonor(AppUser donor) {
    setState(() {
      _selectedBarangay = donor.barangay;
      _mapMode = _DonorMapMode.half;
      _mapFraction = 0.52;
      _panelWidth = _widePanelWidth;
    });
    _focusBarangay(donor.barangay);
  }

  @override
  void initState() {
    super.initState();
    _repo.addListener(_refresh);
    _refreshCounts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapDark =
        _mapDarkOverride ?? (Theme.of(context).brightness == Brightness.dark);
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
    return _repo
        .findDonors(bloodType: _bloodType, barangay: _selectedBarangay)
        .where((donor) {
          // A donor is not a match for themselves: their own card had a
          // disabled Message button and inflated the available-donor count.
          if (donor.id == widget.user.id) return false;
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return donor.mapHandle.toLowerCase().contains(q) ||
              (donor.shareBarangay &&
                  donor.barangay.toLowerCase().contains(q)) ||
              (donor.bloodType?.label.toLowerCase().contains(q) ?? false);
        })
        .toList();
  }

  List<BloodDrive> _drivesIn(String barangay) => _repo.drives
      .where((d) => d.barangay == barangay && d.status != 'Completed')
      .toList(growable: false);

  /// Hospitals and the PRC chapter: what the pin is and where it sits.
  void _showFacilitySheet(DigosFacilityPin pin) {
    final isChapter = pin.kind == 'chapter';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TabangRadius.lg),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: context.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isChapter ? Icons.bloodtype : Icons.local_hospital,
                    size: 22,
                    color: isChapter ? TabangColors.crimson : TabangColors.info,
                  ),
                  const SizedBox(width: TabangSpace.sm),
                  Expanded(
                    child: Text(
                      pin.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: context.textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                pin.note,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: context.textMuted,
                ),
              ),
              const SizedBox(height: TabangSpace.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Close'),
                    ),
                  ),
                  if (isChapter && widget.onOpenBloodBank != null) ...[
                    const SizedBox(width: TabangSpace.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          widget.onOpenBloodBank!.call();
                        },
                        icon: const Icon(Icons.inventory_2_outlined, size: 16),
                        label: const Text('Open Blood Bank'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Drives at a barangay pin: the map's route into the drive details.
  void _showDriveSheet(String barangay) {
    final drives = _drivesIn(barangay);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TabangRadius.lg),
        ),
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
              _driveDetail(dialogContext, 'Ends', formatDateTime(drive.endsAt)),
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

  Map<String, int> get _driveCounts {
    final counts = <String, int>{};
    for (final drive in _repo.drives) {
      if (drive.status == 'Completed') continue;
      counts.update(drive.barangay, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// Active drives pinned at their venue coordinates. Seeds without
  /// coordinates fall back to the barangay centre.
  List<DigosDriveMarker> get _driveMarkers {
    final markers = <DigosDriveMarker>[];
    for (final drive in _repo.drives) {
      if (drive.status == 'Completed') continue;
      final barangay =
          DigosBarangays.canonical(drive.barangay) ?? drive.barangay;
      // Venue seeds are true OSM coordinates; centroids are already in the
      // hand-traced map frame. Rebase only the former so the marker sits on
      // its venue under the nudged raster.
      final point = (drive.lat != null && drive.lng != null)
          ? DigosVectorMap.toMapFrame(LatLng(drive.lat!, drive.lng!))
          : DigosVectorMap.centroidOf(barangay);
      if (point == null) continue;
      markers.add(
        DigosDriveMarker(title: drive.title, barangay: barangay, point: point),
      );
    }
    return markers;
  }

  /// One duration for every map/list transition, so the map switch, the list
  /// chevron and the bottom restore bar all move at the same pace.
  static const Duration _paneAnimation = Duration(milliseconds: 280);

  /// A panel that is animating away is laid out at least this tall and then
  /// clipped; reflowing it below its own header would overflow on every frame.
  static const double _minPaneLayoutHeight = 200;

  /// Width of the donor directory on a wide window.
  static const double _widePanelWidth = 330;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Only phones stack the map above the donor list. A 760 px window has
        // enough room for a 430 px map plus the 330 px donor pane, and keeping
        // them side by side is what makes desktop labels readable.
        final narrow = constraints.maxWidth < 760;
        return narrow
            ? _buildNarrowLayout(
                context,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              )
            : _buildWideLayout(context, width: constraints.maxWidth);
      },
    );
  }

  /// The map fraction that the narrow split snaps back to.
  static const double _halfFraction = 0.52;

  /// Phone arrangement: a draggable bar between the stacked map and directory.
  /// Pull it down to grow the map (the restore bubble appears at map-only);
  /// pull it up to grow the list. Releasing near the middle restores the
  /// normal half-and-half split.
  Widget _buildNarrowLayout(
    BuildContext context, {
    required double width,
    required double height,
  }) {
    final available = math.max(0.0, height - MapSplitHandle.extent);
    final mapTarget = switch (_mapMode) {
      _DonorMapMode.hidden => 0.0,
      _DonorMapMode.mapOnly => available,
      _DonorMapMode.half => math.min(
        available,
        math.max(220.0, available * _mapFraction),
      ),
    };
    return TweenAnimationBuilder<double>(
      // begin == end on the first build, so the page opens at the half split
      // without animating from zero. Later target changes animate from the
      // current height.
      tween: Tween<double>(begin: mapTarget, end: mapTarget),
      duration: _draggingSplit ? Duration.zero : _paneAnimation,
      curve: Curves.easeOutCubic,
      builder: (context, animatedHeight, _) {
        final mapHeight = animatedHeight.clamp(0.0, available);
        final listHeight = math.max(0.0, available - mapHeight);
        final layoutHeight = math.max(listHeight, _minPaneLayoutHeight);
        return Column(
          children: [
            if (mapHeight >= 1)
              SizedBox(
                width: width,
                height: mapHeight,
                // A map laid out at a sub-pixel height has no camera to fit;
                // the last sliver is invisible anyway.
                child: _buildMapPane(context, compact: true),
              ),
            MapSplitHandle(
              key: const ValueKey('mapSplitHandle'),
              vertical: false,
              tooltip: _mapMode == _DonorMapMode.mapOnly
                  ? 'Drag up to show the donor list'
                  : _mapMode == _DonorMapMode.hidden
                  ? 'Drag down to show the map'
                  : 'Drag to resize the map and donor list',
              onDelta: (delta) => _dragNarrowSplit(delta, available),
              onDragEnd: _endNarrowSplitDrag,
            ),
            Expanded(
              child: listHeight < 1
                  ? const SizedBox.shrink()
                  : ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: layoutHeight,
                        maxHeight: layoutHeight,
                        child: _buildDonorPane(context, compact: true),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _dragNarrowSplit(double delta, double available) {
    if (available <= 0) return;
    final next = (_mapFraction + delta / available).clamp(0.0, 1.0);
    setState(() {
      _draggingSplit = true;
      _mapFraction = next;
      if (next >= 0.985) {
        _mapMode = _DonorMapMode.mapOnly;
      } else if (next <= 0.015) {
        _mapMode = _DonorMapMode.hidden;
      } else {
        _mapMode = _DonorMapMode.half;
      }
    });
  }

  void _endNarrowSplitDrag() {
    if (!_draggingSplit) return;
    setState(() {
      _draggingSplit = false;
      if (_mapFraction >= 0.82) {
        _mapMode = _DonorMapMode.mapOnly;
        _mapFraction = 1;
      } else if (_mapFraction <= 0.25) {
        _mapMode = _DonorMapMode.hidden;
        _mapFraction = 0;
      } else {
        _mapMode = _DonorMapMode.half;
        _mapFraction = _halfFraction;
      }
    });
  }

  /// Wide arrangement. The divider is a vertical bar between the map and the
  /// directory; drag it left to shrink the panel to zero (map only), or right
  /// to widen it.
  Widget _buildWideLayout(BuildContext context, {required double width}) {
    final maxPanel = math.max(260.0, math.min(520.0, width * 0.55));
    final panelTarget = _mapMode == _DonorMapMode.mapOnly
        ? 0.0
        : _panelWidth.clamp(0.0, maxPanel);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: panelTarget, end: panelTarget),
      duration: _draggingSplit ? Duration.zero : _paneAnimation,
      curve: Curves.easeOutCubic,
      builder: (context, animatedWidth, _) {
        final panelWidth = animatedWidth.clamp(0.0, maxPanel);
        final contentWidth = math.max(panelWidth, _widePanelWidth);
        return Row(
          children: [
            // Kept in the same slot even at zero width: swapping between a
            // bare map and a Row would rebuild the map state and reset the
            // camera at the end of the animation.
            Expanded(child: _buildMapPane(context, compact: false)),
            MapSplitHandle(
              key: const ValueKey('mapSplitHandle'),
              vertical: true,
              tooltip: panelWidth < 1
                  ? 'Drag right to show the donor list'
                  : 'Drag to resize the map and donor list',
              onDelta: (delta) => _dragWideSplit(delta, maxPanel),
              onDragEnd: _endWideSplitDrag,
            ),
            SizedBox(
              width: panelWidth,
              child: panelWidth < 0.5
                  ? const SizedBox.shrink()
                  : ClipRect(
                      // The panel keeps its full width while the frame
                      // narrows, so its content slides out to the right rather
                      // than reflowing through every intermediate width.
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: _widePanelWidth,
                        maxWidth: contentWidth,
                        child: SizedBox(
                          width: contentWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.surface,
                              border: Border(
                                left: BorderSide(color: context.border),
                              ),
                            ),
                            child: _buildDonorPane(context, compact: false),
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

  void _dragWideSplit(double delta, double maxPanel) {
    // Dragging left (negative dx) grows the panel.
    final next = (_panelWidth - delta).clamp(0.0, maxPanel);
    setState(() {
      _draggingSplit = true;
      _panelWidth = next;
      _mapMode = next < 0.5 ? _DonorMapMode.mapOnly : _DonorMapMode.half;
    });
  }

  void _endWideSplitDrag() {
    if (!_draggingSplit) return;
    setState(() {
      _draggingSplit = false;
      if (_panelWidth < 80) {
        _mapMode = _DonorMapMode.mapOnly;
        _panelWidth = 0;
      } else if (_panelWidth < 280) {
        _mapMode = _DonorMapMode.half;
        _panelWidth = _widePanelWidth;
      } else {
        _mapMode = _DonorMapMode.half;
      }
    });
  }

  Widget _buildMapPane(BuildContext context, {required bool compact}) {
    final selected = _selectedBarangay;
    final drivesHere = selected == null ? 0 : _drivesIn(selected).length;
    final donorsHere = selected == null ? 0 : (_donorCounts[selected] ?? 0);
    final summary = selected == null
        ? null
        : '$donorsHere donor${donorsHere == 1 ? '' : 's'}'
              ' · $drivesHere drive${drivesHere == 1 ? '' : 's'}';

    return DigosMapPane(
      controller: _mapController,
      donorCounts: _donorCounts,
      drives: _driveMarkers,
      selectedBarangay: selected,
      selectedSummary: summary,
      mapDark: _mapDark,
      onSelectBarangay: (name) => setState(() => _selectedBarangay = name),
      onDriveTap: _showDriveSheet,
      onFacilityTap: _showFacilitySheet,
      onToggleMapDark: () => setState(() {
        _mapDarkOverride = !_mapDark;
        _mapDark = _mapDarkOverride!;
      }),
      compact: compact,
      chips: [
        _typeChip(context, null, 'ALL'),
        ...BloodType.values.map((t) => _typeChip(context, t, t.label)),
      ],
      legend: _buildLegend(context, compact: compact),
      listCollapsed: _mapMode == _DonorMapMode.mapOnly,
      // The restore bubble always returns to the normal half split, whichever
      // way the divider was dragged before.
      onToggleList: () => setState(() {
        _mapMode = _mapMode == _DonorMapMode.mapOnly
            ? _DonorMapMode.half
            : _DonorMapMode.mapOnly;
        if (_mapMode == _DonorMapMode.half) {
          _mapFraction = _halfFraction;
          _panelWidth = _widePanelWidth;
        }
      }),
      listLabel: 'donor list',
      listIcon: Icons.people_outline,
    );
  }

  Color _fillFor(int count) => digosHeatColor(count, dark: _mapDark);

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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : context.textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, {required bool compact}) {
    // Sum, not barangay count: three drives in Zone 1 is three active drives.
    final driveCount = _driveCounts.values.fold<int>(
      0,
      (total, count) => total + count,
    );
    final driveLabel = '$driveCount drive${driveCount == 1 ? '' : 's'}';
    return DigosLegendPanel(
      title: compact ? 'Donors' : 'DONOR DENSITY',
      compact: compact,
      entries: [
        DigosLegendEntry(
          color: _fillFor(0),
          label: compact ? '0' : 'No available donors',
        ),
        DigosLegendEntry(
          color: _fillFor(1),
          label: compact ? '1–2' : '1–2 donors',
        ),
        DigosLegendEntry(
          color: _fillFor(4),
          label: compact ? '3–5' : '3–5 donors',
        ),
        DigosLegendEntry(
          color: _fillFor(7),
          label: compact ? '6+' : '6+ donors',
        ),
      ],
      footer: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place, size: 14, color: TabangColors.crimson),
          const SizedBox(width: 2),
          Text(
            compact ? driveLabel : '$driveLabel active',
            style: TextStyle(fontSize: 11, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorPane(BuildContext context, {required bool compact}) {
    final donors = _visibleDonors;
    final drives = _repo.drives
        .where((d) => d.status != 'Completed')
        .toList(growable: false);
    final heading = switch (_paneTab) {
      0 => _selectedBarangay == null
          ? 'Available donors'
          : 'Available donors in $_selectedBarangay',
      1 => _selectedBarangay == null
          ? 'Hospitals & chapter'
          : 'Facilities in $_selectedBarangay',
      _ => _selectedBarangay == null
          ? 'Upcoming drives'
          : 'Drives in $_selectedBarangay',
    };
    final count = switch (_paneTab) {
      0 => donors.length,
      1 => digosFacilityPins.length,
      _ => drives.length,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TabangSpace.lg,
            TabangSpace.lg,
            TabangSpace.lg,
            TabangSpace.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // One header for every tab: the map switch used to disappear on
              // Facilities and Drives because it lived inside the Donors-only
              // block.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.15,
                        color: context.textColor,
                      ),
                    ),
                  ),
                  StatusPill('$count', tone: Tone.brand, dense: true),
                  if (_selectedBarangay != null)
                    Tooltip(
                      message: 'Clear barangay filter',
                      child: InkWell(
                        key: const ValueKey('clearDonorBarangayFilter'),
                        onTap: () => setState(() {
                          _selectedBarangay = null;
                          _refreshCounts();
                        }),
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
                    ),
                ],
              ),
              const SizedBox(height: TabangSpace.sm),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  // Text-only segments: with icons the three labels wrapped
                  // onto two lines ("Donor / s", "Faciliti / es") in a
                  // 330 px side panel.
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Donors', softWrap: false),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Facilities', softWrap: false),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text('Drives', softWrap: false),
                    ),
                  ],
                  selected: {_paneTab},
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 6),
                    ),
                    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
                  ),
                  onSelectionChanged: (selection) =>
                      setState(() => _paneTab = selection.first),
                ),
              ),
              if (_paneTab == 0) ...[
                const SizedBox(height: TabangSpace.sm),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Search donor # or barangay',
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
        Divider(height: 1, color: context.border),
        Expanded(
          child: switch (_paneTab) {
            0 =>
              donors.isEmpty
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
            1 => _buildFacilitiesTab(context),
            _ => _buildDrivesTab(context),
          },
        ),
      ],
    );
  }

  /// Hospitals and the PRC chapter, with a jump to each pin.
  Widget _buildFacilitiesTab(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(TabangSpace.md),
      itemCount: digosFacilityPins.length,
      separatorBuilder: (_, __) => const SizedBox(height: TabangSpace.sm),
      itemBuilder: (context, i) {
        final pin = digosFacilityPins[i];
        final isChapter = pin.kind == 'chapter';
        return SurfaceCard(
          padding: const EdgeInsets.all(TabangSpace.md),
          onTap: () {
            _focusFacility(pin);
            _showFacilitySheet(pin);
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isChapter ? Icons.bloodtype : Icons.local_hospital,
                size: 20,
                color: isChapter ? TabangColors.crimson : TabangColors.info,
              ),
              const SizedBox(width: TabangSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pin.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pin.note,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.my_location, size: 16, color: context.textMuted),
            ],
          ),
        );
      },
    );
  }

  /// Blood drives with a jump-to-barangay and the donor transfer to Requests.
  Widget _buildDrivesTab(BuildContext context) {
    final isDonor = widget.user.role == UserRole.donor;
    final drives = _repo.drives
        .where((d) => d.status != 'Completed')
        .toList(growable: false);

    if (drives.isEmpty) {
      return const EmptyState(
        art: TabangArt.inventory,
        title: 'No drives scheduled',
        message: 'The chapter publishes the next drive here once confirmed.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(TabangSpace.md),
      itemCount: drives.length,
      separatorBuilder: (_, __) => const SizedBox(height: TabangSpace.sm),
      itemBuilder: (context, i) {
        final drive = drives[i];
        final attending = _repo.driveInterestCount(drive.id);
        return SurfaceCard(
          padding: const EdgeInsets.all(TabangSpace.md),
          // The card itself opens the drive; the old Details button duplicated
          // that target and crowded the action row.
          onTap: () => _showDriveDetails(drive),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.event_outlined,
                    size: 18,
                    color: TabangColors.crimson,
                  ),
                  const SizedBox(width: TabangSpace.sm),
                  Expanded(
                    child: Text(
                      drive.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                  ),
                  StatusPill(
                    drive.status,
                    tone: drive.status == 'Ongoing' ? Tone.success : Tone.info,
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${drive.venue} · ${formatDateTime(drive.startsAt)}',
                style: TextStyle(fontSize: 12, color: context.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                '${drive.barangay} · $attending donor'
                '${attending == 1 ? '' : 's'} on the chapter list',
                style: TextStyle(fontSize: 12, color: context.textMuted),
              ),
              const SizedBox(height: TabangSpace.sm),
              Wrap(
                spacing: TabangSpace.sm,
                runSpacing: TabangSpace.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      _focusBarangay(drive.barangay);
                      setState(() => _selectedBarangay = drive.barangay);
                    },
                    icon: const Icon(Icons.place_outlined, size: 15),
                    label: const Text('Show on map'),
                  ),
                  if (isDonor && widget.onOpenRequests != null)
                    FilledButton.tonalIcon(
                      onPressed: widget.onOpenRequests,
                      icon: const Icon(
                        Icons.volunteer_activism_outlined,
                        size: 15,
                      ),
                      label: const Text('Open Requests'),
                    )
                  else if (widget.onOpenBloodBank != null)
                    FilledButton.tonalIcon(
                      onPressed: widget.onOpenBloodBank,
                      icon: const Icon(Icons.inventory_2_outlined, size: 15),
                      label: const Text('Blood bank'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDonorCard(BuildContext context, AppUser donor) {
    final eligibility = EligibilityEngine.evaluate(donor);
    final commitment = _repo.activeCommitmentFor(donor.id);

    return SurfaceCard(
      padding: const EdgeInsets.all(TabangSpace.lg),
      onTap: donor.shareBarangay ? () => _focusDonor(donor) : null,
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
                    semanticLabel: '${donor.mapHandle} profile illustration',
                    creditLabel: donor.mapHandle,
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
                      donor.mapHandle,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                    Text(
                      donor.shareBarangay ? donor.barangay : 'Barangay hidden',
                      style: TextStyle(fontSize: 12, color: context.textMuted),
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
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (commitment != null)
                Tooltip(
                  message:
                      'This donor is already selected for another active '
                      'request. They stay visible, but cannot be reserved for '
                      'two requests at once.',
                  child: StatusPill(
                    'Coordinating · ${commitment.id}',
                    tone: Tone.info,
                    dense: true,
                  ),
                ),
              if (widget.onOpenRequests != null)
                TextButton.icon(
                  onPressed: widget.onOpenRequests,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.assignment_outlined, size: 16),
                  label: const Text('Requests', style: TextStyle(fontSize: 12)),
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
                label: const Text('Message', style: TextStyle(fontSize: 12)),
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
        title: Text('Message ${donor.mapHandle}'),
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
        content: Text('Conversation with ${donor.mapHandle} is ready.'),
        action: widget.onOpenChat == null
            ? null
            : SnackBarAction(label: 'Open', onPressed: widget.onOpenChat!),
      ),
    );
  }
}
