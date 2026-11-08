import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/digos_vector_map.dart';
import '../../widgets/layout.dart';

/// Staff/admin operational map.
///
/// The community Find Donor map answers "where can I donate?"; this one answers
/// "where is the chapter needed right now?". The fill layer switches to the
/// amber open-request ramp, the side panel aggregates eligible donors, open
/// requests and pending donor registrations per barangay, and staff can work a
/// request (view responders, select a donor, mark fulfilled) without leaving
/// the map.
class OperationsMapPage extends StatefulWidget {
  const OperationsMapPage({
    super.key,
    required this.user,
    this.onOpenInventory,
    this.onOpenUsers,
  });

  final AppUser user;
  final VoidCallback? onOpenInventory;
  final VoidCallback? onOpenUsers;

  @override
  State<OperationsMapPage> createState() => _OperationsMapPageState();
}

class _OperationsMapPageState extends State<OperationsMapPage> {
  final TabangRepository _repo = TabangRepository.instance;
  final MapController _mapController = MapController();

  String? _selected;

  /// Follows the app's effective theme (system-aware) unless the style button
  /// on the map has set a per-visit override.
  bool _mapDark = false;
  bool? _mapDarkOverride;

  /// The operations map can shade either open workload (requests) or donor
  /// availability. Staff asked for the donor-density view they already know
  /// from Find Donor.
  bool _showDonorDensity = false;

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

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1024;
    final map = _buildMap(context);
    final panel = _buildPanel(context);
    return compact
        ? ListView(
            padding: context.pagePadding,
            children: [
              SizedBox(height: 380, child: map),
              const SizedBox(height: TabangSpace.lg),
              panel,
            ],
          )
        : Padding(
            padding: context.pagePadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: SizedBox(height: 640, child: map)),
                const SizedBox(width: TabangSpace.lg),
                Expanded(flex: 2, child: SingleChildScrollView(child: panel)),
              ],
            ),
          );
  }

  Widget _buildMap(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(TabangRadius.lg),
            child: DigosVectorMap(
              controller: _mapController,
              donorCounts: _repo.donorCountsByBarangay(),
              // Switches the heat ramp between workload and donor density;
              // the legend below tracks the same flag.
              requestCounts: _showDonorDensity
                  ? null
                  : _repo.openRequestsByBarangay(),
              drives: _driveMarkers,
              selectedBarangay: _selected,
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
            ),
          ),
        ),
        Positioned(
          top: TabangSpace.md,
          right: TabangSpace.md,
          child: Column(
            children: [
              _mapButton(
                context,
                Icons.add,
                () => _mapController.move(
                  _mapController.camera.center,
                  (_mapController.camera.zoom + 0.75).clamp(10.5, 18),
                ),
                tooltip: 'Zoom in',
              ),
              const SizedBox(height: 4),
              _mapButton(
                context,
                Icons.remove,
                () => _mapController.move(
                  _mapController.camera.center,
                  (_mapController.camera.zoom - 0.75).clamp(10.5, 18),
                ),
                tooltip: 'Zoom out',
              ),
              const SizedBox(height: 4),
              _mapButton(
                context,
                Icons.fit_screen,
                () => DigosVectorMap.fitCity(_mapController),
                tooltip: 'Fit city',
                accent: true,
              ),
              const SizedBox(height: 4),
              _mapButton(
                context,
                _mapDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                () => setState(() {
                  _mapDarkOverride = !_mapDark;
                  _mapDark = _mapDarkOverride!;
                }),
                tooltip: _mapDark ? 'Use light map' : 'Use dark map',
              ),
            ],
          ),
        ),
        Positioned(
          left: TabangSpace.md,
          bottom: TabangSpace.md,
          child: SurfaceCard(
            padding: const EdgeInsets.all(TabangSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Staff get both ramps: workload for triage and the same
                // donor-density view used by Find Donor. The switch drives
                // both the shading and this legend.
                Row(
                  children: [
                    _layerToggle(context, donor: false),
                    const SizedBox(width: 4),
                    _layerToggle(context, donor: true),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _showDonorDensity ? 'DONOR DENSITY' : 'OPEN REQUESTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                if (_showDonorDensity) ...[
                  _legendRow(
                    context,
                    digosHeatColor(0, dark: _mapDark),
                    'No available donors',
                  ),
                  _legendRow(
                    context,
                    digosHeatColor(1, dark: _mapDark),
                    '1–2 donors',
                  ),
                  _legendRow(
                    context,
                    digosHeatColor(4, dark: _mapDark),
                    '3–5 donors',
                  ),
                  _legendRow(
                    context,
                    digosHeatColor(7, dark: _mapDark),
                    '6+ donors',
                  ),
                ] else ...[
                  _legendRow(
                    context,
                    digosRequestColor(0, dark: _mapDark),
                    'None open',
                  ),
                  _legendRow(
                    context,
                    digosRequestColor(1, dark: _mapDark),
                    '1 request',
                  ),
                  _legendRow(
                    context,
                    digosRequestColor(3, dark: _mapDark),
                    '2–3 requests',
                  ),
                  _legendRow(
                    context,
                    digosRequestColor(6, dark: _mapDark),
                    '4+ requests',
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.bloodtype,
                      size: 12,
                      color: TabangColors.crimson,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Chapter',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          right: TabangSpace.md,
          bottom: TabangSpace.md,
          child: DigosMapAttribution(),
        ),
      ],
    );
  }

  Widget _legendRow(BuildContext context, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: context.border),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  /// Small two-state switch inside the map legend card.
  Widget _layerToggle(BuildContext context, {required bool donor}) {
    final selected = _showDonorDensity == donor;
    return InkWell(
      borderRadius: BorderRadius.circular(TabangRadius.xs),
      onTap: () => setState(() => _showDonorDensity = donor),
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
          donor ? 'Donor density' : 'Requests',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? TabangColors.crimson : context.textMuted,
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
      color: accent ? TabangColors.crimson : context.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TabangRadius.sm),
        side: BorderSide(color: accent ? TabangColors.crimson : context.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(TabangRadius.sm),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 17,
            color: accent ? Colors.white : context.textColor,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  Widget _buildPanel(BuildContext context) {
    final selected = _selected;
    final requests = selected == null
        ? _repo.requests
              .where(
                (r) =>
                    r.status == RequestStatus.open ||
                    r.status == RequestStatus.matched,
              )
              .take(8)
              .toList()
        : _repo.openRequestsIn(selected);
    final applications = _repo.openDonorApplications.where((application) {
      if (selected == null) return true;
      return _repo.userById(application.userId)?.barangay == selected;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Operations map',
          subtitle: selected == null
              ? 'Requests, donors and registrations across the 26 barangays.'
              : 'Barangay $selected at a glance.',
          actions: [
            OutlinedButton.icon(
              onPressed: widget.onOpenInventory,
              icon: const Icon(Icons.inventory_2_outlined, size: 15),
              label: const Text('Inventory queue'),
            ),
          ],
        ),
        const SizedBox(height: TabangSpace.lg),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                context,
                'Open requests',
                '${_repo.openRequestsByBarangay().values.fold<int>(0, (a, b) => a + b)}',
                Icons.campaign_outlined,
                TabangColors.crimson,
              ),
            ),
            const SizedBox(width: TabangSpace.sm),
            Expanded(
              child: _metricCard(
                context,
                'Eligible donors',
                '${_repo.eligibleDonorsFor().length}',
                Icons.volunteer_activism_outlined,
                TabangColors.success,
              ),
            ),
            const SizedBox(width: TabangSpace.sm),
            Expanded(
              child: _metricCard(
                context,
                'Pending registrations',
                '${_repo.openDonorApplications.length}',
                Icons.how_to_reg_outlined,
                TabangColors.warning,
              ),
            ),
            const SizedBox(width: TabangSpace.sm),
            Expanded(
              child: _metricCard(
                context,
                'Appointments to confirm',
                '${_repo.pendingAppointments.length}',
                Icons.event_available_outlined,
                TabangColors.crimson,
              ),
            ),
          ],
        ),
        const SizedBox(height: TabangSpace.lg),
        if (selected == null)
          Text(
            'Tap a barangay on the map to scope the queue, or work the '
            'city-wide list below.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: context.textMuted,
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_repo.donorCountsByBarangay()[selected] ?? 0} eligible '
                  'donor(s) · ${_repo.pendingApplicationsByBarangay()[selected] ?? 0} '
                  'pending registration(s)',
                  style: TextStyle(fontSize: 12, color: context.textMuted),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selected = null),
                child: const Text('Clear'),
              ),
            ],
          ),
        const SizedBox(height: TabangSpace.sm),
        SectionLabel(selected == null ? 'City-wide queue' : 'Requests here'),
        const SizedBox(height: TabangSpace.sm),
        if (requests.isEmpty)
          Text(
            'Nothing open${selected == null ? '' : ' in $selected'}.',
            style: TextStyle(fontSize: 12, color: context.textMuted),
          )
        else
          for (final request in requests) _requestCard(context, request),
        if (applications.isNotEmpty) ...[
          const SizedBox(height: TabangSpace.lg),
          const SectionLabel('Pending registrations'),
          const SizedBox(height: TabangSpace.sm),
          for (final application in applications)
            _applicationCard(context, application),
        ],
      ],
    );
  }

  Widget _metricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return SurfaceCard(
      padding: const EdgeInsets.all(TabangSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.textColor,
            ),
          ),
          Text(
            label,
            maxLines: 2,
            style: TextStyle(fontSize: 10.5, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(BuildContext context, BloodRequest request) {
    final responders = _repo.responsesFor(request.id);
    final selectedCount = responders
        .where((r) => r.status == ResponseStatus.selected)
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: TabangSpace.sm),
      child: SurfaceCard(
        padding: const EdgeInsets.all(TabangSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                const SizedBox(width: 6),
                StatusPill(request.status.label, dense: true),
                const Spacer(),
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
            Text(
              '${request.hospital} · ${request.unitsNeeded} unit(s) · '
              '$selectedCount selected · ${responders.length} response(s)',
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
                if (widget.user.role.canFulfillRequests)
                  TextButton(
                    onPressed: () => _fulfil(context, request),
                    child: const Text('Mark fulfilled'),
                  ),
                if (widget.user.role.canFulfillRequests &&
                    request.source == RequestSource.donorNetwork &&
                    request.status == RequestStatus.open &&
                    responders.any((r) => r.status == ResponseStatus.pending))
                  TextButton(
                    onPressed: () => _showResponders(context, request),
                    child: const Text('Select donor'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _applicationCard(BuildContext context, DonorApplication application) {
    final applicant = _repo.userById(application.userId);
    return Padding(
      padding: const EdgeInsets.only(bottom: TabangSpace.sm),
      child: SurfaceCard(
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
              onPressed: widget.onOpenUsers,
              child: const Text('Review'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestDetails(BuildContext context, BloodRequest request) {
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
              Text('Urgency: ${request.urgency.label}'),
              Text('Hospital: ${request.hospital}'),
              Text('Barangay: ${request.barangay}'),
              Text('Source: ${request.source.label}'),
              if (request.note != null && request.note!.trim().isNotEmpty)
                Text('Note: ${request.note}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showResponders(BuildContext context, BloodRequest request) {
    final pending = _repo
        .responsesFor(request.id)
        .where((r) => r.status == ResponseStatus.pending)
        .toList();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select a donor'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selection needs a reciprocal chat between the requester and '
                'the donor, and re-checks eligibility at this moment.',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: TabangSpace.sm),
              for (final response in pending)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(response.donorAlias),
                  subtitle: Text(response.message ?? 'No message'),
                  trailing: TextButton(
                    onPressed: () {
                      final thread = _repo.selectResponse(
                        responseId: response.id,
                        selectedById: widget.user.id,
                      );
                      if (thread == null) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Not selectable yet — the requester and donor '
                              'must both have sent a message first.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Select'),
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
