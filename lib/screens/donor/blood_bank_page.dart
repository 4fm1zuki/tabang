import 'package:flutter/material.dart';

import '../../core/eligibility.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/blood_request_dialog.dart';
import '../../widgets/common.dart';
import '../../widgets/illustrations.dart';

/// Blood bank inventory and request submission.
///
/// The inventory is deliberately **read-only** for community users, matching
/// the paper's SEIPS "read-only inventory visibility" requirement. Chapter staff
/// reserve, dispatch and quarantine units from the admin surface. The
/// compatibility filter is component-aware: plasma uses the reverse ABO rule,
/// while red cells and platelets use the red-cell baseline. Expired units are
/// shown as expired and never counted as available.
class BloodBankPage extends StatefulWidget {
  const BloodBankPage({super.key, required this.user});

  final AppUser user;

  @override
  State<BloodBankPage> createState() => _BloodBankPageState();
}

class _BloodBankPageState extends State<BloodBankPage> {
  final TabangRepository _repo = TabangRepository.instance;
  final TextEditingController _searchController = TextEditingController();

  BloodType? _recipientType;
  BloodComponent? _component;
  UnitStatus? _status;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repo.addListener(_refresh);
  }

  @override
  void dispose() {
    _repo.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Chapter hours: weekdays 8am-8pm, weekends 8am-5pm.
  bool get _isOpenNow {
    final now = DateTime.now();
    final weekend = now.weekday == DateTime.saturday ||
        now.weekday == DateTime.sunday;
    return weekend
        ? now.hour >= 8 && now.hour < 17
        : now.hour >= 8 && now.hour < 20;
  }

  List<BloodUnit> get _filtered {
    final now = DateTime.now();
    return _repo.units.where((unit) {
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final matches = unit.barcode.toLowerCase().contains(q) ||
            unit.product.toLowerCase().contains(q) ||
            unit.storageBay.toLowerCase().contains(q);
        if (!matches) return false;
      }
      if (_component != null && unit.component != _component) return false;
      if (_status != null && unit.effectiveStatus(now) != _status) {
        return false;
      }
      if (_recipientType != null &&
          !Compatibility.canDonateComponentTo(
            unit.bloodType,
            _recipientType!,
            unit.component,
          )) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final units = _filtered;

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChapterBanner(context),
          const SizedBox(height: TabangSpace.xl),
          _buildStockSummary(context),
          const SizedBox(height: TabangSpace.xl),
          _buildFilters(context),
          const SizedBox(height: TabangSpace.lg),
          SectionLabel(
            'Inventory units',
            trailing: Text(
              '${units.length} of ${_repo.units.length}',
              style: TextStyle(fontSize: 11, color: context.textMuted),
            ),
          ),
          if (units.isEmpty)
            const EmptyState(
              art: TabangArt.inventory,
              title: 'No units match these filters',
              message: 'Clear a filter or widen the recipient blood type.',
            )
          else
            _buildUnitTable(context, units),
        ],
      ),
    );
  }

  Widget _buildChapterBanner(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(TabangSpace.sm),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? const Color(0xFF3A1917)
                      : TabangColors.crimsonSoft,
                  borderRadius: BorderRadius.circular(TabangRadius.sm),
                ),
                child: const Icon(Icons.bloodtype,
                    color: TabangColors.crimson, size: 20),
              ),
              const SizedBox(width: TabangSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Philippine Red Cross — Davao del Sur Chapter',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Quezon Avenue, Davao–Cotabato Rd, Digos City',
                      style: TextStyle(fontSize: 11.5, color: context.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Weekdays 8:00 AM – 8:00 PM · Weekends 8:00 AM – 5:00 PM',
                      style: TextStyle(fontSize: 11.5, color: context.textMuted),
                    ),
                  ],
                ),
              ),
              StatusPill(
                _isOpenNow ? 'OPEN NOW' : 'CLOSED NOW',
                tone: _isOpenNow ? Tone.success : Tone.danger,
                icon: Icons.circle,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),
          Row(
            children: [
              if (widget.user.role == UserRole.recipient) ...[
                ElevatedButton.icon(
                  onPressed: () => showBloodRequestDialog(context, widget.user),
                  icon: const Icon(Icons.sos, size: 16),
                  label: const Text('Request blood'),
                ),
                const SizedBox(width: TabangSpace.sm),
              ],
              OutlinedButton.icon(
                onPressed: () => _showCompatibilitySheet(context),
                icon: const Icon(Icons.compare_arrows, size: 16),
                label: const Text('Compatibility chart'),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.md),
          Row(
            children: [
              Icon(Icons.visibility_outlined,
                  size: 13, color: context.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Public inventory is read-only. Chapter staff manage '
                  'reservations, dispatch and expiry.',
                  style: TextStyle(fontSize: 11, color: context.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockSummary(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = _repo.availableUnits;
        // Tiles get narrower on phones; four fixed columns squeezed the count
        // labels to one character per line.
        final columns = constraints.maxWidth < 420
            ? 2
            : constraints.maxWidth < 720
                ? 3
                : constraints.maxWidth < 1100
                    ? 4
                    : 8;
        return Wrap(
          spacing: TabangSpace.md,
          runSpacing: TabangSpace.md,
          children: BloodType.values.map((type) {
            final count = available.where((u) => u.bloodType == type).length;
            final tone = count == 0
                ? Tone.danger
                : count <= 1
                    ? Tone.warning
                    : Tone.success;
            return SizedBox(
              width:
                  (constraints.maxWidth - TabangSpace.md * (columns - 1)) /
                      columns,
              child: SurfaceCard(
                padding: const EdgeInsets.all(TabangSpace.md),
                child: Row(
                  children: [
                    BloodTypeChip(type, size: 32),
                    const SizedBox(width: TabangSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$count unit${count == 1 ? '' : 's'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.textColor,
                            ),
                          ),
                          Text(
                            count == 0
                                ? 'Out of stock'
                                : count <= 1
                                    ? 'Low stock'
                                    : 'Available',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tone == Tone.success
                            ? TabangColors.success
                            : tone == Tone.warning
                                ? TabangColors.warning
                                : TabangColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Wrap(
      spacing: TabangSpace.md,
      runSpacing: TabangSpace.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 230,
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(
              hintText: 'Barcode, product, storage',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 17),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 15),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        _dropdown<BloodType?>(
          context,
          label: 'Recipient type',
          value: _recipientType,
          items: [
            const DropdownMenuItem<BloodType?>(
              value: null,
              child: Text('Any recipient'),
            ),
            ...BloodType.values.map(
              (t) => DropdownMenuItem<BloodType?>(
                value: t,
                child: Text('Recipient ${t.label}'),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _recipientType = v),
        ),
        _dropdown<BloodComponent?>(
          context,
          label: 'Component',
          value: _component,
          items: [
            const DropdownMenuItem<BloodComponent?>(
              value: null,
              child: Text('All components'),
            ),
            ...BloodComponent.values.map(
              (c) => DropdownMenuItem<BloodComponent?>(
                value: c,
                child: Text(c.label),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _component = v),
        ),
        _dropdown<UnitStatus?>(
          context,
          label: 'Status',
          value: _status,
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
          onChanged: (v) => setState(() => _status = v),
        ),
        if (_recipientType != null || _component != null || _status != null)
          TextButton.icon(
            onPressed: () => setState(() {
              _recipientType = null;
              _component = null;
              _status = null;
            }),
            icon: const Icon(Icons.filter_alt_off, size: 15),
            label: const Text('Clear'),
          ),
      ],
    );
  }

  Widget _dropdown<T>(
    BuildContext context, {
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        style: TextStyle(fontSize: 12.5, color: context.textColor),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildUnitTable(BuildContext context, List<BloodUnit> units) {
    final now = DateTime.now();

    return SurfaceCard(
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
                _headCell(context, 'BARCODE', flex: 3),
                _headCell(context, 'TYPE', flex: 1),
                _headCell(context, 'COMPONENT', flex: 3),
                _headCell(context, 'STORAGE', flex: 3),
                _headCell(context, 'EXPIRES', flex: 2),
                _headCell(context, 'STATUS', flex: 2),
              ],
            ),
          ),
          ...units.map((unit) {
            final days = unit.daysUntilExpiry(now);
            final effective = unit.effectiveStatus(now);
            final expiringSoon =
                days >= 0 && days <= 5 && unit.isUsableAt(now);
            return InkWell(
              onTap: () => _showUnitDialog(context, unit),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TabangSpace.lg,
                  vertical: TabangSpace.md,
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
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          color: context.textColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: BloodTypeChip(unit.bloodType, size: 26),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        unit.product,
                        style: TextStyle(
                            fontSize: 11.5, color: context.textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        unit.storageBay,
                        style: TextStyle(
                            fontSize: 11, color: context.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        unit.timeLeft(now),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              expiringSoon ? FontWeight.w700 : FontWeight.w500,
                          color: expiringSoon
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
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _headCell(BuildContext context, String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: context.textMuted,
        ),
      ),
    );
  }

  void _showUnitDialog(BuildContext context, BloodUnit unit) {
    final now = DateTime.now();
    final effective = unit.effectiveStatus(now);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            BloodTypeChip(unit.bloodType, size: 30),
            const SizedBox(width: TabangSpace.md),
            Expanded(
              child: Text(
                unit.barcode,
                style: const TextStyle(fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detail(context, 'Component', unit.product),
              _detail(context, 'Status', effective.label),
              _detail(context, 'Storage', unit.storageBay),
              _detail(context, 'Collected', formatDate(unit.collectedOn)),
              _detail(context, 'Expires', formatDate(unit.expiresOn)),
              _detail(context, 'Remaining', unit.timeLeft(now)),
              const SizedBox(height: TabangSpace.md),
              const Divider(),
              const SizedBox(height: TabangSpace.md),
              Text(
                'Safety & compliance',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• Screened for transfusion-transmitted infections\n'
                '• Cross-match testing required before transfusion\n'
                '• Public inventory is read-only; staff manage reservations',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.6,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: context.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCompatibilitySheet(BuildContext context) {
    var component = _component ?? BloodComponent.packedRbc;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ABO/Rh compatibility'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<BloodComponent>(
                    initialValue: component,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Component',
                    ),
                    items: BloodComponent.values
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.label),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => component = v ?? component),
                  ),
                  const SizedBox(height: TabangSpace.md),
                  Text(
                    component == BloodComponent.plasma
                        ? 'Plasma compatibility is the reverse of red cells: '
                            'AB plasma is the universal plasma donor, and O '
                            'plasma can only go to an O recipient. Rh is not '
                            'used for plasma in this prototype.'
                        : component == BloodComponent.platelets
                            ? 'Platelets use the ABO/Rh red-cell baseline in '
                                'this prototype. ABO-identical units are '
                                'preferred clinically; HLA and antigen-negative '
                                'selection are out of scope.'
                            : 'A recipient can safely receive red cells from '
                                'any donor type listed against them. O- is the '
                                'universal red-cell donor; AB+ is the universal '
                                'recipient.',
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                  const SizedBox(height: TabangSpace.lg),
                  ...BloodType.values.map((recipient) {
                    final donors = Compatibility.donorsForComponent(
                      recipient,
                      component,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: TabangSpace.sm),
                      child: Row(
                        children: [
                          BloodTypeChip(recipient, size: 28),
                          const SizedBox(width: TabangSpace.md),
                          Icon(Icons.arrow_back,
                              size: 13, color: context.textMuted),
                          const SizedBox(width: TabangSpace.md),
                          Expanded(
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: donors
                                  .map((d) => StatusPill(d.label,
                                      tone: Tone.neutral, dense: true))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  /// Blood request form.
  ///
  /// Every field is bound to a controller and validated, and submitting
  /// writes a real [BloodRequest] so it appears on the Requests page and in
  /// the admin queue.
}
