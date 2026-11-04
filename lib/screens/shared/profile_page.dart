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
  /// 14 days, plasma 28 days). The profile defaults to packed RBC, the most
  /// common donation, and lets the donor check another component.
  BloodComponent _eligibilityComponent = BloodComponent.packedRbc;

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
    final eligibility = EligibilityEngine.evaluate(
      user,
      component: _eligibilityComponent,
    );
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
                            fontSize: 12.5, color: context.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: TextStyle(
                            fontSize: 12.5, color: context.textMuted),
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
            _buildEligibilityCard(context, user, eligibility),
            const SizedBox(height: TabangSpace.lg),
            _buildStatsRow(context, user),
            const SizedBox(height: TabangSpace.lg),
          ],

          _buildDetailsCard(context, user),
          const SizedBox(height: TabangSpace.lg),

          if (isDonor) _buildAvailabilityCard(context, user),
        ],
      ),
    );
  }

  Widget _buildEligibilityCard(
    BuildContext context,
    AppUser user,
    EligibilityResult eligibility,
  ) {
    final tone = toneForEligibility(eligibility);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                eligibility.isEligible
                    ? Icons.check_circle_outline
                    : Icons.schedule,
                size: 17,
                color: tone == Tone.success
                    ? TabangColors.success
                    : tone == Tone.warning
                        ? TabangColors.warning
                        : TabangColors.danger,
              ),
              const SizedBox(width: TabangSpace.sm),
              Text(
                'Donation eligibility',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.textColor,
                ),
              ),
              const Spacer(),
              StatusPill(eligibility.summary, tone: tone),
            ],
          ),
          const SizedBox(height: TabangSpace.md),
          Row(
            children: [
              Text(
                'Donation type',
                style: TextStyle(fontSize: 12.5, color: context.textMuted),
              ),
              const SizedBox(width: TabangSpace.md),
              DropdownButton<BloodComponent>(
                value: _eligibilityComponent,
                isDense: true,
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.textColor,
                ),
                items: BloodComponent.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.label),
                        ))
                    .toList(),
                onChanged: (v) => setState(
                  () => _eligibilityComponent = v ?? _eligibilityComponent,
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.sm),
          if (user.lastDonationDate != null) ...[
            Text(
              'Last donation: ${formatDate(user.lastDonationDate!)}'
              '${user.lastDonationComponent == null ? '' : ' · '
                  '${user.lastDonationComponent!.label}'}',
              style: TextStyle(fontSize: 12.5, color: context.textMuted),
            ),
            const SizedBox(height: 4),
          ],
          if (eligibility.eligibleFrom != null) ...[
            Text(
              'Eligible again from ${formatDate(eligibility.eligibleFrom!)}',
              style: TextStyle(fontSize: 12.5, color: context.textMuted),
            ),
            const SizedBox(height: TabangSpace.sm),
            ProportionBar(
              value: (EligibilityEngine.cooldownFor(_eligibilityComponent) -
                      eligibility.daysRemaining)
                  .clamp(0, EligibilityEngine.cooldownFor(_eligibilityComponent))
                  .toDouble(),
              max: EligibilityEngine.cooldownFor(_eligibilityComponent)
                  .toDouble(),
              color: TabangColors.warning,
            ),
            const SizedBox(height: 4),
            Text(
              '${eligibility.daysRemaining} of '
              '${EligibilityEngine.cooldownFor(_eligibilityComponent)} '
              'cooldown days remaining for '
              '${_eligibilityComponent.label.toLowerCase()}',
              style: TextStyle(fontSize: 11.5, color: context.textMuted),
            ),
          ] else
            Text(
              'You meet every eligibility rule: age, availability, account '
              'standing and donation interval.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: context.textMuted,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, AppUser user) {
    return Row(
      children: [
        Expanded(
          child: MetricTile(
            label: 'Total donations',
            value: '${user.totalDonations}',
            icon: Icons.favorite_outline,
            tone: Tone.brand,
          ),
        ),
        const SizedBox(width: TabangSpace.md),
        Expanded(
          child: MetricTile(
            label: 'Last donated',
            value: user.lastDonationDate == null
                ? '—'
                : formatDate(user.lastDonationDate!),
            icon: Icons.event_outlined,
            tone: Tone.info,
          ),
        ),
        const SizedBox(width: TabangSpace.md),
        Expanded(
          child: MetricTile(
            label: 'Warnings',
            value: '${user.warningCount}',
            icon: Icons.flag_outlined,
            tone: user.warningCount == 0 ? Tone.success : Tone.warning,
          ),
        ),
        const SizedBox(width: TabangSpace.md),
        Expanded(
          child: MetricTile(
            label: 'Blood card',
            value: user.bloodCardVerified ? 'Verified' : 'Pending',
            icon: Icons.badge_outlined,
            tone: user.bloodCardVerified ? Tone.success : Tone.info,
          ),
        ),
      ],
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
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard(BuildContext context, AppUser user) {
    return SurfaceCard(
      child: Row(
        children: [
          Icon(
            user.isAvailable
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 17,
            color: context.textMuted,
          ),
          const SizedBox(width: TabangSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available for donation',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textColor,
                  ),
                ),
                Text(
                  user.isAvailable
                      ? 'You appear in the donor directory when eligible'
                      : 'You are hidden from the donor directory',
                  style: TextStyle(fontSize: 11.5, color: context.textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: user.isAvailable,
            onChanged: (v) => _repo.setDonorAvailability(user.id, v),
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
                      decoration:
                          const InputDecoration(labelText: 'Full name'),
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
                      decoration:
                          const InputDecoration(labelText: 'Contact number'),
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
                          .map((b) =>
                              DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => barangay = v ?? barangay),
                    ),
                    if (user.role == UserRole.donor) ...[
                      const SizedBox(height: TabangSpace.md),
                      DropdownButtonFormField<BloodType>(
                        initialValue: bloodType,
                        decoration:
                            const InputDecoration(labelText: 'Blood type'),
                        items: BloodType.values
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t.label),
                                ))
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
                _repo.updateUser(user.copyWith(
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
                ));
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
