import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/barcode.dart';
import '../../widgets/common.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/illustrations.dart';
import '../../widgets/request_document_list.dart';
import '../../widgets/request_review_dialogs.dart';
import '../../widgets/user_record_dialog.dart';
import '../../widgets/tabang_dropdown.dart';

/// Inventory and request management for chapter staff.
///
/// Staff can change a unit's status, see expiry pressure, and work the request
/// queue. The previous build's inventory page was read-only and held a second,
/// divergent copy of the blood unit list.
class InventoryManagementPage extends StatefulWidget {
  const InventoryManagementPage({
    super.key,
    required this.currentUser,
    this.embedded = false,
  });

  final AppUser currentUser;

  /// Embedded inside [OperationsWorkspacePage]: keeps the same tabs and
  /// actions but drops the large duplicate page header.
  final bool embedded;

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
    final units = _repo.units.where((u) {
      if (_typeFilter != null && u.bloodType != _typeFilter) return false;
      if (_statusFilter != null && u.effectiveStatus(now) != _statusFilter) {
        return false;
      }
      return true;
    }).toList();
    // Most recent first: the ledger is a working queue, so the unit collected
    // or registered last belongs at the top instead of at the end of the seed
    // list. `collectedOn` is the only timestamp a unit carries.
    units.sort((a, b) => b.collectedOn.compareTo(a.collectedOn));
    return units;
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return SingleChildScrollView(
      padding: widget.embedded
          ? EdgeInsets.fromLTRB(pad.left, 0, pad.right, pad.bottom)
          : pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.embedded)
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
          if (!widget.embedded) const SizedBox(height: TabangSpace.xl),

          // Tabs. Embedded in the Operations workspace the strip shares a row
          // with "Add unit", so the header is one line instead of a lone
          // right-aligned button sitting above the chips.
          if (widget.embedded)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _tabStrip(context)),
                if (widget.currentUser.role.canManageInventory) ...[
                  const SizedBox(width: TabangSpace.md),
                  FilledButton.icon(
                    onPressed: () => _showAddUnitDialog(context),
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('Add unit'),
                  ),
                ],
              ],
            )
          else
            _tabStrip(context),
          const SizedBox(height: TabangSpace.lg),

          switch (_tab) {
            0 => _buildUnitsTab(context),
            1 => _buildRequestsTab(context),
            2 => _buildBookedSlotsTab(context),
            _ => _buildRemovedUnitsTab(context),
          },
        ],
      ),
    );
  }

  /// The Blood units / Requests / Booked slots / Removed units strip. Rendered
  /// on its own line on a full page, and beside "Add unit" when embedded.
  Widget _tabStrip(BuildContext context) {
    return Wrap(
      spacing: TabangSpace.sm,
      runSpacing: TabangSpace.sm,
      children: [
        _tabButton(context, 0, 'Blood units', _repo.units.length),
        _tabButton(context, 1, 'Requests', _repo.requests.length),
        _tabButton(
          context,
          2,
          'Booked slots',
          _repo.pendingScheduledRequests.length,
        ),
        _tabButton(
          context,
          3,
          'Removed units',
          _repo.removedUnits.where((record) => !record.restored).length,
        ),
      ],
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
        TabangFilterBar(
          filters: [
            TabangDropdown<BloodType?>(
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
            TabangDropdown<UnitStatus?>(
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
          ],
        ),
        const SizedBox(height: TabangSpace.sm),
        // One-line legend so staff and volunteers read the same statuses.
        Text(
          'Available — ready for allocation · Reserved — held for a patient '
          'or verified request · Quarantined — screening or safety hold · '
          'Expired — past shelf life and never usable.',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.45,
            color: context.textMuted,
          ),
        ),
        const SizedBox(height: TabangSpace.md),
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

  /// One inventory row: blood type chip, product, time left and status on the
  /// first line, the unit ID barcode and its holder (when reserved) beneath it,
  /// and the status menu on the right. The barcode graphic, storage bay and
  /// collected date stay behind the row tap in the unit sheet.
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

    final timeLeft = Text(
      unit.timeLeft(now),
      style: TextStyle(
        fontSize: 12,
        fontWeight: expiring ? FontWeight.w700 : FontWeight.w600,
        color: expiring ? TabangColors.danger : context.textMuted,
      ),
    );
    final statusPill = StatusPill(
      effective.label,
      tone: toneForUnit(effective),
      dense: true,
    );
    final menu = PopupMenuButton<UnitStatus>(
      tooltip: 'Change status',
      icon: Icon(Icons.more_horiz, size: 18, color: context.textMuted),
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
    );
    final identity = Column(
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
    );

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // At phone width the chip, product, expiry, status and menu
              // cannot share one line, so expiry and status drop to a second
              // row instead of squeezing the product name.
              if (constraints.maxWidth < 480) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BloodTypeChip(unit.bloodType, size: 32),
                        const SizedBox(width: TabangSpace.md),
                        Expanded(child: identity),
                        menu,
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Wrap rather than Row: a long expiry string and a wide
                    // status pill can still run out of width on the second
                    // line. Tapping the row itself opens the unit's full
                    // record, so the row carries no separate Details button.
                    Wrap(
                      spacing: TabangSpace.sm,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [timeLeft, statusPill],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  BloodTypeChip(unit.bloodType, size: 32),
                  const SizedBox(width: TabangSpace.md),
                  Expanded(child: identity),
                  const SizedBox(width: TabangSpace.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [timeLeft, const SizedBox(height: 4), statusPill],
                  ),
                  const SizedBox(width: 4),
                  menu,
                ],
              );
            },
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
                  formatDateWithAge(unit.collectedOn, now: now),
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
                  TabangSnackBar(
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
          if (widget.currentUser.role.canManageInventory)
            TextButton(
              onPressed: () {
                final ok = _repo.removeBloodUnit(
                  unit.barcode,
                  actorId: widget.currentUser.id,
                );
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  TabangSnackBar(
                    content: Text(
                      ok
                          ? '${unit.barcode} removed from the ledger.'
                          : 'Could not remove ${unit.barcode}.',
                    ),
                    action: ok
                        ? SnackBarAction(
                            label: 'Undo',
                            onPressed: () {
                              final restored = _repo.restoreRemovedUnit(
                                unit.barcode,
                                actorId: widget.currentUser.id,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                TabangSnackBar(
                                  content: Text(
                                    restored
                                        ? '${unit.barcode} restored to stock.'
                                        : 'Could not restore ${unit.barcode}.',
                                  ),
                                ),
                              );
                            },
                          )
                        : null,
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: TabangColors.danger),
              child: const Text('Remove unit'),
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
              RequestStatus.matched ||
              RequestStatus.open ||
              RequestStatus.pendingReview ||
              RequestStatus.rejected => false,
            };
            ScaffoldMessenger.of(context).showSnackBar(
              TabangSnackBar(
                content: Text(
                  ok
                      ? 'Request ${request.id} marked ${status.label.toLowerCase()}.'
                      : 'Could not update ${request.id}.',
                ),
              ),
            );
          }

          // Same card anatomy as the booked-slot queue: identity row, slot
          // row, uploaded files, then the response summary. The two queues
          // describe one record, so they must not read like two products.
          return Padding(
            padding: const EdgeInsets.only(bottom: TabangSpace.md),
            child: SurfaceCard(
              onTap: () => _showRequestDetails(context, request),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BloodTypeChip(request.bloodType, size: 34),
                      const SizedBox(width: TabangSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Wrap, not Row: on a phone the urgency pill is
                            // wider than the space left beside a long alias.
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Text(
                                  request.patientAlias,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    color: context.textColor,
                                  ),
                                ),
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
                              '${request.unitsNeeded} unit'
                              '${request.unitsNeeded == 1 ? '' : 's'} · '
                              '${request.hospital}',
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
                  const SizedBox(height: 6),
                  // Status and the update menu sit on their own row so the
                  // long "Awaiting verification" pill cannot squeeze the
                  // alias column at phone width.
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusPill(
                        request.status.label,
                        tone: toneForRequest(request.status),
                        dense: true,
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
                  const SizedBox(height: TabangSpace.sm),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_available_outlined,
                        size: 15,
                        color: TabangColors.crimson,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          request.scheduledFor == null
                              ? 'No slot booked'
                              : formatDateTime(request.scheduledFor!),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: context.textColor,
                          ),
                        ),
                      ),
                      Text(
                        '${request.id} · ',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textMuted,
                        ),
                      ),
                      UserMention(
                        userId: request.requesterId,
                        fallback: requester?.alias,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (request.documents.isNotEmpty) ...[
                    const SizedBox(height: TabangSpace.sm),
                    RequestDocumentList(
                      documents: request.documents,
                      dense: true,
                    ),
                  ],
                  const SizedBox(height: TabangSpace.sm),
                  Text(
                    '${request.source == RequestSource.bloodBank ? 'Blood bank' : 'Donor network'}'
                    ' · ${request.barangay} · posted '
                    '${formatRelative(request.createdAt)}',
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    request.source == RequestSource.bloodBank
                        ? '$compatibleUnits compatible units in stock · '
                              '${responses.length} donor responses'
                        : '$compatibleDonors eligible compatible donors · '
                              '${responses.length} responses '
                              '($selected selected)',
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                  if (responses.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 3,
                      children: [
                        Text(
                          'Responders:',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textMuted,
                          ),
                        ),
                        for (final response in responses)
                          UserMention(
                            userId: response.donorId,
                            fallback: response.donorAlias,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
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

  /// The full record behind a request or booked-slot row.
  ///
  /// Rows stay a one-glance queue entry; opening one brings up everything the
  /// chapter knows about the request, including every attached file through the
  /// shared [RequestDocumentList] viewer. Staff verification runs from here
  /// through [showVerifyRequestDialog] and [showRejectRequestDialog], and staff
  /// can close the request out with the map's `Mark fulfilled` action — the same
  /// dialogs and action the Operations map uses, so the app keeps one flow.
  /// Both the Requests tab and the Booked-slots tab open this one dialog.
  void _showRequestDetails(BuildContext context, BloodRequest request) {
    final responses = _repo.responsesFor(request.id);
    final selected = responses
        .where((r) => r.status == ResponseStatus.selected)
        .length;
    final requester = _repo.userById(request.requesterId);
    final canReview =
        widget.currentUser.role.canFulfillRequests && request.isAwaitingReview;
    // Same fulfil window as the Operations map: staff close out any request
    // that is no longer in review and has not already reached a terminal
    // state.
    final canFulfil =
        widget.currentUser.role.canFulfillRequests &&
        !request.isAwaitingReview &&
        request.status != RequestStatus.fulfilled &&
        request.status != RequestStatus.rejected &&
        request.status != RequestStatus.cancelled;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            BloodTypeChip(request.bloodType, size: 32),
            const SizedBox(width: TabangSpace.md),
            Expanded(child: Text('Request ${request.id}')),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusPill(
                      request.urgency.label,
                      tone: toneForUrgency(request.urgency),
                      dense: true,
                    ),
                    StatusPill(
                      request.status.label,
                      tone: toneForRequest(request.status),
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: TabangSpace.md),
                _detail(dialogContext, 'Patient', request.patientAlias),
                _detail(
                  dialogContext,
                  'Need',
                  '${request.bloodType.label} · ${request.component.label} · '
                      '${request.unitsNeeded} unit'
                      '${request.unitsNeeded == 1 ? '' : 's'}',
                ),
                _detail(
                  dialogContext,
                  'Urgency',
                  '${request.urgency.label} · ${request.urgency.detail}',
                ),
                _detail(dialogContext, 'Hospital', request.hospital),
                _detail(dialogContext, 'Barangay', request.barangay),
                _detail(dialogContext, 'Source', request.source.label),
                _detail(
                  dialogContext,
                  'Requested',
                  formatDateTime(request.createdAt),
                ),
                _detail(
                  dialogContext,
                  'Requested by',
                  requester?.alias ?? 'Unknown requester',
                ),
                if (request.scheduledFor != null)
                  _detail(
                    dialogContext,
                    'Booked slot',
                    formatDateTime(request.scheduledFor!),
                  ),
                _detail(
                  dialogContext,
                  'Responses',
                  '$selected selected · ${responses.length} total',
                ),
                if (request.assignedUnitIds.isNotEmpty)
                  _detail(
                    dialogContext,
                    'Held units',
                    request.assignedUnitIds.join(', '),
                  ),
                // Always render the shared document list, even when nothing was
                // uploaded: the widget's "No documents attached." line tells
                // staff the verification packet is empty, and every uploaded
                // image opens full size from here — the same viewer the map
                // uses, rather than a bare file name.
                const SizedBox(height: TabangSpace.sm),
                Text(
                  'Attached documents',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: dialogContext.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                RequestDocumentList(
                  documents: request.documents,
                  dense: true,
                ),
                if (request.reviewNote != null &&
                    request.reviewNote!.trim().isNotEmpty)
                  _detail(dialogContext, 'Review note', request.reviewNote!),
                if (request.note != null && request.note!.trim().isNotEmpty)
                  _detail(dialogContext, 'Note', request.note!),
              ],
            ),
          ),
        ),
        actions: [
          if (requester != null)
            TextButton(
              onPressed: () => showUserRecordDialog(dialogContext, requester),
              child: const Text('Requester details'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (canReview) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                showRejectRequestDialog(
                  context,
                  request,
                  actor: widget.currentUser,
                );
              },
              child: const Text('Reject'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                showVerifyRequestDialog(
                  context,
                  request,
                  actor: widget.currentUser,
                );
              },
              child: const Text('Verify and open'),
            ),
          ],
          // The map's fulfil action, under the map's conditions: available
          // whenever staff can fulfil and the request is no longer awaiting
          // review.
          if (canFulfil)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _fulfilRequest(context, request);
              },
              child: const Text('Mark fulfilled'),
            ),
        ],
      ),
    );
  }

  /// Closes out a request once the donation is recorded — the same action the
  /// Operations map offers from its request card.
  void _fulfilRequest(BuildContext context, BloodRequest request) {
    final ok = _repo.markRequestFulfilled(
      request.id,
      actorId: widget.currentUser.id,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      TabangSnackBar(
        content: Text(
          ok
              ? 'Request ${request.id} marked fulfilled.'
              : 'Request ${request.id} cannot be fulfilled yet — a '
                    'donor-network request must be matched first.',
        ),
      ),
    );
  }

  /// The removed-units ledger: every deletion stays visible and reversible.
  Widget _buildRemovedUnitsTab(BuildContext context) {
    final records = _repo.removedUnits;
    if (records.isEmpty) {
      return const EmptyState(
        art: TabangArt.inventory,
        title: 'No removed units',
        message:
            'Bags removed from the ledger appear here, with a restore action.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Every removal is recorded and can be undone. Restoring a bag puts '
          'it back on the shelf at its original expiry; both actions stay in '
          'the activity log.',
          style: TextStyle(fontSize: 12, height: 1.5, color: context.textMuted),
        ),
        const SizedBox(height: TabangSpace.md),
        for (final record in records)
          Padding(
            padding: const EdgeInsets.only(bottom: TabangSpace.md),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BloodTypeChip(record.unit.bloodType, size: 34),
                      const SizedBox(width: TabangSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UnitBarcode(record.unit.barcode),
                            const SizedBox(height: 4),
                            Text(
                              '${record.unit.component.label} · '
                              '${record.unit.storageBay} · expires '
                              '${formatDate(record.unit.expiresOn)}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(
                        record.restored ? 'Restored' : 'Removed',
                        tone: record.restored ? Tone.success : Tone.warning,
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: TabangSpace.sm),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Icon(Icons.history, size: 15, color: context.textMuted),
                      Text(
                        'Removed ${formatDateTime(record.removedAt)} by',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textMuted,
                        ),
                      ),
                      UserMention(
                        userId: record.removedById,
                        fallback: 'chapter staff',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (!record.restored &&
                      widget.currentUser.role.canManageInventory) ...[
                    const SizedBox(height: TabangSpace.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final ok = _repo.restoreRemovedUnit(
                            record.unit.barcode,
                            actorId: widget.currentUser.id,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            TabangSnackBar(
                              content: Text(
                                ok
                                    ? '${record.unit.barcode} restored to stock.'
                                    : 'Could not restore ${record.unit.barcode}; '
                                          'its barcode may already be in use.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.undo, size: 15),
                        label: const Text('Restore to stock'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Booked blood-bank slots now belong to requests.
  ///
  /// The old separate appointment queue duplicated the request record: both
  /// described one scheduled blood need. This view reads the same requests and
  /// confirms a slot when staff verify its request.
  Widget _buildBookedSlotsTab(BuildContext context) {
    final requests = _repo.scheduledRequests;
    if (requests.isEmpty) {
      return const EmptyState(
        art: TabangArt.requests,
        title: 'No booked slots',
        message: 'Requester slots appear here once someone submits a request.',
      );
    }
    final pending = _repo.pendingScheduledRequests.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pending == 0
              ? 'All booked slots are confirmed. Staff verify a request and '
                    'its slot together.'
              : '$pending booked slot${pending == 1 ? '' : 's'} still need '
                    'verification. Opening a request confirms both its files '
                    'and its slot.',
          style: TextStyle(fontSize: 12, height: 1.5, color: context.textMuted),
        ),
        const SizedBox(height: TabangSpace.md),
        for (final request in requests)
          Padding(
            padding: const EdgeInsets.only(bottom: TabangSpace.md),
            child: _buildBookedSlotCard(context, request),
          ),
      ],
    );
  }

  Widget _buildBookedSlotCard(BuildContext context, BloodRequest request) {
    final requester = _repo.userById(request.requesterId);
    final pending = request.status == RequestStatus.pendingReview;
    return SurfaceCard(
      onTap: () => _showRequestDetails(context, request),
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
                    Text(
                      request.patientAlias,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                    Text(
                      '${request.component.label} · '
                      '${request.unitsNeeded} unit'
                      '${request.unitsNeeded == 1 ? '' : 's'} · '
                      '${request.hospital}',
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                  ],
                ),
              ),
              StatusPill(
                pending ? 'Awaiting verification' : 'Slot confirmed',
                tone: pending ? Tone.warning : Tone.success,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.sm),
          Row(
            children: [
              const Icon(
                Icons.event_available_outlined,
                size: 15,
                color: TabangColors.crimson,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  request.scheduledFor == null
                      ? 'No slot booked'
                      : formatDateTime(request.scheduledFor!),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textColor,
                  ),
                ),
              ),
              Text(
                '${request.id} · ',
                style: TextStyle(fontSize: 11, color: context.textMuted),
              ),
              UserMention(
                userId: request.requesterId,
                fallback: requester?.alias,
                style: TextStyle(fontSize: 11, color: context.textMuted),
              ),
            ],
          ),
          if (request.documents.isNotEmpty) ...[
            const SizedBox(height: TabangSpace.sm),
            RequestDocumentList(documents: request.documents, dense: true),
          ],
          // Verification happens in the details, which the row opens: the old
          // inline "Verify slot" button opened the very same dialog while
          // sounding like a lighter action, so it is gone.
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
            TabangSnackBar(
              content: Text(
                '${unit.barcode} added — expires '
                '${formatDate(unit.expiresOn)}.',
              ),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  final removed = _repo.removeBloodUnit(
                    unit.barcode,
                    actorId: widget.currentUser.id,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    TabangSnackBar(
                      content: Text(
                        removed
                            ? '${unit.barcode} removed again.'
                            : 'Could not undo the addition.',
                      ),
                    ),
                  );
                },
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
              TabangDropdown<BloodType>(
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
              TabangDropdown<BloodComponent>(
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
                const TabangSnackBar(
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
