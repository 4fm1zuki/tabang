import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/digos_map_pane.dart';
import '../../widgets/digos_vector_map.dart';
import '../../widgets/illustrations.dart';
import '../../widgets/request_document_list.dart';
import '../../widgets/request_review_dialogs.dart';
import '../../widgets/user_record_dialog.dart';

/// How the map and the request panel share a screen.
///
/// Deliberately the same three states as Find Donor: the map is either on (the
/// default [half] split) or off ([hidden]), toggled by one **Expand** /
/// **Collapse** button. [mapOnly] is the panel's own collapsed state, driven by
/// the chevron rather than by the map switch.
enum _OperationsMapMode { mapOnly, half, hidden }

/// Staff/admin operational map.
///
/// This is the community Find Donor map with staff data: the same map surface,
/// the same overlay chrome, the same Expand/Collapse switch and the same
/// side-panel anatomy. The list holds open requests (and pending donor
/// registrations) instead of donors; everything else is shared.
class OperationsMapPage extends StatefulWidget {
  const OperationsMapPage({
    super.key,
    required this.user,
    this.onOpenInventory,
    this.onOpenUsers,
    this.embedded = false,
  });

  final AppUser user;
  final VoidCallback? onOpenInventory;
  final VoidCallback? onOpenUsers;

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

  /// 0 = requests, 1 = pending registrations.
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

  /// Open requests per barangay, filtered by the same blood-type chips the
  /// community map uses.
  Map<String, int> get _requestCounts {
    final counts = <String, int>{};
    for (final request in _repo.requests) {
      if (request.status != RequestStatus.open &&
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

  List<DonorApplication> get _visibleApplications {
    final q = _query.trim().toLowerCase();
    return _repo.openDonorApplications.where((application) {
      final applicant = _repo.userById(application.userId);
      if (_selected != null && applicant?.barangay != _selected) return false;
      if (q.isEmpty) return true;
      return (applicant?.mapHandle.toLowerCase().contains(q) ?? false) ||
          (applicant?.fullName.toLowerCase().contains(q) ?? false) ||
          (applicant?.barangay.toLowerCase().contains(q) ?? false);
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
            : _buildWideLayout(context);
      },
    );
  }

  /// Phone arrangement with a real height animation, matching Find Donor:
  /// Expand/Collapse grows or shrinks the map while the request panel takes
  /// the remainder, and hiding the panel grows the map to the full page.
  Widget _buildNarrowLayout(
    BuildContext context, {
    required double width,
    required double height,
  }) {
    final mapTarget = switch (_mapMode) {
      _OperationsMapMode.hidden => 0.0,
      _OperationsMapMode.half => math.max(220.0, height * 0.52),
      _OperationsMapMode.mapOnly => height,
    };
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: mapTarget, end: mapTarget),
      duration: _paneAnimation,
      curve: Curves.easeOutCubic,
      builder: (context, animatedHeight, _) {
        final mapHeight = animatedHeight.clamp(0.0, height);
        final listHeight = math.max(0.0, height - mapHeight);
        final layoutHeight = math.max(listHeight, _minPaneLayoutHeight);
        return Column(
          children: [
            SizedBox(
              width: width,
              height: mapHeight,
              child: mapHeight < 1
                  ? const SizedBox.shrink()
                  : _buildMapPane(context, compact: true),
            ),
            if (mapHeight >= 1 && listHeight >= 1)
              Divider(height: 1, color: context.border),
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

  /// Wide arrangement: collapsing the panel animates its width to zero and
  /// hands the space to the map.
  Widget _buildWideLayout(BuildContext context) {
    if (_mapMode == _OperationsMapMode.hidden) {
      return _buildPanelOnlyPane(context, compact: false);
    }
    final panelTarget = _mapMode == _OperationsMapMode.mapOnly
        ? 0.0
        : _widePanelWidth;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: panelTarget, end: panelTarget),
      duration: _paneAnimation,
      curve: Curves.easeOutCubic,
      builder: (context, animatedWidth, _) {
        final panelWidth = animatedWidth.clamp(0.0, _widePanelWidth);
        return Row(
          children: [
            // Same element slot at every width, so collapsing the last few
            // pixels does not rebuild the map and reset its camera.
            Expanded(child: _buildMapPane(context, compact: false)),
            SizedBox(
              width: panelWidth,
              child: panelWidth < 0.5
                  ? const SizedBox.shrink()
                  : ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: _widePanelWidth,
                        maxWidth: _widePanelWidth,
                        child: SizedBox(
                          width: _widePanelWidth,
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
      requestCounts: _requestCounts,
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
      onToggleList: () => setState(
        () => _mapMode = _mapMode == _OperationsMapMode.mapOnly
            ? _OperationsMapMode.half
            : _OperationsMapMode.mapOnly,
      ),
      listLabel: 'request list',
      listTitle: _paneTab == 0 ? 'Open requests' : 'Pending registrations',
      listCount: _paneTab == 0
          ? _visibleRequests.length
          : _visibleApplications.length,
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

  Widget _buildLegend(BuildContext context, {required bool compact}) {
    return DigosLegendPanel(
      title: compact ? 'Requests' : 'OPEN REQUESTS',
      compact: compact,
      entries: [
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

  /// The panel with no map above it. The map switch lives in the shared
  /// header, so there is no second toolbar here.
  Widget _buildPanelOnlyPane(BuildContext context, {required bool compact}) {
    return _buildPanel(context, compact: compact);
  }

  /// One switch button for map visibility, mirroring the donor list header.
  Widget _hideMapButton(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('hideOperationsMapButton'),
      onPressed: () => setState(() => _mapMode = _OperationsMapMode.hidden),
      icon: const Icon(Icons.expand_less, size: 15),
      label: const Text('Expand'),
      style: _mapSwitchStyle(context),
    );
  }

  Widget _showMapButton(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('showOperationsMapButton'),
      onPressed: () => setState(() => _mapMode = _OperationsMapMode.half),
      icon: const Icon(Icons.expand_more, size: 15),
      label: const Text('Collapse'),
      style: _mapSwitchStyle(context),
    );
  }

  ButtonStyle _mapSwitchStyle(BuildContext context) {
    return OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      minimumSize: const Size(0, 28),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      backgroundColor: context.surfaceAlt,
      foregroundColor: context.textColor,
      side: BorderSide(color: context.border),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
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
    final applications = _visibleApplications;
    final heading = _paneTab == 0
        ? (_selected == null ? 'Open requests' : 'Requests in $_selected')
        : (_selected == null
              ? 'Pending registrations'
              : 'Registrations in $_selected');

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
              // Same anatomy as Find Donor: heading and map switch first, then
              // the segmented tabs, then the search field.
              Row(
                children: [
                  Expanded(
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
                  if (_mapMode == _OperationsMapMode.hidden)
                    _showMapButton(context)
                  else ...[
                    if (compact) ...[
                      const SizedBox(width: 4),
                      _hideMapButton(context),
                    ],
                    Tooltip(
                      message: 'Hide request list',
                      child: InkWell(
                        key: const ValueKey('collapseOperationsListButton'),
                        onTap: () => setState(
                          () => _mapMode = _OperationsMapMode.mapOnly,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: context.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
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
                      label: _tabLabel('Registrations', applications.length),
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
              const SizedBox(height: TabangSpace.sm),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: _paneTab == 0
                      ? 'Search request # or barangay'
                      : 'Search applicant or barangay',
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
              : (applications.isEmpty
                    ? const EmptyState(
                        art: TabangArt.donors,
                        title: 'No pending registrations',
                        message:
                            'New donor applications appear here for review.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(TabangSpace.md),
                        itemCount: applications.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: TabangSpace.sm),
                        itemBuilder: (context, i) =>
                            _applicationCard(context, applications[i]),
                      )),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- card bodies

  Widget _requestCard(BuildContext context, BloodRequest request) {
    return SurfaceCard(
      padding: const EdgeInsets.all(TabangSpace.md),
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
          // requester all live behind Details so the card stays a queue row.
          Text(
            '${request.hospital} · ${request.unitsNeeded} unit(s)',
            style: TextStyle(fontSize: 11, color: context.textMuted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              TextButton(
                onPressed: () => _showRequestDetails(context, request),
                child: const Text('Details'),
              ),
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

  Widget _applicationCard(BuildContext context, DonorApplication application) {
    final applicant = _repo.userById(application.userId);
    return SurfaceCard(
      padding: const EdgeInsets.all(TabangSpace.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  applicant?.mapHandle ?? application.userId,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textColor,
                  ),
                ),
                Text(
                  '${applicant?.barangay ?? '—'} · '
                  '${application.hasExistingCard ? 'Has PRC card' : 'New donor'} · '
                  '${application.status.label}',
                  style: TextStyle(fontSize: 11, color: context.textMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: applicant == null
                ? null
                : () => showUserRecordDialog(context, applicant),
            child: const Text('Details'),
          ),
          TextButton(
            onPressed: widget.onOpenUsers,
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }

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
      SnackBar(
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
