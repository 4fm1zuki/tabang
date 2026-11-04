import 'package:flutter/material.dart';

import '../../core/eligibility.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/blood_request_dialog.dart';
import '../../widgets/common.dart';
import '../../widgets/illustrations.dart';

/// Blood bank inventory, reservations and appointment booking.
///
/// Community users get read-only visibility into the public stock, matching the
/// paper's SEIPS "read-only inventory visibility" requirement, but they can
/// place a *hold* on a unit and request a slot. A hold is not a transfusion
/// order: chapter staff confirm release after clinical screening. Staff still
/// dispatch, quarantine and expire units from the admin surface.
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
    final weekend = now.weekday == DateTime.saturday ||
        now.weekday == DateTime.sunday;
    return weekend
        ? now.hour >= 8 && now.hour < 17
        : now.hour >= 8 && now.hour < 20;
  }

  bool get _canRequest => widget.user.role.canRequestBlood;

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
      if (_unitType != null && unit.bloodType != _unitType) return false;
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
    final shortages = _repo.criticalShortageTypes;
    final holds = _repo.reservedUnitsFor(widget.user.id);
    final appointments = _repo.appointmentsFor(widget.user.id);

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Blood Bank',
            subtitle:
                'Live stock at the Davao del Sur chapter, holds and appointment slots.',
            actions: [
              if (_canRequest)
                FilledButton.icon(
                  onPressed: () => _showAppointmentDialog(context),
                  icon: const Icon(Icons.event_available_outlined, size: 17),
                  label: const Text('Book appointment'),
                ),
              if (_canRequest)
                OutlinedButton.icon(
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
          if (holds.isNotEmpty || appointments.isNotEmpty) ...[
            _buildMyActivity(context, holds, appointments),
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
            text: '$labels ${types.length == 1 ? 'has' : 'have'} no units '
                'available in any component. Eligible donors are prioritised '
                'for emergency release.',
          ),
        ],
      ),
      style: TextStyle(
        fontSize: 12.5,
        height: 1.45,
        color: context.textColor,
      ),
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
        border: Border.all(
          color: TabangColors.warning.withValues(alpha: 0.38),
        ),
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
                child: const Icon(Icons.bloodtype,
                    color: Colors.white, size: 20),
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
                  label: const Text('Nearest drive'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- my activity

  Widget _buildMyActivity(
    BuildContext context,
    List<BloodUnit> holds,
    List<DonationAppointment> appointments,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final holdCard = _buildHolds(context, holds);
        final appointmentCard = _buildAppointments(context, appointments);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: holdCard),
              const SizedBox(width: TabangSpace.lg),
              Expanded(child: appointmentCard),
            ],
          );
        }
        return Column(
          children: [
            holdCard,
            if (holds.isNotEmpty && appointments.isNotEmpty)
              const SizedBox(height: TabangSpace.lg),
            appointmentCard,
          ],
        );
      },
    );
  }

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

  Widget _buildAppointments(
    BuildContext context,
    List<DonationAppointment> appointments,
  ) {
    if (appointments.isEmpty) return const SizedBox.shrink();
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(
            'Your appointments',
            trailing: TextButton(
              onPressed: () => _showAppointmentDialog(context),
              child: const Text('New', style: TextStyle(fontSize: 10.5)),
            ),
          ),
          for (final appointment in appointments.take(3))
            Container(
              margin: const EdgeInsets.only(bottom: TabangSpace.sm),
              padding: const EdgeInsets.all(TabangSpace.sm),
              decoration: BoxDecoration(
                color: context.surfaceAlt,
                borderRadius: BorderRadius.circular(TabangRadius.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(TabangRadius.xs),
                      border: Border.all(color: context.border),
                    ),
                    child: const Icon(
                      Icons.event_available_outlined,
                      size: 18,
                      color: TabangColors.crimson,
                    ),
                  ),
                  const SizedBox(width: TabangSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${appointment.patientName} · '
                          '${appointment.bloodType.label} · '
                          '${appointment.units} unit'
                          '${appointment.units == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${appointment.component.label} · '
                          '${formatDateTime(appointment.scheduledAt)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.textMuted,
                          ),
                        ),
                        Text(
                          '${appointment.hospital} · ${appointment.ward}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    appointment.status == 'Confirmed' ? 'Confirmed' : 'Pending',
                    tone: appointment.status == 'Confirmed'
                        ? Tone.success
                        : Tone.warning,
                    dense: true,
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
                  onTap: () => setState(
                    () => _unitType = selected ? null : type,
                  ),
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
                          borderRadius:
                              BorderRadius.circular(TabangRadius.pill),
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
          label: 'Blood type',
          value: _unitType,
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
          onChanged: (v) => setState(() => _unitType = v),
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
        if (_unitType != null ||
            _recipientType != null ||
            _component != null ||
            _status != null)
          TextButton.icon(
            onPressed: () => setState(() {
              _unitType = null;
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
      width: 174,
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
        border: Border.all(
          color: TabangColors.crimson.withValues(alpha: 0.3),
        ),
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
            onPressed: _reserveSelected,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding:
                  const EdgeInsets.symmetric(horizontal: TabangSpace.md),
            ),
            icon: const Icon(Icons.lock_clock_outlined, size: 15),
            label: const Text(
              'Reserve selected',
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

  void _reserveSelected() {
    var reserved = 0;
    for (final barcode in List.of(_selected)) {
      if (_repo.reserveUnit(
        barcode: barcode,
        userId: widget.user.id,
        note: 'Public inventory hold',
      )) {
        reserved++;
      }
    }
    setState(_selected.clear);
    _showSnack(
      reserved == 0
          ? 'Those units are no longer available.'
          : 'Reserved $reserved unit${reserved == 1 ? '' : 's'}. '
              'Chapter staff will confirm release.',
    );
  }

  void _reserveOne(BloodUnit unit) {
    final ok = _repo.reserveUnit(
      barcode: unit.barcode,
      userId: widget.user.id,
      note: 'Public inventory hold',
    );
    _showSnack(
      ok
          ? 'Hold placed on ${unit.barcode}. Staff confirm release after screening.'
          : 'That unit is no longer available.',
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
                _detail(context, 'Collected', formatDate(unit.collectedOn)),
                _detail(context, 'Expires', formatDate(unit.expiresOn)),
                _detail(context, 'Remaining', unit.timeLeft(now)),
                if (unit.reservedBy != null)
                  _detail(
                    context,
                    'Held by',
                    mine
                        ? 'You'
                        : (_repo.userById(unit.reservedBy!)?.alias ??
                            'Another community member'),
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
              icon: const Icon(Icons.lock_clock_outlined, size: 16),
              label: const Text('Reserve unit'),
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

  // ------------------------------------------------------ appointment dialog

  Future<void> _showAppointmentDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _AppointmentDialog(
        user: widget.user,
        initialComponent: _component,
        onBooked: (appointment) {
          _showSnack(
            'Appointment ${appointment.id} requested for '
            '${formatDateTime(appointment.scheduledAt)}. '
            'Chapter staff will confirm the slot.',
          );
        },
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
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: widget.selected
              ? (context.isDark
                  ? TabangColors.crimson.withValues(alpha: 0.18)
                  : TabangColors.crimsonSoft.withValues(alpha: 0.55))
              : _hovered
                  ? context.surfaceAlt
                  : context.surface,
          borderRadius: BorderRadius.circular(TabangRadius.md),
          border: Border.all(
            color: widget.selected ? TabangColors.crimson : context.border,
            width: widget.selected ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(TabangRadius.md),
          onTap: widget.onOpen,
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
                        fontWeight:
                            expiringSoon ? FontWeight.w700 : FontWeight.w600,
                        color: expiringSoon
                            ? TabangColors.danger
                            : context.textMuted,
                      ),
                    ),
                    const Spacer(),
                    if (mine)
                      const StatusPill('Held by you', tone: Tone.brand, dense: true)
                    else if (held)
                      const StatusPill('On hold', tone: Tone.neutral, dense: true),
                  ],
                ),
                const SizedBox(height: TabangSpace.sm),
                Divider(height: 1, color: context.border),
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

/// Appointment-with-blood form.
///
/// Covers every field the checklist requires: blood type, patient name,
/// donation type (component), patient hospital and ward, and the amount of
/// units. The appointment requests a slot and does not allocate a unit by
/// itself; staff confirmation is still required.
class _AppointmentDialog extends StatefulWidget {
  const _AppointmentDialog({
    required this.user,
    required this.onBooked,
    this.initialComponent,
  });

  final AppUser user;
  final BloodComponent? initialComponent;
  final ValueChanged<DonationAppointment> onBooked;

  @override
  State<_AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends State<_AppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _ward = TextEditingController();
  final _note = TextEditingController();

  BloodType? _bloodType;
  BloodComponent? _component;
  String? _hospital;
  int _units = 1;
  DateTime? _date;
  TimeOfDay? _time;
  String? _error;

  @override
  void initState() {
    super.initState();
    _component = widget.initialComponent ?? BloodComponent.packedRbc;
    _hospital = DigosFacilities.names.first;
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day + 1);
    _time = const TimeOfDay(hour: 9, minute: 0);
  }

  @override
  void dispose() {
    _name.dispose();
    _ward.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      helpText: 'Select appointment date',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Select appointment time',
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_bloodType == null) {
      setState(() => _error = 'Select the patient blood type.');
      return;
    }
    if (_date == null || _time == null) {
      setState(() => _error = 'Choose a date and time.');
      return;
    }
    final scheduled = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
    final appointment = TabangRepository.instance.addAppointment(
      requesterId: widget.user.id,
      patientName: _name.text,
      bloodType: _bloodType!,
      component: _component!,
      hospital: _hospital!,
      ward: _ward.text,
      units: _units,
      scheduledAt: scheduled,
      note: _note.text,
    );
    if (appointment == null) {
      setState(() => _error = 'The appointment could not be created.');
      return;
    }
    Navigator.pop(context);
    widget.onBooked(appointment);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Appointment with blood'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Request a slot at the chapter blood bank. Staff confirm the '
                  'appointment; a slot does not guarantee a specific unit.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: TabangSpace.md),
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(TabangSpace.sm),
                    decoration: BoxDecoration(
                      color: context.dangerBg,
                      borderRadius: BorderRadius.circular(TabangRadius.xs),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: TabangColors.danger,
                      ),
                    ),
                  ),
                  const SizedBox(height: TabangSpace.md),
                ],
                // What this dialog actually books, in one sentence. The
                // "appointment with blood" name confused testers into thinking
                // it was a donation slot.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(TabangSpace.md),
                  decoration: BoxDecoration(
                    color: context.surfaceAlt,
                    borderRadius: BorderRadius.circular(TabangRadius.sm),
                  ),
                  child: Text(
                    'Reserve a chapter slot to prepare and release blood for a '
                    'named patient. This is not a donation slot — chapter staff '
                    'confirm it after cross-matching, and the patient\'s real '
                    'name stays visible only to chapter staff.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: context.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: TabangSpace.md),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Patient name',
                    helperText:
                        'As written on the hospital record; visible to '
                        'chapter staff only',
                    prefixIcon: Icon(Icons.person_outline, size: 18),
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Enter the patient name'
                      : null,
                ),
                const SizedBox(height: TabangSpace.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bloodTypeField = DropdownButtonFormField<BloodType>(
                      initialValue: _bloodType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Blood type',
                        prefixIcon: Icon(Icons.water_drop_outlined, size: 18),
                      ),
                      items: BloodType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.label),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _bloodType = v),
                    );
                    final amountField = DropdownButtonFormField<int>(
                      initialValue: _units,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Amount (units)',
                        prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                      ),
                      items: List.generate(
                        10,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('${i + 1} unit${i == 0 ? '' : 's'}'),
                        ),
                      ),
                      onChanged: (v) => setState(() => _units = v ?? 1),
                    );

                    // The dialog is only ~232 px wide on a phone after the
                    // alert insets, so two prefixed dropdowns cannot share a
                    // row without clipping the amount field.
                    if (constraints.maxWidth < 360) {
                      return Column(
                        children: [
                          bloodTypeField,
                          const SizedBox(height: TabangSpace.md),
                          amountField,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: bloodTypeField),
                        const SizedBox(width: TabangSpace.md),
                        Expanded(child: amountField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: TabangSpace.md),
                DropdownButtonFormField<BloodComponent>(
                  initialValue: _component,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Donation type',
                    prefixIcon: Icon(Icons.science_outlined, size: 18),
                  ),
                  items: BloodComponent.values
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.label),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _component = v),
                ),
                const SizedBox(height: TabangSpace.md),
                DropdownButtonFormField<String>(
                  initialValue: _hospital,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Patient hospital / facility',
                    helperText:
                        'Where the patient is confined; the chapter releases '
                        'the units to this facility',
                    prefixIcon: Icon(Icons.local_hospital_outlined, size: 18),
                  ),
                  items: DigosFacilities.names
                      .map((name) => DropdownMenuItem(
                            value: name,
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _hospital = v),
                ),
                const SizedBox(height: TabangSpace.md),
                TextFormField(
                  controller: _ward,
                  decoration: const InputDecoration(
                    labelText: 'Ward / room (optional)',
                    helperText:
                        'Where staff should deliver, e.g. "OB Ward 2". Leave '
                        'blank if it is not assigned yet.',
                    prefixIcon: Icon(Icons.meeting_room_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: TabangSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(TabangRadius.sm),
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            prefixIcon: Icon(Icons.calendar_today, size: 17),
                          ),
                          child: Text(
                            _date == null ? 'Choose date' : formatDate(_date!),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _date == null
                                  ? context.textMuted
                                  : context.textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: TabangSpace.md),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(TabangRadius.sm),
                        onTap: _pickTime,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Time',
                            prefixIcon: Icon(Icons.schedule, size: 17),
                          ),
                          child: Text(
                            _time == null ? 'Choose time' : _time!.format(context),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _time == null
                                  ? context.textMuted
                                  : context.textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TabangSpace.md),
                TextFormField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: Icon(Icons.notes_outlined, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.event_available_outlined, size: 16),
          label: const Text('Request appointment'),
        ),
      ],
    );
  }
}
