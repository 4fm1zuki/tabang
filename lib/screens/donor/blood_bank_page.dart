import 'package:flutter/material.dart';

import '../../core/eligibility.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/blood_request_dialog.dart';
import '../../widgets/common.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/illustrations.dart';
import '../../widgets/tabang_dropdown.dart';

/// Blood bank inventory, reservations and the blood-request flow.
///
/// Community users get read-only visibility into the public stock, matching the
/// paper's SEIPS "read-only inventory visibility" requirement, but they can
/// place a *hold* on a unit and request a slot. A hold is not a transfusion
/// order: chapter staff confirm release after clinical screening. Staff still
/// dispatch, quarantine and expire units from the admin surface.
///
/// A scheduled blood need is always a *request*: the old "appointment with
/// blood" form duplicated this page, so the booked slot now lives inside the
/// request and staff confirm it during verification.
///
/// The urgent-shortage callout lives here rather than on Discover because it
/// describes this inventory; Discover is for orientation and education.
class BloodBankPage extends StatefulWidget {
  const BloodBankPage({
    super.key,
    required this.user,
    this.onOpenMap,
    this.onOpenRequests,
  });

  final AppUser user;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenRequests;

  @override
  State<BloodBankPage> createState() => _BloodBankPageState();
}

class _BloodBankPageState extends State<BloodBankPage> {
  final TabangRepository _repo = TabangRepository.instance;
  final TextEditingController _searchController = TextEditingController();

  BloodType? _unitType;
  BloodType? _recipientType;
  BloodComponent? _component;
  UnitStatus? _status;
  String _query = '';
  final Set<String> _selected = {};

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
    final weekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    return weekend
        ? now.hour >= 8 && now.hour < 17
        : now.hour >= 8 && now.hour < 20;
  }

  bool get _canRequest => widget.user.role.canRequestBlood;

  bool _matchesUnit(
    BloodUnit unit, {
    required DateTime now,
    BloodType? unitType,
    BloodType? recipientType,
    BloodComponent? component,
    UnitStatus? status,
  }) {
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      final matches =
          unit.barcode.toLowerCase().contains(q) ||
          unit.product.toLowerCase().contains(q) ||
          unit.storageBay.toLowerCase().contains(q);
      if (!matches) return false;
    }
    if (unitType != null && unit.bloodType != unitType) return false;
    if (component != null && unit.component != component) return false;
    if (status != null && unit.effectiveStatus(now) != status) return false;
    if (recipientType != null &&
        !Compatibility.canDonateComponentTo(
          unit.bloodType,
          recipientType,
          unit.component,
        )) {
      return false;
    }
    return true;
  }

  /// Faceted count: the candidate replaces this dropdown's own filter while
  /// the other filters and the search term stay applied.
  int _unitCount({
    BloodType? unitType,
    BloodType? recipientType,
    BloodComponent? component,
    UnitStatus? status,
  }) {
    final now = DateTime.now();
    return _repo.units
        .where(
          (unit) => _matchesUnit(
            unit,
            now: now,
            unitType: unitType,
            recipientType: recipientType,
            component: component,
            status: status,
          ),
        )
        .length;
  }

  List<BloodUnit> get _filtered {
    final now = DateTime.now();
    return _repo.units
        .where(
          (unit) => _matchesUnit(
            unit,
            now: now,
            unitType: _unitType,
            recipientType: _recipientType,
            component: _component,
            status: _status,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final units = _filtered;
    final shortages = _repo.criticalShortageTypes;
    final holds = _repo.reservedUnitsFor(widget.user.id);

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Blood Bank',
            subtitle:
                'Stock at the Davao del Sur chapter, unit holds and '
                'booked request slots.',
            actions: [
              if (_canRequest)
                FilledButton.icon(
                  onPressed: () => showBloodRequestDialog(context, widget.user),
                  // `sos_outlined` renders the letters "SOS" and read as a
                  // typo next to the label; the drop glyph makes the action
                  // unambiguous.
                  icon: const Icon(Icons.bloodtype_outlined, size: 17),
                  label: const Text('Request blood'),
                ),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),
          if (shortages.isNotEmpty) ...[
            _buildShortageBanner(context, shortages),
            const SizedBox(height: TabangSpace.lg),
          ],
          _buildChapterBanner(context),
          const SizedBox(height: TabangSpace.xl),
          if (holds.isNotEmpty) ...[
            _buildHolds(context, holds),
            const SizedBox(height: TabangSpace.xl),
          ],
          _buildStockSummary(context),
          const SizedBox(height: TabangSpace.xl),
          _buildFilters(context),
          const SizedBox(height: TabangSpace.lg),
          SectionLabel(
            'Inventory units',
            trailing: Text(
              '${units.length} of ${_repo.units.length}',
              style: TextStyle(fontSize: 12, color: context.textMuted),
            ),
          ),
          if (_selected.isNotEmpty) ...[
            _buildSelectionBar(context),
            const SizedBox(height: TabangSpace.sm),
          ],
          if (units.isEmpty)
            const EmptyState(
              art: TabangArt.inventory,
              title: 'No units match these filters',
              message: 'Clear a filter or widen the recipient blood type.',
            )
          else
            _buildUnitList(context, units),
          const SizedBox(height: TabangSpace.sm),
          Row(
            children: [
              Icon(Icons.info_outline, size: 13, color: context.textMuted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Holds expire with the unit and are confirmed by chapter '
                  'staff after cross-matching. Selecting a unit never bypasses '
                  'clinical screening.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
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

  // --------------------------------------------------------------- banners

  /// A compact, in-context stock note.
  ///
  /// The previous build opened this page with a large amber "URGENT BLOOD
  /// SHORTAGE" panel, which dominated every visit and duplicated the same
  /// information four times. Shortage data still belongs here (and only here),
  /// but it now reads as one line of operational status with an action.
  Widget _buildShortageBanner(BuildContext context, List<BloodType> types) {
    final labels = types.map((t) => t.label).join(', ');
    final message = Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'No usable units · ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text:
                '$labels ${types.length == 1 ? 'has' : 'have'} no units '
                'available in any component. Eligible donors are prioritised '
                'for emergency release.',
          ),
        ],
      ),
      style: TextStyle(fontSize: 12.5, height: 1.45, color: context.textColor),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        TabangSpace.md,
        TabangSpace.sm,
        TabangSpace.sm,
        TabangSpace.sm,
      ),
      decoration: BoxDecoration(
        color: context.warningBg,
        borderRadius: BorderRadius.circular(TabangRadius.sm),
        border: Border.all(color: TabangColors.warning.withValues(alpha: 0.38)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final icon = Icon(
            Icons.info_outline,
            size: 18,
            color: context.isDark
                ? const Color(0xFFFFD27A)
                : TabangColors.warning,
          );
          final action = TextButton.icon(
            onPressed: widget.onOpenMap,
            icon: const Icon(Icons.map_outlined, size: 16),
            label: const Text('Find donors'),
          );
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: icon,
                    ),
                    const SizedBox(width: TabangSpace.sm),
                    Expanded(child: message),
                  ],
                ),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }
          return Row(
            children: [
              icon,
              const SizedBox(width: TabangSpace.sm),
              Expanded(child: message),
              const SizedBox(width: TabangSpace.sm),
              action,
            ],
          );
        },
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
                  gradient: TabangGradients.brand,
                  borderRadius: BorderRadius.circular(TabangRadius.sm),
                ),
                child: const Icon(
                  Icons.bloodtype,
                  color: Colors.white,
                  size: 20,
                ),
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
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Weekdays 8:00 AM – 8:00 PM · Weekends 8:00 AM – 5:00 PM',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.textMuted,
                      ),
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
          Wrap(
            spacing: TabangSpace.sm,
            runSpacing: TabangSpace.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showCompatibilitySheet(context),
                icon: const Icon(Icons.compare_arrows, size: 16),
                label: const Text('Compatibility chart'),
              ),
              // Booking lives once, in the page header. Repeating it here made
              // the chapter card look like a second toolbar.
              if (widget.user.role == UserRole.donor)
                OutlinedButton.icon(
                  onPressed: widget.onOpenMap,
                  icon: const Icon(Icons.place_outlined, size: 16),
                  label: const Text('View drives on map'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- my activity

  Widget _buildHolds(BuildContext context, List<BloodUnit> holds) {
    if (holds.isEmpty) return const SizedBox.shrink();
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(
            'Your unit holds',
            trailing: StatusPill(
              '${holds.length} active',
              tone: Tone.warning,
              dense: true,
            ),
          ),
          for (final unit in holds)
            Container(
              margin: const EdgeInsets.only(bottom: TabangSpace.sm),
              padding: const EdgeInsets.all(TabangSpace.sm),
              decoration: BoxDecoration(
                color: context.surfaceAlt,
                borderRadius: BorderRadius.circular(TabangRadius.sm),
                border: Border.all(
                  color: TabangColors.gold.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  BloodTypeChip(unit.bloodType, size: 28),
                  const SizedBox(width: TabangSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${unit.product} · ${unit.barcode}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: context.textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${unit.storageBay} · ${unit.timeLeft(DateTime.now())} left',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _repo.cancelReservation(
                        barcode: unit.barcode,
                        userId: widget.user.id,
                      );
                      _showSnack('Hold released for ${unit.barcode}.');
                    },
                    child: const Text(
                      'Release',
                      style: TextStyle(fontSize: 10.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ stock summary

  Widget _buildStockSummary(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = _repo.availableUnits;
        final maxCount = BloodType.values
            .map((type) => available.where((u) => u.bloodType == type).length)
            .fold(1, (a, b) => a > b ? a : b);
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
            final selected = _unitType == type;
            return SizedBox(
              width:
                  (constraints.maxWidth - TabangSpace.md * (columns - 1)) /
                  columns,
              child: SurfaceCard(
                padding: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(TabangRadius.md),
                  onTap: () =>
                      setState(() => _unitType = selected ? null : type),
                  child: Container(
                    padding: const EdgeInsets.all(TabangSpace.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(TabangRadius.md),
                      border: Border.all(
                        color: selected
                            ? TabangColors.crimson
                            : Colors.transparent,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            BloodTypeChip(type, size: 30),
                            const SizedBox(width: TabangSpace.sm),
                            Expanded(
                              child: Text(
                                '$count unit${count == 1 ? '' : 's'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.textColor,
                                ),
                              ),
                            ),
                            Container(
                              width: 7,
                              height: 7,
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
                        const SizedBox(height: 6),
                        Text(
                          count == 0
                              ? 'Out of stock'
                              : count <= 1
                              ? 'Low stock'
                              : 'Available',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            TabangRadius.pill,
                          ),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            value: maxCount == 0 ? 0 : count / maxCount,
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
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFilters(BuildContext context) {
    final hasFilters =
        _unitType != null ||
        _recipientType != null ||
        _component != null ||
        _status != null;
    return TabangFilterBar(
      search: TextField(
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
      trailing: hasFilters
          ? TextButton.icon(
              onPressed: () => setState(() {
                _unitType = null;
                _recipientType = null;
                _component = null;
                _status = null;
              }),
              icon: const Icon(Icons.filter_alt_off, size: 15),
              label: const Text('Clear'),
            )
          : null,
      filters: [
        _dropdown<BloodType?>(
          context,
          label: 'Blood type',
          value: _unitType,
          items: [
            const DropdownMenuItem<BloodType?>(
              value: null,
              child: Text('All types'),
            ),
            ...BloodType.values.map(
              (t) =>
                  DropdownMenuItem<BloodType?>(value: t, child: Text(t.label)),
            ),
          ],
          onChanged: (v) => setState(() => _unitType = v),
          countFor: (value) => _unitCount(
            unitType: value,
            recipientType: _recipientType,
            component: _component,
            status: _status,
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
          countFor: (value) => _unitCount(
            unitType: _unitType,
            recipientType: value,
            component: _component,
            status: _status,
          ),
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
          countFor: (value) => _unitCount(
            unitType: _unitType,
            recipientType: _recipientType,
            component: value,
            status: _status,
          ),
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
              (s) =>
                  DropdownMenuItem<UnitStatus?>(value: s, child: Text(s.label)),
            ),
          ],
          onChanged: (v) => setState(() => _status = v),
          countFor: (value) => _unitCount(
            unitType: _unitType,
            recipientType: _recipientType,
            component: _component,
            status: value,
          ),
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
    int? Function(T? value)? countFor,
  }) {
    return TabangDropdown<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      style: TextStyle(fontSize: 12.5, color: context.textColor),
      items: items,
      onChanged: onChanged,
      countFor: countFor,
    );
  }

  // --------------------------------------------------------------- selection

  Widget _buildSelectionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TabangSpace.md,
        vertical: TabangSpace.sm,
      ),
      decoration: BoxDecoration(
        color: context.isDark
            ? TabangColors.crimson.withValues(alpha: 0.16)
            : TabangColors.crimsonSoft,
        borderRadius: BorderRadius.circular(TabangRadius.sm),
        border: Border.all(color: TabangColors.crimson.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 440;
          final label = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 16,
                color: TabangColors.crimson,
              ),
              const SizedBox(width: 6),
              Text(
                '${_selected.length} unit'
                '${_selected.length == 1 ? '' : 's'} selected',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.textColor,
                ),
              ),
            ],
          );
          final clearButton = TextButton(
            onPressed: () => setState(_selected.clear),
            child: const Text('Clear', style: TextStyle(fontSize: 11)),
          );
          final reserveButton = FilledButton.icon(
            onPressed: _requestSelected,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: TabangSpace.md),
            ),
            icon: const Icon(Icons.assignment_outlined, size: 15),
            label: const Text(
              'Request this unit',
              style: TextStyle(fontSize: 11.5),
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [clearButton, reserveButton],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: label),
              clearButton,
              const SizedBox(width: 4),
              reserveButton,
            ],
          );
        },
      ),
    );
  }

  /// Reserving is a request, not a one-tap hold.
  ///
  /// The selected unit only seeds the request dialog with its component and
  /// blood type; chapter staff verify the documents and place the hold when
  /// they approve the request.
  void _requestSelected() {
    final selected = List<String>.of(_selected);
    if (selected.isEmpty) return;
    final unit = _repo.units.firstWhere(
      (candidate) => candidate.barcode == selected.first,
      orElse: () => _repo.units.first,
    );
    setState(_selected.clear);
    showBloodRequestDialog(
      context,
      widget.user,
      initialComponent: unit.component,
      initialBloodType: unit.bloodType,
    );
  }

  void _reserveOne(BloodUnit unit) {
    showBloodRequestDialog(
      context,
      widget.user,
      initialComponent: unit.component,
      initialBloodType: unit.bloodType,
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(TabangSnackBar(content: Text(message)));
  }

  // --------------------------------------------------------------- unit list

  /// Responsive card list instead of a 981 px data table.
  ///
  /// The old table pushed the hold/reserve column off-screen on anything
  /// narrower than a desktop and forced horizontal scrolling to find it. Cards
  /// reflow into one, two or three columns and keep the action next to the
  /// unit it belongs to.
  Widget _buildUnitList(BuildContext context, List<BloodUnit> units) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = TabangSpace.lg;
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 660
            ? 2
            : 1;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final unit in units)
              SizedBox(
                width: cardWidth,
                child: _UnitCard(
                  unit: unit,
                  userId: widget.user.id,
                  selected: _selected.contains(unit.barcode),
                  onToggleSelected: () {
                    setState(() {
                      if (!_selected.add(unit.barcode)) {
                        _selected.remove(unit.barcode);
                      }
                    });
                  },
                  onOpen: () => _showUnitDialog(context, unit),
                  onReserve: () => _reserveOne(unit),
                  onRelease: () {
                    _repo.cancelReservation(
                      barcode: unit.barcode,
                      userId: widget.user.id,
                    );
                    _showSnack('Hold released for ${unit.barcode}.');
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void _showUnitDialog(BuildContext context, BloodUnit unit) {
    final now = DateTime.now();
    final effective = unit.effectiveStatus(now);
    final mine = unit.reservedBy == widget.user.id;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: TabangSpace.md,
                    vertical: TabangSpace.sm,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaceAlt,
                    borderRadius: BorderRadius.circular(TabangRadius.xs),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UNIT ID',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        unit.barcode,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          fontFamily: 'monospace',
                          color: context.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: TabangSpace.md),
                _detail(context, 'Component', unit.product),
                _detail(context, 'Status', effective.label),
                _detail(context, 'Storage', unit.storageBay),
                _detail(
                  context,
                  'Collected',
                  formatDateWithAge(unit.collectedOn, now: now),
                ),
                _detail(context, 'Expires', formatDate(unit.expiresOn)),
                _detail(context, 'Remaining', unit.timeLeft(now)),
                if (unit.reservedBy != null)
                  _detail(
                    context,
                    'Held by',
                    // Who holds a bag is operational information; community
                    // members only ever see their own holds.
                    mine
                        ? 'Held for you'
                        : 'Another member — identity kept private',
                  ),
                if (unit.reservedAt != null)
                  _detail(
                    context,
                    'Hold placed',
                    formatDateTime(unit.reservedAt!),
                  ),
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
                  '• A hold does not reserve a specific transfusion slot',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.6,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (mine)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _repo.cancelReservation(
                  barcode: unit.barcode,
                  userId: widget.user.id,
                );
                _showSnack('Hold released for ${unit.barcode}.');
              },
              icon: const Icon(Icons.lock_open_outlined, size: 16),
              label: const Text('Release hold'),
            )
          else if (effective == UnitStatus.available && unit.isUsableAt(now))
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _reserveOne(unit);
              },
              icon: const Icon(Icons.assignment_outlined, size: 16),
              label: const Text('Request this unit'),
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
            width: 96,
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

  // ------------------------------------------------------ compatibility sheet

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
                  TabangDropdown<BloodComponent>(
                    initialValue: component,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Component'),
                    items: BloodComponent.values
                        .map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.label)),
                        )
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
                  // Column captions: the left arrow alone read as "this
                  // recipient gives to these donors", the opposite of the
                  // rule the rows encode. The two labels make the direction
                  // explicit without repeating it on every row.
                  Row(
                    children: [
                      Text(
                        'Recipient',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: context.textMuted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Can receive from',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
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
                          Tooltip(
                            message:
                                'These donor types can give to '
                                '${recipient.label}',
                            child: Icon(
                              Icons.arrow_back,
                              size: 13,
                              color: context.textMuted,
                            ),
                          ),
                          const SizedBox(width: TabangSpace.md),
                          Expanded(
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: donors
                                  .map(
                                    (d) => StatusPill(
                                      d.label,
                                      tone: Tone.neutral,
                                      dense: true,
                                    ),
                                  )
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
}

/// One inventory row. Kept stateful so a real pointer hover can highlight the
/// row; the public inventory used to be a flat, unresponsive table.
/// One unit in the public list: identity, status, expiry, hold.
///
/// The full record — including the barcode graphic and who holds the unit —
/// opens in the details dialog, so the list itself stays scannable. This is
/// the public catalogue; the administrative inventory keeps the barcode
/// rendering.
class _UnitCard extends StatefulWidget {
  const _UnitCard({
    required this.unit,
    required this.userId,
    required this.selected,
    required this.onToggleSelected,
    required this.onOpen,
    required this.onReserve,
    required this.onRelease,
  });

  final BloodUnit unit;
  final String userId;
  final bool selected;
  final VoidCallback onToggleSelected;
  final VoidCallback onOpen;
  final VoidCallback onReserve;
  final VoidCallback onRelease;

  @override
  State<_UnitCard> createState() => _UnitCardState();
}

class _UnitCardState extends State<_UnitCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final now = DateTime.now();
    final effective = unit.effectiveStatus(now);
    final days = unit.daysUntilExpiry(now);
    final expiringSoon = days >= 0 && days <= 5 && unit.isUsableAt(now);
    final mine = unit.reservedBy == widget.userId;
    final held = unit.reservedBy != null && !mine;
    final selectable = effective == UnitStatus.available || widget.selected;

    return MouseRegion(
      key: ValueKey('unitCard-${unit.barcode}'),
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: widget.selected
              ? (context.isDark
                    ? TabangColors.crimson.withValues(alpha: 0.18)
                    : TabangColors.crimsonSoft.withValues(alpha: 0.55))
              : _pressed
              ? Color.alphaBlend(
                  TabangColors.crimson.withValues(alpha: 0.06),
                  context.surfaceAlt,
                )
              : _hovered
              ? context.surfaceAlt
              : context.surface,
          borderRadius: BorderRadius.circular(TabangRadius.md),
          border: Border.all(
            color: widget.selected
                ? TabangColors.crimson
                : _pressed
                ? TabangColors.crimson.withValues(alpha: 0.55)
                : _hovered
                ? TabangColors.crimson.withValues(alpha: 0.35)
                : context.border,
            width: widget.selected
                ? 1.6
                : (_pressed || _hovered)
                ? 1.2
                : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(TabangRadius.md),
            onTap: widget.onOpen,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            // The wash is painted by the AnimatedContainer above, so the ink
            // layer only adds the press ripple. Leaving InkWell's default hover
            // tint on top both double-tinted the surface and washed out the
            // footer divider.
            hoverColor: Colors.transparent,
            splashColor: TabangColors.crimson.withValues(
              alpha: context.isDark ? 0.16 : 0.08,
            ),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(TabangSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BloodTypeChip(unit.bloodType, size: 38),
                      const SizedBox(width: TabangSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unit.product,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                                color: context.textColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              unit.storageBay,
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
                      const SizedBox(width: 6),
                      StatusPill(
                        effective.label,
                        tone: toneForUnit(effective),
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: TabangSpace.md),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: expiringSoon
                            ? TabangColors.danger
                            : context.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        unit.timeLeft(now),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: expiringSoon
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: expiringSoon
                              ? TabangColors.danger
                              : context.textMuted,
                        ),
                      ),
                      const Spacer(),
                      if (mine)
                        const StatusPill(
                          'Held by you',
                          tone: Tone.brand,
                          dense: true,
                        )
                      else if (held)
                        const StatusPill(
                          'On hold',
                          tone: Tone.neutral,
                          dense: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: TabangSpace.sm),
                  Divider(
                    height: 1,
                    // On the hover/press wash the regular border colour sits
                    // almost exactly on the tinted surface and the line looks
                    // gone. A stronger muted tone keeps the footer separation
                    // visible in every card state.
                    color: widget.selected || _hovered || _pressed
                        ? context.textMuted.withValues(alpha: 0.32)
                        : context.border,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(TabangRadius.xs),
                        onTap: selectable ? widget.onToggleSelected : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: widget.selected,
                                  onChanged: selectable
                                      ? (_) => widget.onToggleSelected()
                                      : null,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Select',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: selectable
                                      ? context.textColor
                                      : context.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      _buildAction(
                        context,
                        effective: effective,
                        mine: mine,
                        held: held,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAction(
    BuildContext context, {
    required UnitStatus effective,
    required bool mine,
    required bool held,
  }) {
    if (mine) {
      return TextButton(
        onPressed: widget.onRelease,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('Cancel hold', style: TextStyle(fontSize: 12.5)),
      );
    }
    if (held) {
      return Tooltip(
        message: 'Another community member has a hold on this unit',
        child: Text(
          'On hold',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: context.textMuted,
          ),
        ),
      );
    }
    if (effective == UnitStatus.available) {
      return OutlinedButton(
        onPressed: widget.onReserve,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('Reserve', style: TextStyle(fontSize: 12.5)),
      );
    }
    return Text(
      'Unavailable',
      style: TextStyle(fontSize: 12.5, color: context.textMuted),
    );
  }
}
