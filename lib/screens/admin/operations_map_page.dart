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
import '../../widgets/donor_list_card.dart';
import '../../widgets/illustrations.dart';
import '../../widgets/map_split_handle.dart';
import '../../widgets/request_document_list.dart';
import '../../widgets/request_review_dialogs.dart';
import '../../widgets/user_record_dialog.dart';

/// How the map and the request panel share a screen.
///
/// The draggable divider between them snaps between three states: [mapOnly]
/// (the list steps aside and its restore bubble appears), [half] (the default
/// 50/50 split) and [hidden] (the map steps aside and the list fills the page).
enum _OperationsMapMode { mapOnly, half, hidden }

/// Staff/admin operational map.
///
/// This is the community Find Donor map with staff data: the same map surface,
/// the same overlay chrome, the same Expand/Collapse switch and the same
/// side-panel anatomy. The list holds the open request queue and the donor
/// directory; everything else is shared.
class OperationsMapPage extends StatefulWidget {
  const OperationsMapPage({
    super.key,
    required this.user,
    this.onOpenInventory,
    this.onOpenUsers,
    this.onOpenMessages,
    this.embedded = false,
  });

  final AppUser user;
  final VoidCallback? onOpenInventory;
  final VoidCallback? onOpenUsers;

  /// Opens the shell's Messages tab on a conversation with the given user id.
  /// When null the donor card simply omits its Message action.
  final ValueChanged<String>? onOpenMessages;

  /// Embedded inside [OperationsWorkspacePage]. Kept for API compatibility;
  /// the map always fills its slot the way Find Donor does.
  final bool embedded;

  @override
  State<OperationsMapPage> createState() => _OperationsMapPageState();
}

class _OperationsMapPageState extends State<OperationsMapPage> {
  final TabangRepository _repo = TabangRepository.instance;
  final MapController _mapController = MapController();

  String? _selected;
  BloodType? _bloodType;
  String _query = '';
  _OperationsMapMode _mapMode = _OperationsMapMode.half;

  /// Fraction of the phone's body height given to the map (0–1). The draggable
  /// divider updates it live; on release it snaps to 0, 0.52 or 1.
  double _mapFraction = 0.52;

  /// Width of the desktop request panel. Dragging the vertical divider left
  /// shrinks it to zero (map only), which shows the same restore bubble.
  double _panelWidth = _widePanelWidth;
  bool _draggingSplit = false;

  /// Staff can switch the heat ramp between the amber request-workload view
  /// (default) and the community donor-density view. The legend switch and the
  /// panel tab both drive it through [_selectPaneTab]; this flag and `_paneTab`
  /// are set together there so they cannot disagree.
  bool _showDonorDensity = false;

  /// 0 = requests, 1 = donors.
  int _paneTab = 0;

  /// Follows the app's effective theme (system-aware) unless the style button
  /// on the map has set a per-visit override.
  bool _mapDark = false;
  bool? _mapDarkOverride;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_refresh);
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
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------- map data

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

  /// Actionable requests per barangay, filtered by the same blood-type chips
  /// the community map uses.
  ///
  /// Matches the panel list exactly: **Awaiting verification** requests count
  /// too, otherwise a queue made up only of newly submitted requests paints no
  /// heat at all and the map reads as empty.
  Map<String, int> get _requestCounts {
    final counts = <String, int>{};
    for (final request in _repo.requests) {
      if (request.status != RequestStatus.pendingReview &&
          request.status != RequestStatus.open &&
          request.status != RequestStatus.matched) {
        continue;
      }
      if (_bloodType != null && request.bloodType != _bloodType) continue;
      counts.update(request.barangay, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  List<BloodRequest> get _visibleRequests {
    final q = _query.trim().toLowerCase();
    final list = _repo.requests.where((request) {
      final actionable =
          request.status == RequestStatus.pendingReview ||
          request.status == RequestStatus.open ||
          request.status == RequestStatus.matched;
      if (!actionable) return false;
      if (_selected != null && request.barangay != _selected) return false;
      if (_bloodType != null && request.bloodType != _bloodType) return false;
      if (q.isEmpty) return true;
      return request.id.toLowerCase().contains(q) ||
          request.patientAlias.toLowerCase().contains(q) ||
          request.hospital.toLowerCase().contains(q) ||
          request.barangay.toLowerCase().contains(q) ||
          request.bloodType.label.toLowerCase().contains(q);
    }).toList();

    int rank(BloodRequest r) => switch (r.status) {
      RequestStatus.pendingReview => 0,
      RequestStatus.open => 1,
      RequestStatus.matched => 2,
      _ => 3,
    };
    list.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  /// Donors shown in the panel's Donors tab: the same audience Find Donor
  /// lists, narrowed by the selected barangay and the search box.
  List<AppUser> get _visibleDonors {
    final q = _query.trim().toLowerCase();
    return _repo.findDonors(barangay: _selected).where((donor) {
      if (q.isEmpty) return true;
      return donor.mapHandle.toLowerCase().contains(q) ||
          (donor.shareBarangay && donor.barangay.toLowerCase().contains(q)) ||
          (donor.bloodType?.label.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ------------------------------------------------------------------- build

  /// Mirrors Find Donor's transition timing so both maps feel identical.
  static const Duration _paneAnimation = Duration(milliseconds: 280);

  /// Minimum height a panel is laid out at while it animates away; below this
  /// it is clipped rather than reflowed into its own header.
  static const double _minPaneLayoutHeight = 200;

  /// Width of the request panel on a wide window.
  static const double _widePanelWidth = 330;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Same breakpoint as Find Donor: only phones stack the map above the
        // panel.
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

  /// Phone arrangement: a draggable bar between the stacked map and request
  /// panel. Pull the bar down to grow the map (the restore bubble appears at
  /// map-only); pull it up to grow the list. Releasing near the middle restores
  /// the normal half-and-half split.
  Widget _buildNarrowLayout(
    BuildContext context, {
    required double width,
    required double height,
  }) {
    final available = math.max(0.0, height - MapSplitHandle.extent);
    final mapTarget = switch (_mapMode) {
      _OperationsMapMode.hidden => 0.0,
      _OperationsMapMode.mapOnly => available,
      _OperationsMapMode.half => math.min(
        available,
        math.max(220.0, available * _mapFraction),
      ),
    };
    return TweenAnimationBuilder<double>(
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
                child: _buildMapPane(context, compact: true),
              ),
            MapSplitHandle(
              key: const ValueKey('mapSplitHandle'),
              vertical: false,
              tooltip: _mapMode == _OperationsMapMode.mapOnly
                  ? 'Drag up to show the request list'
                  : _mapMode == _OperationsMapMode.hidden
                  ? 'Drag down to show the map'
                  : 'Drag to resize the map and request list',
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
                        child: _buildPanel(context, compact: true),
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
        _mapMode = _OperationsMapMode.mapOnly;
      } else if (next <= 0.015) {
        _mapMode = _OperationsMapMode.hidden;
      } else {
        _mapMode = _OperationsMapMode.half;
      }
    });
  }

  void _endNarrowSplitDrag() {
    if (!_draggingSplit) return;
    setState(() {
      _draggingSplit = false;
      if (_mapFraction >= 0.82) {
        _mapMode = _OperationsMapMode.mapOnly;
        _mapFraction = 1;
      } else if (_mapFraction <= 0.25) {
        _mapMode = _OperationsMapMode.hidden;
        _mapFraction = 0;
      } else {
        _mapMode = _OperationsMapMode.half;
        _mapFraction = _halfFraction;
      }
    });
  }

  /// Wide arrangement: the divider is a vertical bar between the map and the
  /// request panel. Drag it left to shrink the panel to zero (map only), or
  /// right to widen it.
  Widget _buildWideLayout(BuildContext context, {required double width}) {
    final maxPanel = math.max(260.0, math.min(520.0, width * 0.55));
    final panelTarget = _mapMode == _OperationsMapMode.mapOnly
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
            // Same element slot at every width, so collapsing the last few
            // pixels does not rebuild the map and reset its camera.
            Expanded(child: _buildMapPane(context, compact: false)),
            MapSplitHandle(
              key: const ValueKey('mapSplitHandle'),
              vertical: true,
              tooltip: panelWidth < 1
                  ? 'Drag right to show the request list'
                  : 'Drag to resize the map and request list',
              onDelta: (delta) => _dragWideSplit(delta, maxPanel),
              onDragEnd: _endWideSplitDrag,
            ),
            SizedBox(
              width: panelWidth,
              child: panelWidth < 0.5
                  ? const SizedBox.shrink()
                  : ClipRect(
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
                            child: _buildPanel(context, compact: false),
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
      _mapMode = next < 0.5
          ? _OperationsMapMode.mapOnly
          : _OperationsMapMode.half;
    });
  }

  void _endWideSplitDrag() {
    if (!_draggingSplit) return;
    setState(() {
      _draggingSplit = false;
      if (_panelWidth < 80) {
        _mapMode = _OperationsMapMode.mapOnly;
        _panelWidth = 0;
      } else if (_panelWidth < 280) {
        _mapMode = _OperationsMapMode.half;
        _panelWidth = _widePanelWidth;
      } else {
        _mapMode = _OperationsMapMode.half;
      }
    });
  }

  Widget _buildMapPane(BuildContext context, {required bool compact}) {
    final selected = _selected;
    final requestsHere = selected == null
        ? 0
        : _repo.openRequestsIn(selected).length;
    final registrationsHere = selected == null
        ? 0
        : _repo.pendingApplicationsByBarangay()[selected]?.toInt() ?? 0;
    final summary = selected == null
        ? null
        : '$requestsHere request${requestsHere == 1 ? '' : 's'}'
              ' · $registrationsHere registration'
              '${registrationsHere == 1 ? '' : 's'}';

    return DigosMapPane(
      controller: _mapController,
      donorCounts: _repo.donorCountsByBarangay(),
      // A null requestCounts makes the shared map paint the donor-density
      // ramp; the legend switch decides which ramp is live.
      requestCounts: _showDonorDensity ? null : _requestCounts,
      drives: _driveMarkers,
      selectedBarangay: selected,
      selectedSummary: summary,
      mapDark: _mapDark,
      onSelectBarangay: (name) => setState(() => _selected = name),
      onDriveTap: (barangay) => setState(() => _selected = barangay),
      onFacilityTap: (pin) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(pin.name),
          content: Text(pin.note),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
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
      listCollapsed: _mapMode == _OperationsMapMode.mapOnly,
      // The restore bubble always returns to the normal half split, whichever
      // way the divider was dragged before.
      onToggleList: () => setState(() {
        _mapMode = _mapMode == _OperationsMapMode.mapOnly
            ? _OperationsMapMode.half
            : _OperationsMapMode.mapOnly;
        if (_mapMode == _OperationsMapMode.half) {
          _mapFraction = _halfFraction;
          _panelWidth = _widePanelWidth;
        }
      }),
      listLabel: 'request list',
      listIcon: _paneTab == 0
          ? Icons.assignment_outlined
          : Icons.person_add_alt_1_outlined,
    );
  }

  Widget _typeChip(BuildContext context, BloodType? type, String label) {
    final selected = _bloodType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(TabangRadius.pill),
        onTap: () => setState(() => _bloodType = type),
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

  /// Selecting a panel tab also picks the heat layer, mirroring Find Donor's
  /// `_selectPaneTab`: the Requests tab paints the amber request ramp and the
  /// Donors tab donor density, so the legend switch and the tab cannot
  /// disagree. Both controls route through here.
  void _selectPaneTab(int tab) {
    setState(() {
      _paneTab = tab;
      // 0 = requests, 1 = donors.
      _showDonorDensity = tab == 1;
    });
  }

  Widget _buildLegend(BuildContext context, {required bool compact}) {
    // Staff get both ramps through one two-state switch: the amber
    // request-workload heat (the default, matching the old operations map) and
    // the same warm donor-density ramp the community map uses.
    final donor = _showDonorDensity;
    return DigosLegendPanel(
      // No legend title: the layer chips below already name the active ramp
      // ("Donor density" / "Requests"), so a heading repeated the switch.
      title: '',
      compact: compact,
      header: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _layerToggle(context, compact: compact, donor: true),
          _layerToggle(context, compact: compact, donor: false),
        ],
      ),
      entries: donor
          ? [
              DigosLegendEntry(
                color: digosHeatColor(0, dark: _mapDark),
                label: compact ? '0' : 'No available donors',
              ),
              DigosLegendEntry(
                color: digosHeatColor(1, dark: _mapDark),
                label: compact ? '1–2' : '1–2 donors',
              ),
              DigosLegendEntry(
                color: digosHeatColor(4, dark: _mapDark),
                label: compact ? '3–5' : '3–5 donors',
              ),
              DigosLegendEntry(
                color: digosHeatColor(7, dark: _mapDark),
                label: compact ? '6+' : '6+ donors',
              ),
            ]
          : [
              DigosLegendEntry(
                color: digosRequestColor(0, dark: _mapDark),
                label: compact ? '0' : 'None open',
              ),
              DigosLegendEntry(
                color: digosRequestColor(1, dark: _mapDark),
                label: compact ? '1' : '1 request',
              ),
              DigosLegendEntry(
                color: digosRequestColor(3, dark: _mapDark),
                label: compact ? '2–3' : '2–3 requests',
              ),
              DigosLegendEntry(
                color: digosRequestColor(6, dark: _mapDark),
                label: compact ? '4+' : '4+ requests',
              ),
            ],
      footer: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bloodtype, size: 12, color: TabangColors.crimson),
          const SizedBox(width: 4),
          Text(
            'Chapter',
            style: TextStyle(fontSize: 11, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  /// Small two-state switch inside the map legend card.
  Widget _layerToggle(
    BuildContext context, {
    required bool compact,
    required bool donor,
  }) {
    final selected = _showDonorDensity == donor;
    return InkWell(
      key: ValueKey(
        donor ? 'operationsHeatDonors' : 'operationsHeatRequests',
      ),
      borderRadius: BorderRadius.circular(TabangRadius.xs),
      onTap: () => _selectPaneTab(donor ? 1 : 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? (context.isDark
                    ? TabangColors.crimson.withValues(alpha: 0.22)
                    : TabangColors.crimsonSoft)
              : null,
          borderRadius: BorderRadius.circular(TabangRadius.xs),
          border: Border.all(
            color: selected
                ? TabangColors.crimson.withValues(alpha: 0.45)
                : context.border,
          ),
        ),
        child: Text(
          donor ? (compact ? 'Donors' : 'Donor density') : 'Requests',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? TabangColors.crimson : context.textMuted,
          ),
        ),
      ),
    );
  }

  /// Tab label with its own count, so the queue size reads on the tab instead
  /// of floating beside the heading where it looked like a Collapse badge.
  Widget _tabLabel(String label, int count) {
    // scaleDown: the equal-width segments can be narrower than the label at
    // the panel's 330 px cap (and in tests, whose font is much wider), so the
    // label shrinks instead of overflowing.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, softWrap: false),
          const SizedBox(width: 6),
          // A bare count, not a StatusPill: the pill's padding pushed
          // "Registrations" past the edge of the 330 px side panel.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: context.surfaceAlt,
              borderRadius: BorderRadius.circular(TabangRadius.pill),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: TabangColors.crimson,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context, {required bool compact}) {
    final requests = _visibleRequests;
    final donors = _visibleDonors;
    final heading = _paneTab == 0
        ? (_selected == null ? 'Open requests' : 'Requests in $_selected')
        : (_selected == null ? 'Donors' : 'Donors in $_selected');
    final count = _paneTab == 0 ? requests.length : donors.length;

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
              // Same anatomy as Find Donor: heading first (the map/list switch
              // is now the draggable divider below the map), then the
              // segmented tabs, then the search field.
              Row(
                // Same anatomy as Find Donor: the count sits beside the
                // heading, the clear-filter action stays at the far right.
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            heading,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.15,
                              color: context.textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: TabangSpace.sm),
                        CountBadge(
                          count,
                          semanticLabel:
                              '$count '
                              '${_paneTab == 0 ? 'open requests' : 'donors'}',
                        ),
                      ],
                    ),
                  ),
                  if (_selected != null)
                    Tooltip(
                      message: 'Clear barangay filter',
                      child: InkWell(
                        key: const ValueKey('clearOperationsBarangayFilter'),
                        onTap: () => setState(() => _selected = null),
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
                // Text-only segments, exactly like Find Donor: with icons the
                // labels wrap in a 330 px side panel.
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 0,
                      label: _tabLabel('Requests', requests.length),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: _tabLabel('Donors', donors.length),
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
                      _selectPaneTab(selection.first),
                ),
              ),
              const SizedBox(height: TabangSpace.sm),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: _paneTab == 0
                      ? 'Search request # or barangay'
                      : 'Search donor or barangay',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 16),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: context.border),
        Expanded(
          child: _paneTab == 0
              ? (requests.isEmpty
                    ? EmptyState(
                        art: TabangArt.requests,
                        title: 'Nothing open',
                        message: _selected == null
                            ? 'No request needs staff action right now.'
                            : 'No request needs staff action in $_selected.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(TabangSpace.md),
                        itemCount: requests.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: TabangSpace.sm),
                        itemBuilder: (context, i) =>
                            _requestCard(context, requests[i]),
                      ))
              : (donors.isEmpty
                    ? EmptyState(
                        art: TabangArt.donors,
                        title: 'No donors here',
                        message: _selected == null
                            ? 'No donor is currently listed for this chapter.'
                            : 'No donor is listed in $_selected right now.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(TabangSpace.md),
                        itemCount: donors.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: TabangSpace.sm),
                        itemBuilder: (context, i) =>
                            _donorCard(context, donors[i]),
                      )),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- card bodies

  /// Staff see the same donor card the community map shows, with a tap that
  /// opens the account record and a Message action that reuses the shell's
  /// Messages tab.
  Widget _donorCard(BuildContext context, AppUser donor) {
    return DonorListCard(
      donor: donor,
      eligibility: EligibilityEngine.evaluate(donor),
      commitmentId: _repo.activeCommitmentFor(donor.id)?.id,
      onTap: () => showUserRecordDialog(context, donor),
      onTapHint: 'Open ${donor.mapHandle}\'s record',
      actions: [
        TextButton.icon(
          onPressed: () => showUserRecordDialog(context, donor),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.badge_outlined, size: 16),
          label: const Text('Record', style: TextStyle(fontSize: 12)),
        ),
        if (widget.onOpenMessages != null)
          TextButton.icon(
            onPressed: () => widget.onOpenMessages!(donor.id),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.forum_outlined, size: 16),
            label: const Text('Message', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _requestCard(BuildContext context, BloodRequest request) {
    return SurfaceCard(
      padding: const EdgeInsets.all(TabangSpace.md),
      // The whole card opens the request; the separate Details button was
      // pointing at the same sheet and only crowded the action row.
      onTap: () => _showRequestDetails(context, request),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wrap, not a fixed row: "Awaiting verification" is a long
              // status and used to push the barangay past the card edge on
              // the narrow panel.
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusPill(
                      request.urgency.label,
                      tone: request.urgency == RequestUrgency.critical
                          ? Tone.danger
                          : request.urgency == RequestUrgency.urgent
                          ? Tone.warning
                          : Tone.neutral,
                      dense: true,
                    ),
                    StatusPill(request.status.label, dense: true),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                request.barangay,
                style: TextStyle(fontSize: 11, color: context.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${request.patientAlias} · ${request.bloodType.label} '
            '${request.component.label}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 2),
          // One glanceable line; hospital, units, responder counts and the
          // requester all live behind a tap on the card, so the row stays a
          // queue entry rather than a details form.
          Text(
            '${request.hospital} · ${request.unitsNeeded} unit(s)',
            style: TextStyle(fontSize: 11, color: context.textMuted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              if (widget.user.role.canFulfillRequests &&
                  request.isAwaitingReview) ...[
                TextButton(
                  onPressed: () => _reject(context, request),
                  child: const Text('Reject'),
                ),
                FilledButton(
                  onPressed: () => _verify(context, request),
                  child: const Text('Verify'),
                ),
              ],
              if (widget.user.role.canFulfillRequests &&
                  !request.isAwaitingReview &&
                  request.status != RequestStatus.fulfilled &&
                  request.status != RequestStatus.rejected &&
                  request.status != RequestStatus.cancelled)
                TextButton(
                  onPressed: () => _fulfil(context, request),
                  child: const Text('Mark fulfilled'),
                ),
              // Staff no longer pick donors: verification opens the request
              // and the requester selects from the people who responded.
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- card bodies

  // ----------------------------------------------------------------- actions

  /// Verification shows the actual attachments and confirms the booked slot.
  void _verify(BuildContext context, BloodRequest request) {
    showVerifyRequestDialog(context, request, actor: widget.user);
  }

  void _reject(BuildContext context, BloodRequest request) {
    showRejectRequestDialog(context, request, actor: widget.user);
  }

  void _showRequestDetails(BuildContext context, BloodRequest request) {
    final responders = _repo.responsesFor(request.id);
    final selectedCount = responders
        .where((r) => r.status == ResponseStatus.selected)
        .length;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Request ${request.id}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient: ${request.patientAlias}'),
              Text(
                'Need: ${request.bloodType.label} · '
                '${request.component.label} · ${request.unitsNeeded} unit(s)',
              ),
              Text(
                'Urgency: ${request.urgency.label} · ${request.urgency.detail}',
              ),
              Text('Status: ${request.status.label}'),
              Text(
                'Responses: $selectedCount selected · '
                '${responders.length} response(s)',
              ),
              Text('Hospital: ${request.hospital}'),
              Text('Barangay: ${request.barangay}'),
              Text('Source: ${request.source.label}'),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    const Text('Requested by'),
                    UserMention(userId: request.requesterId),
                    if (responders.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      const Text('· Responders:'),
                      for (final response in responders)
                        UserMention(
                          userId: response.donorId,
                          fallback: response.donorAlias,
                        ),
                    ],
                  ],
                ),
              ),
              if (request.scheduledFor != null)
                Text('Booked slot: ${formatDateTime(request.scheduledFor!)}'),
              if (request.documents.isNotEmpty) ...[
                const SizedBox(height: TabangSpace.sm),
                Text(
                  'Documents',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: dialogContext.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                RequestDocumentList(documents: request.documents, dense: true),
              ],
              if (request.assignedUnitIds.isNotEmpty)
                Text('Held units: ${request.assignedUnitIds.join(', ')}'),
              if (request.reviewNote != null &&
                  request.reviewNote!.trim().isNotEmpty)
                Text('Review note: ${request.reviewNote}'),
              if (request.note != null && request.note!.trim().isNotEmpty)
                Text('Note: ${request.note}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final requester = _repo.userById(request.requesterId);
              if (requester != null) {
                showUserRecordDialog(dialogContext, requester);
              }
            },
            child: const Text('Requester details'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (widget.user.role.canFulfillRequests &&
              request.isAwaitingReview) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _reject(context, request);
              },
              child: const Text('Reject'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _verify(context, request);
              },
              child: const Text('Verify'),
            ),
          ],
        ],
      ),
    );
  }

  void _fulfil(BuildContext context, BloodRequest request) {
    final ok = _repo.markRequestFulfilled(request.id, actorId: widget.user.id);
    ScaffoldMessenger.of(context).showSnackBar(
      TabangSnackBar(
        content: Text(
          ok
              ? '${request.id} marked fulfilled.'
              : '${request.id} cannot be fulfilled yet — a donor-network '
                    'request must be matched first.',
        ),
      ),
    );
  }
}
