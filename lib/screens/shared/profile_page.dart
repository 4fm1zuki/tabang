import 'package:flutter/material.dart';

import '../../core/eligibility.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/common.dart';

/// Donor / recipient profile.
///
/// Shows the signed-in user's own record: donation history, eligibility
/// status with the live cooldown countdown, and editable contact details.
/// The previous build hardcoded "Iverson D. Briones" for every user.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user});

  final AppUser user;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TabangRepository _repo = TabangRepository.instance;

  /// Eligibility is component-specific (whole blood/RBC 84 days, platelets
  /// 14 days, plasma 28 days). The donor can select several components at once
  /// and see each interval side by side; packed RBC is selected first because
  /// it is the most common donation.
  final Set<BloodComponent> _eligibilityComponents = {BloodComponent.packedRbc};

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

  AppUser get _user => _repo.userById(widget.user.id) ?? widget.user;

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final isDonor = user.role == UserRole.donor;

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Profile',
            subtitle: 'Your account, donation history and eligibility.',
            actions: [
              OutlinedButton.icon(
                onPressed: () => _showEditDialog(context),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Edit profile'),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.xl),

          // Identity card
          SurfaceCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: TabangColors.crimson,
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: TabangSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            user.fullName,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: context.textColor,
                            ),
                          ),
                          const SizedBox(width: TabangSpace.sm),
                          StatusPill(
                            user.status.label,
                            tone: toneForAccount(user.status),
                            dense: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Alias "${user.alias}" · ${user.role.label}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDonor && user.bloodType != null)
                  BloodTypeChip(user.bloodType!, size: 46),
              ],
            ),
          ),
          const SizedBox(height: TabangSpace.lg),

          if (isDonor) ...[
            _buildEligibilityCard(context, user),
            const SizedBox(height: TabangSpace.lg),
            _buildStatsRow(context, user),
            const SizedBox(height: TabangSpace.lg),
          ],

          _buildDetailsCard(context, user),
        ],
      ),
    );
  }

  Widget _buildEligibilityCard(BuildContext context, AppUser user) {
    final results = <BloodComponent, EligibilityResult>{
      for (final component in BloodComponent.values)
        component: EligibilityEngine.evaluate(user, component: component),
    };
    final selected = _eligibilityComponents.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final eligibleCount = selected.where((c) => results[c]!.isEligible).length;
    final allEligible = eligibleCount == selected.length;
    final tone = allEligible
        ? Tone.success
        : eligibleCount == 0
        ? Tone.warning
        : Tone.info;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allEligible ? Icons.check_circle_outline : Icons.schedule,
                size: 17,
                color: allEligible
                    ? TabangColors.success
                    : eligibleCount == 0
                    ? TabangColors.warning
                    : TabangColors.info,
              ),
              const SizedBox(width: TabangSpace.sm),
              Expanded(
                child: Text(
                  'Donation eligibility',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textColor,
                  ),
                ),
              ),
              StatusPill(
                '$eligibleCount of ${selected.length} eligible',
                tone: tone,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.md),
          Text(
            'Donation types',
            style: TextStyle(fontSize: 12.5, color: context.textMuted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final component in BloodComponent.values)
                FilterChip(
                  label: Text(component.label),
                  selected: _eligibilityComponents.contains(component),
                  visualDensity: VisualDensity.compact,
                  onSelected: (on) => setState(() {
                    if (on) {
                      _eligibilityComponents.add(component);
                    } else if (_eligibilityComponents.length > 1) {
                      // Keep at least one type selected: the card is a
                      // comparison, not an empty multi-select.
                      _eligibilityComponents.remove(component);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select every type you want to check. Each has its own cooldown.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: context.textMuted,
            ),
          ),
          if (user.lastDonationDate != null) ...[
            const SizedBox(height: TabangSpace.sm),
            Text(
              'Last donation: ${formatDate(user.lastDonationDate!)}'
              '${user.lastDonationComponent == null ? '' : ' · '
                        '${user.lastDonationComponent!.label}'}',
              style: TextStyle(fontSize: 12.5, color: context.textMuted),
            ),
          ],
          const SizedBox(height: TabangSpace.md),
          for (final component in selected) ...[
            _buildEligibilityRow(context, component, results[component]!),
            if (component != selected.last) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildEligibilityRow(
    BuildContext context,
    BloodComponent component,
    EligibilityResult result,
  ) {
    final tone = toneForEligibility(result);
    final color = tone == Tone.success
        ? TabangColors.success
        : tone == Tone.warning
        ? TabangColors.warning
        : TabangColors.danger;

    return Container(
      padding: const EdgeInsets.all(TabangSpace.sm),
      decoration: BoxDecoration(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(TabangRadius.xs),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.isEligible ? Icons.check_circle_outline : Icons.schedule,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        component.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: context.textColor,
                        ),
                      ),
                    ),
                    StatusPill(result.summary, tone: tone, dense: true),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  result.eligibleFrom != null
                      ? 'Eligible again '
                            '${formatDate(result.eligibleFrom!)} · '
                            '${result.daysRemaining} '
                            'day${result.daysRemaining == 1 ? '' : 's'} left'
                      : 'Meets every rule for this donation type.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Donation summary tiles.
  ///
  /// Four tiles used to be forced into a single Row, which crushed each one to
  /// ~85 px on a phone and clipped the values. They now wrap two-up on
  /// narrow screens and four-up once there is room.
  Widget _buildStatsRow(BuildContext context, AppUser user) {
    final tiles = <Widget>[
      MetricTile(
        label: 'Total donations',
        value: '${user.totalDonations}',
        icon: Icons.favorite_outline,
        tone: Tone.brand,
      ),
      MetricTile(
        label: 'Last donated',
        value: user.lastDonationDate == null
            ? '—'
            : formatDate(user.lastDonationDate!),
        icon: Icons.event_outlined,
        tone: Tone.info,
      ),
      MetricTile(
        label: 'Warnings',
        value: '${user.warningCount}',
        icon: Icons.flag_outlined,
        tone: user.warningCount == 0 ? Tone.success : Tone.warning,
      ),
      MetricTile(
        label: 'Blood card',
        value: user.bloodCardVerified ? 'Verified' : 'Pending',
        icon: Icons.badge_outlined,
        tone: user.bloodCardVerified ? Tone.success : Tone.info,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = TabangSpace.md;
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }

  Widget _buildDetailsCard(BuildContext context, AppUser user) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account details',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: TabangSpace.md),
          _detailRow(context, 'Contact number', user.phone),
          _detailRow(context, 'Barangay', user.barangay),
          if (user.bloodType != null)
            _detailRow(context, 'Blood type', user.bloodType!.label),
          if (user.role == UserRole.donor && user.weightKg != null)
            _detailRow(
              context,
              'Weight',
              '${user.weightKg!.toStringAsFixed(1)} kg',
            ),
          if (user.birthDate != null)
            _detailRow(
              context,
              'Birth date',
              '${formatDate(user.birthDate!)}'
                  '${user.age != null ? ' (${user.age} years)' : ''}',
            ),
          _detailRow(context, 'Registered', formatDate(user.registeredOn)),
          if (user.suspensionReason != null)
            _detailRow(context, 'Suspension reason', user.suspensionReason!),
          const SizedBox(height: TabangSpace.xs),
          Text(
            'Your real name and contact number are shared with another user '
            'only after both of you accept an identity reveal in Messages.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TabangSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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

  void _showEditDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final user = _user;

    final nameController = TextEditingController(text: user.fullName);
    final aliasController = TextEditingController(text: user.alias);
    final phoneController = TextEditingController(text: user.phone);
    final weightController = TextEditingController(
      text: user.weightKg?.toStringAsFixed(1) ?? '',
    );
    var barangay = user.barangay;
    var bloodType = user.bloodType;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit profile'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        helperText:
                            'Shared only after a mutual identity reveal',
                      ),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Enter your full name'
                          : null,
                    ),
                    const SizedBox(height: TabangSpace.md),
                    TextFormField(
                      controller: aliasController,
                      decoration: const InputDecoration(
                        labelText: 'Alias',
                        helperText: 'Shown to other users instead of your name',
                      ),
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? 'Choose an alias'
                          : null,
                    ),
                    const SizedBox(height: TabangSpace.md),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact number',
                        helperText:
                            'Shared only after a mutual identity reveal',
                      ),
                      validator: (v) => (v == null || v.trim().length < 7)
                          ? 'Enter a contact number'
                          : null,
                    ),
                    const SizedBox(height: TabangSpace.md),
                    DropdownButtonFormField<String>(
                      initialValue: barangay,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Barangay'),
                      items: DigosBarangays.all
                          .map(
                            (b) => DropdownMenuItem(value: b, child: Text(b)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => barangay = v ?? barangay),
                    ),
                    if (user.role == UserRole.donor) ...[
                      const SizedBox(height: TabangSpace.md),
                      DropdownButtonFormField<BloodType>(
                        initialValue: bloodType,
                        decoration: const InputDecoration(
                          labelText: 'Blood type',
                        ),
                        items: BloodType.values
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => bloodType = v ?? bloodType),
                      ),
                      const SizedBox(height: TabangSpace.md),
                      TextFormField(
                        controller: weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Weight (kg)',
                          helperText: 'At least 50 kg is required to donate',
                        ),
                        validator: (v) {
                          if (user.role != UserRole.donor) return null;
                          final weight = double.tryParse(v?.trim() ?? '');
                          if (weight == null) return 'Enter your weight';
                          if (weight < 20 || weight > 300) {
                            return 'Enter a weight between 20 and 300 kg';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final typeChanged =
                    user.role == UserRole.donor && bloodType != user.bloodType;
                _repo.updateUser(
                  user.copyWith(
                    fullName: nameController.text.trim(),
                    alias: aliasController.text.trim(),
                    phone: phoneController.text.trim(),
                    barangay: barangay,
                    bloodType: bloodType,
                    weightKg: user.role == UserRole.donor
                        ? double.tryParse(weightController.text.trim())
                        : null,
                    status: typeChanged ? AccountStatus.unverified : null,
                    bloodCardVerified: typeChanged ? false : null,
                  ),
                );
                Navigator.pop(dialogContext);
                if (typeChanged) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Blood type changed. Your blood card must be '
                        're-verified by chapter staff before matching.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
