import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/barcode.dart';
import '../../widgets/common.dart';
import '../../widgets/illustrations.dart';

/// Inventory and request management for chapter staff.
///
/// Staff can change a unit's status, see expiry pressure, and work the request
/// queue. The previous build's inventory page was read-only and held a second,
/// divergent copy of the blood unit list.
class InventoryManagementPage extends StatefulWidget {
  const InventoryManagementPage({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<InventoryManagementPage> createState() =>
      _InventoryManagementPageState();
}

class _InventoryManagementPageState extends State<InventoryManagementPage> {
  final TabangRepository _repo = TabangRepository.instance;

  BloodType? _typeFilter;
  UnitStatus? _statusFilter;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_refresh);
  }

  @override
  void dispose() {
    _repo.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<BloodUnit> get _units {
    final now = DateTime.now();
    return _repo.units.where((u) {
      if (_typeFilter != null && u.bloodType != _typeFilter) return false;
      if (_statusFilter != null && u.effectiveStatus(now) != _statusFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Inventory & requests',
            subtitle: 'Manage blood units, monitor expiry, and work the request queue.',
            actions: [
              if (widget.currentUser.role.canManageInventory)
                FilledButton.icon(
                  onPressed: () => _showAddUnitDialog(context),
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Add unit'),
                ),
            ],
          ),
          const SizedBox(height: TabangSpace.xl),

          // Tabs
          Wrap(
            spacing: TabangSpace.sm,
            runSpacing: TabangSpace.sm,
            children: [
              _tabButton(context, 0, 'Blood units', _repo.units.length),
              _tabButton(context, 1, 'Requests', _repo.requests.length),
              _tabButton(
                context,
                2,
                'Appointments',
                _repo.pendingAppointments.length,
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),

          switch (_tab) {
            0 => _buildUnitsTab(context),
            1 => _buildRequestsTab(context),
            _ => _buildAppointmentsTab(context),
          },
        ],
      ),
    );
  }

  Widget _tabButton(BuildContext context, int index, String label, int count) {
    final selected = _tab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(TabangRadius.sm),
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TabangSpace.lg,
          vertical: TabangSpace.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? TabangColors.crimson : context.surface,
          borderRadius: BorderRadius.circular(TabangRadius.sm),
          border: Border.all(
            color: selected ? TabangColors.crimson : context.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : context.textColor,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : context.surfaceAlt,
                borderRadius: BorderRadius.circular(TabangRadius.pill),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : context.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitsTab(BuildContext context) {
    final units = _units;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: TabangSpace.md,
          runSpacing: TabangSpace.md,
          children: [
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<BloodType?>(
                initialValue: _typeFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Blood type',
                  isDense: true,
                ),
                style: TextStyle(fontSize: 12.5, color: context.textColor),
                items: [
                  const DropdownMenuItem<BloodType?>(
                    value: null,
                    child: Text('All types'),
                  ),
                  ...BloodType.values.map(
                    (t) => DropdownMenuItem<BloodType?>(
                      value: t,
                      child: Text(t.label),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _typeFilter = v),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<UnitStatus?>(
                initialValue: _statusFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  isDense: true,
                ),
                style: TextStyle(fontSize: 12.5, color: context.textColor),
                items: [
                  const DropdownMenuItem<UnitStatus?>(
                    value: null,
                    child: Text('All statuses'),
                  ),
                  ...UnitStatus.values.map(
                    (s) => DropdownMenuItem<UnitStatus?>(
                      value: s,
                      child: Text(s.label),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _statusFilter = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: TabangSpace.lg),
        if (units.isEmpty)
          const EmptyState(
            art: TabangArt.inventory,
            title: 'No units match these filters',
          )
        else
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < units.length; i++)
                  _buildUnitRow(context, units[i], now, first: i == 0),
              ],
            ),
          ),
      ],
    );
  }

  /// One inventory row. The list shows only what staff scan for — product,
  /// ID, expiry and status. Selecting the row opens the full record, including
  /// the barcode graphic and the name of the person holding the unit.
  Widget _buildUnitRow(
    BuildContext context,
    BloodUnit unit,
    DateTime now, {
    required bool first,
  }) {
    final days = unit.daysUntilExpiry(now);
    final effective = unit.effectiveStatus(now);
    final expiring = days >= 0 && days <= 5 && unit.isUsableAt(now);
    final holder = unit.reservedBy == null
        ? null
        : _repo.userById(unit.reservedBy!);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: context.border)),
      ),
      child: InkWell(
        onTap: () => _showUnitDetails(context, unit, now),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TabangSpace.lg,
            vertical: TabangSpace.md,
          ),
          child: Row(
            children: [
              BloodTypeChip(unit.bloodType, size: 32),
              const SizedBox(width: TabangSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.product,
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
                      'ID ${unit.barcode}'
                      '${holder == null ? '' : ' · held by ${holder.alias}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TabangSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    unit.timeLeft(now),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: expiring ? FontWeight.w700 : FontWeight.w600,
                      color: expiring ? TabangColors.danger : context.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusPill(
                    effective.label,
                    tone: toneForUnit(effective),
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(width: 4),
              PopupMenuButton<UnitStatus>(
                tooltip: 'Change status',
                icon: Icon(
                  Icons.more_horiz,
                  size: 18,
                  color: context.textMuted,
                ),
                onSelected: (status) => _repo.setUnitStatus(
                  unit.barcode,
                  status,
                  actorId: widget.currentUser.id,
                ),
                itemBuilder: (context) => UnitStatus.values
                    .where(
                      (s) =>
                          s != effective &&
                          !(s == UnitStatus.available && unit.isExpiredAt(now)),
                    )
                    .map(
                      (s) => PopupMenuItem(
                        value: s,
                        child: Text(
                          'Mark ${s.label.toLowerCase()}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnitDetails(BuildContext context, BloodUnit unit, DateTime now) {
    final effective = unit.effectiveStatus(now);
    final holder = unit.reservedBy == null
        ? null
        : _repo.userById(unit.reservedBy!);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            BloodTypeChip(unit.bloodType, size: 32),
            const SizedBox(width: TabangSpace.md),
            const Expanded(child: Text('Unit details')),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(TabangSpace.md),
                  decoration: BoxDecoration(
                    color: dialogContext.surfaceAlt,
                    borderRadius: BorderRadius.circular(TabangRadius.sm),
                  ),
                  child: UnitBarcode(unit.barcode),
                ),
                const SizedBox(height: TabangSpace.lg),
                _detail(dialogContext, 'Component', unit.product),
                _detail(dialogContext, 'Status', effective.label),
                _detail(dialogContext, 'Storage', unit.storageBay),
                _detail(
                  dialogContext,
                  'Collected',
                  formatDate(unit.collectedOn),
                ),
                _detail(dialogContext, 'Expires', formatDate(unit.expiresOn)),
                _detail(dialogContext, 'Remaining', unit.timeLeft(now)),
                _detail(
                  dialogContext,
                  'Reserved by',
                  holder == null
                      ? 'No one — available for allocation'
                      : '${holder.alias} (${holder.role.label})',
                ),
                if (unit.reservedAt != null)
                  _detail(
                    dialogContext,
                    'Hold placed',
                    formatDateTime(unit.reservedAt!),
                  ),
                if (unit.reservationNote != null &&
                    unit.reservationNote!.isNotEmpty)
                  _detail(dialogContext, 'Hold note', unit.reservationNote!),
              ],
            ),
          ),
        ),
        actions: [
          if (widget.currentUser.role.canManageInventory &&
              unit.reservedBy != null)
            TextButton(
              onPressed: () {
                final ok = _repo.releaseUnit(
                  unit.barcode,
                  actorId: widget.currentUser.id,
                );
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? '${unit.barcode} released back to available stock.'
                          : 'Could not release ${unit.barcode}.',
                    ),
                  ),
                );
              },
              child: const Text('Release to stock'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  Widget _buildRequestsTab(BuildContext context) {
    final requests = _repo.requests;

    if (requests.isEmpty) {
      return const EmptyState(
        art: TabangArt.requests,
        title: 'No requests in the queue',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fulfilment is staff-only. Donor responses are offers; the '
          'requester selects a donor in the community app, and staff mark the '
          'request fulfilled after the donation is recorded.',
          style: TextStyle(fontSize: 12, height: 1.5, color: context.textMuted),
        ),
        const SizedBox(height: TabangSpace.md),
        ...requests.map((request) {
          final compatibleDonors = _repo
              .findDonors(
                compatibleWith: request.bloodType,
                component: request.component,
              )
              .length;
          final compatibleUnits = _repo
              .compatibleUnitsFor(
                recipientType: request.bloodType,
                component: request.component,
              )
              .length;
          final responses = _repo.responsesFor(request.id);
          final selected = responses
              .where((r) => r.status == ResponseStatus.selected)
              .length;
          final requester = _repo.userById(request.requesterId);

          void updateStatus(RequestStatus status) {
            final ok = switch (status) {
              RequestStatus.fulfilled => _repo.markRequestFulfilled(
                request.id,
                actorId: widget.currentUser.id,
              ),
              RequestStatus.cancelled => _repo.cancelRequest(
                request.id,
                actorId: widget.currentUser.id,
              ),
              RequestStatus.matched || RequestStatus.open => false,
            };
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ok
                      ? 'Request ${request.id} marked ${status.label.toLowerCase()}.'
                      : 'Could not update ${request.id}.',
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: TabangSpace.md),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BloodTypeChip(request.bloodType, size: 34),
                      const SizedBox(width: TabangSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // One pill, one title. Three stacked pills beside
                            // every request made the staff queue read as noise;
                            // status and source now sit in the sentence below.
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    request.patientAlias,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                      color: context.textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                StatusPill(
                                  request.urgency.label,
                                  tone: toneForUrgency(request.urgency),
                                  dense: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${request.component.label} · '
                              '${request.unitsOutstanding} of '
                              '${request.unitsNeeded} units outstanding · '
                              '${request.hospital}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: context.textMuted,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${request.status.label} · '
                              '${request.source == RequestSource.bloodBank ? 'Blood bank' : 'Donor network'}'
                              ' · posted by ${requester?.alias ?? 'unknown'}'
                              ' · ${request.barangay}'
                              ' · ${formatRelative(request.createdAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textMuted,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              request.source == RequestSource.bloodBank
                                  ? '$compatibleUnits compatible units in '
                                        'stock · ${responses.length} donor '
                                        'responses'
                                  : '$compatibleDonors eligible compatible '
                                        'donors · ${responses.length} responses '
                                        '($selected selected)',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textMuted,
                              ),
                            ),
                            if (responses.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Responders: '
                                '${responses.map((r) => r.donorAlias).join(', ')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.currentUser.role.canFulfillRequests &&
                          request.source == RequestSource.donorNetwork &&
                          request.status == RequestStatus.open &&
                          responses.any(
                            (r) => r.status == ResponseStatus.pending,
                          ))
                        IconButton(
                          tooltip: 'Select donor',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.how_to_reg_outlined,
                            size: 17,
                            color: context.textMuted,
                          ),
                          onPressed: () => _showSelectDonor(context, request),
                        ),
                      if (request.status == RequestStatus.open ||
                          request.status == RequestStatus.matched)
                        PopupMenuButton<RequestStatus>(
                          tooltip: 'Update request',
                          icon: Icon(
                            Icons.more_vert,
                            size: 17,
                            color: context.textMuted,
                          ),
                          onSelected: updateStatus,
                          itemBuilder: (context) => [
                            if (request.status == RequestStatus.matched ||
                                request.source == RequestSource.bloodBank)
                              const PopupMenuItem(
                                value: RequestStatus.fulfilled,
                                child: Text(
                                  'Mark fulfilled (staff only)',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            const PopupMenuItem(
                              value: RequestStatus.cancelled,
                              child: Text(
                                'Cancel request',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (request.unitsNeeded > 1) ...[
                    const SizedBox(height: TabangSpace.md),
                    ProportionBar(
                      value: request.unitsFulfilled.toDouble(),
                      max: request.unitsNeeded.toDouble(),
                      color: TabangColors.success,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Confirm and track appointment-with-blood slots. This queue used to be
  /// invisible on the staff side even though requesters could book.
  Widget _buildAppointmentsTab(BuildContext context) {
    final appointments = _repo.appointments;
    if (appointments.isEmpty) {
      return const EmptyState(
        art: TabangArt.inventory,
        title: 'No appointments booked',
      );
    }
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < appointments.length; i++)
            _buildAppointmentRow(context, appointments[i], first: i == 0),
        ],
      ),
    );
  }

  Widget _buildAppointmentRow(
    BuildContext context,
    DonationAppointment appointment, {
    required bool first,
  }) {
    final requester = _repo.userById(appointment.requesterId);
    final pending = appointment.status.toLowerCase().contains('pending');
    return DecoratedBox(
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: context.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TabangSpace.lg,
          vertical: TabangSpace.md,
        ),
        child: Row(
          children: [
            BloodTypeChip(appointment.bloodType, size: 32),
            const SizedBox(width: TabangSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.patientName,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.textColor,
                    ),
                  ),
                  Text(
                    '${appointment.hospital} · ${appointment.ward} · '
                    '${appointment.component.label} · ${appointment.units} unit(s)',
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                  Text(
                    '${formatDateTime(appointment.scheduledAt)}'
                    '${requester == null ? '' : ' · booked by ${requester.alias}'}',
                    style: TextStyle(fontSize: 11.5, color: context.textMuted),
                  ),
                ],
              ),
            ),
            StatusPill(
              appointment.status,
              tone: pending ? Tone.warning : Tone.success,
              dense: true,
            ),
            const SizedBox(width: TabangSpace.sm),
            if (pending && widget.currentUser.role.canConfirmAppointments)
              FilledButton(
                onPressed: () {
                  final ok = _repo.confirmAppointment(
                    appointment.id,
                    actorId: widget.currentUser.id,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? '${appointment.id} confirmed.'
                            : 'Could not confirm ${appointment.id}.',
                      ),
                    ),
                  );
                },
                child: const Text('Confirm'),
              ),
          ],
        ),
      ),
    );
  }

  void _showSelectDonor(BuildContext context, BloodRequest request) {
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
                        selectedById: widget.currentUser.id,
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

  /// Receive a new bag. Expiry is derived from the component shelf life, so
  /// staff cannot enter an impossible date.
  void _showAddUnitDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddUnitDialog(
        actorId: widget.currentUser.id,
        onAdded: (unit) {
          if (unit == null || !context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${unit.barcode} added — expires '
                '${formatDate(unit.expiresOn)}.',
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Dialog that collects a new bag and calls [TabangRepository.addBloodUnit].
class _AddUnitDialog extends StatefulWidget {
  const _AddUnitDialog({required this.actorId, required this.onAdded});

  final String actorId;
  final ValueChanged<BloodUnit?> onAdded;

  @override
  State<_AddUnitDialog> createState() => _AddUnitDialogState();
}

class _AddUnitDialogState extends State<_AddUnitDialog> {
  final TabangRepository _repo = TabangRepository.instance;
  final TextEditingController _bay = TextEditingController();
  final TextEditingController _barcode = TextEditingController();

  BloodType _type = BloodType.oPos;
  BloodComponent _component = BloodComponent.packedRbc;
  DateTime _collected = DateTime.now();

  DateTime get _expires => _collected.add(
    Duration(days: TabangRepository.shelfLifeDays[_component] ?? 42),
  );

  @override
  void dispose() {
    _bay.dispose();
    _barcode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add blood unit'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<BloodType>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Blood type',
                  isDense: true,
                ),
                items: BloodType.values
                    .map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: TabangSpace.md),
              DropdownButtonFormField<BloodComponent>(
                initialValue: _component,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Component',
                  isDense: true,
                ),
                items: BloodComponent.values
                    .map(
                      (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _component = v ?? _component),
              ),
              const SizedBox(height: TabangSpace.md),
              TextField(
                controller: _bay,
                decoration: const InputDecoration(
                  labelText: 'Storage bay',
                  hintText: 'e.g. Fridge A · Shelf 2',
                  isDense: true,
                ),
              ),
              const SizedBox(height: TabangSpace.md),
              TextField(
                controller: _barcode,
                decoration: const InputDecoration(
                  labelText: 'Barcode (optional — generated when blank)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: TabangSpace.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Collected on'),
                subtitle: Text(formatDate(_collected)),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _collected,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 2),
                      ),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _collected = picked);
                  },
                  child: const Text('Change'),
                ),
              ),
              Text(
                'Expires ${formatDate(_expires)} '
                '(${TabangRepository.shelfLifeDays[_component]} days shelf life)',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final unit = _repo.addBloodUnit(
              actorId: widget.actorId,
              bloodType: _type,
              component: _component,
              storageBay: _bay.text,
              collectedOn: _collected,
              barcode: _barcode.text,
            );
            if (unit == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Could not add the unit — check the barcode and that your '
                    'role can manage inventory.',
                  ),
                ),
              );
              return;
            }
            widget.onAdded(unit);
            Navigator.pop(context);
          },
          child: const Text('Add to stock'),
        ),
      ],
    );
  }
}
