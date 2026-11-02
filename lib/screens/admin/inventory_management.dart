import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
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
      if (_statusFilter != null &&
          u.effectiveStatus(now) != _statusFilter) {
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
          const PageHeader(
            title: 'Inventory & requests',
            subtitle:
                'Manage blood units, monitor expiry, and work the request queue.',
          ),
          const SizedBox(height: TabangSpace.xl),

          // Tabs
          Row(
            children: [
              _tabButton(context, 0, 'Blood units', _repo.units.length),
              const SizedBox(width: TabangSpace.sm),
              _tabButton(context, 1, 'Requests', _repo.requests.length),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),

          if (_tab == 0) _buildUnitsTab(context) else _buildRequestsTab(context),
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
                  fontSize: 9.5,
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
                decoration:
                    const InputDecoration(labelText: 'Blood type', isDense: true),
                style: TextStyle(fontSize: 12.5, color: context.textColor),
                items: [
                  const DropdownMenuItem<BloodType?>(
                      value: null, child: Text('All types')),
                  ...BloodType.values.map((t) => DropdownMenuItem<BloodType?>(
                        value: t,
                        child: Text(t.label),
                      )),
                ],
                onChanged: (v) => setState(() => _typeFilter = v),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<UnitStatus?>(
                initialValue: _statusFilter,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Status', isDense: true),
                style: TextStyle(fontSize: 12.5, color: context.textColor),
                items: [
                  const DropdownMenuItem<UnitStatus?>(
                      value: null, child: Text('All statuses')),
                  ...UnitStatus.values.map((s) => DropdownMenuItem<UnitStatus?>(
                        value: s,
                        child: Text(s.label),
                      )),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TabangSpace.lg,
                    vertical: TabangSpace.md,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaceAlt,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(TabangRadius.md - 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      _head(context, 'BARCODE', 3),
                      _head(context, 'TYPE', 1),
                      _head(context, 'COMPONENT', 3),
                      _head(context, 'STORAGE', 3),
                      _head(context, 'EXPIRES', 2),
                      _head(context, 'STATUS', 2),
                      _head(context, 'ACTION', 2),
                    ],
                  ),
                ),
                ...units.map((unit) {
                  final days = unit.daysUntilExpiry(now);
                  final effective = unit.effectiveStatus(now);
                  final expiring =
                      days >= 0 && days <= 5 && unit.isUsableAt(now);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TabangSpace.lg,
                      vertical: TabangSpace.sm,
                    ),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: context.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            unit.barcode,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: context.textColor,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: BloodTypeChip(unit.bloodType, size: 24),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            unit.product,
                            style: TextStyle(
                                fontSize: 11, color: context.textColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            unit.storageBay,
                            style: TextStyle(
                                fontSize: 10.5, color: context.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            unit.timeLeft(now),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: expiring
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: expiring
                                  ? TabangColors.danger
                                  : context.textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: StatusPill(
                              effective.label,
                              tone: toneForUnit(effective),
                              dense: true,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: PopupMenuButton<UnitStatus>(
                              tooltip: 'Change status',
                              icon: Icon(Icons.more_horiz,
                                  size: 16, color: context.textMuted),
                              onSelected: (status) =>
                                  _repo.setUnitStatus(unit.barcode, status),
                              itemBuilder: (context) => UnitStatus.values
                                  .where((s) =>
                                      s != effective &&
                                      !(s == UnitStatus.available &&
                                          unit.isExpiredAt(now)))
                                  .map((s) => PopupMenuItem(
                                        value: s,
                                        child: Text(
                                          'Mark ${s.label.toLowerCase()}',
                                          style:
                                              const TextStyle(fontSize: 12),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _head(BuildContext context, String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: context.textMuted,
        ),
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
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
            color: context.textMuted,
          ),
        ),
        const SizedBox(height: TabangSpace.md),
        ...requests.map((request) {
          final compatibleDonors = _repo.findDonors(
            compatibleWith: request.bloodType,
            component: request.component,
          ).length;
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
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  request.patientAlias,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: context.textColor,
                                  ),
                                ),
                                StatusPill(
                                  request.urgency.label,
                                  tone: toneForUrgency(request.urgency),
                                  dense: true,
                                ),
                                StatusPill(
                                  request.status.label,
                                  tone: request.status == RequestStatus.open
                                      ? Tone.info
                                      : Tone.neutral,
                                  dense: true,
                                ),
                                StatusPill(
                                  request.source.label,
                                  tone:
                                      request.source == RequestSource.bloodBank
                                          ? Tone.brand
                                          : Tone.neutral,
                                  dense: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${request.component.label} · '
                              '${request.unitsOutstanding} of '
                              '${request.unitsNeeded} units outstanding · '
                              '${request.hospital}',
                              style: TextStyle(
                                  fontSize: 11, color: context.textMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Posted by ${requester?.alias ?? 'unknown'} · '
                              '${request.barangay} · '
                              '${formatRelative(request.createdAt)}',
                              style: TextStyle(
                                  fontSize: 10.5, color: context.textMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              request.source == RequestSource.bloodBank
                                  ? '$compatibleUnits compatible units in '
                                      'stock · ${responses.length} donor '
                                      'responses'
                                  : '$compatibleDonors eligible compatible '
                                      'donors · ${responses.length} responses '
                                      '($selected selected)',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: context.textMuted,
                              ),
                            ),
                            if (responses.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Responders: '
                                '${responses.map((r) => r.donorAlias).join(', ')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (request.status == RequestStatus.open ||
                          request.status == RequestStatus.matched)
                        PopupMenuButton<RequestStatus>(
                          tooltip: 'Update request',
                          icon: Icon(Icons.more_vert,
                              size: 17, color: context.textMuted),
                          onSelected: updateStatus,
                          itemBuilder: (context) => [
                            if (request.status == RequestStatus.matched ||
                                request.source == RequestSource.bloodBank)
                              const PopupMenuItem(
                                value: RequestStatus.fulfilled,
                                child: Text('Mark fulfilled (staff only)',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            const PopupMenuItem(
                              value: RequestStatus.cancelled,
                              child: Text('Cancel request',
                                  style: TextStyle(fontSize: 12)),
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
}
