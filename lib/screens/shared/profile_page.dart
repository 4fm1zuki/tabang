import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/chapter_identity.dart';
import '../../widgets/layout.dart';
import '../../widgets/common.dart';
import '../../widgets/photo.dart';
import '../../widgets/tabang_dropdown.dart';

/// Donor / recipient profile.
///
/// Shows the signed-in user's own record: donation history, eligibility
/// status with the live cooldown countdown, and editable contact details.
/// The previous build hardcoded one demo name for every user.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user});

  final AppUser user;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TabangRepository _repo = TabangRepository.instance;

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
                onPressed: () => _showAvatarPicker(context, user),
                icon: const Icon(Icons.face_outlined, size: 15),
                label: const Text('Change avatar'),
              ),
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
                Tooltip(
                  message: 'Change profile photo',
                  child: InkWell(
                    onTap: () => _showAvatarPicker(context, user),
                    borderRadius: BorderRadius.circular(34),
                    child: Stack(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: TabangPhoto(
                              user.photoAsset,
                              semanticLabel: '${user.alias} profile photo',
                              creditLabel: user.alias,
                              fallbackIcon: Icons.person_outline,
                              fallbackIconSize: 26,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: TabangColors.crimson,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.surface,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
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

          if (user.role.isAdminSide) ...[
            _buildChapterAffiliationCard(context, user),
            const SizedBox(height: TabangSpace.lg),
          ],

          if (isDonor) ...[
            _buildStatsRow(context, user),
            const SizedBox(height: TabangSpace.lg),
          ],

          _buildDetailsCard(context, user),
          const SizedBox(height: TabangSpace.lg),
          _buildPrivacyCard(context, user),
        ],
      ),
    );
  }

  /// Privacy & data moved here from Settings: this is the page that shows the
  /// account's own record, so the explanation of what other people can see
  /// belongs beside it.
  Widget _buildPrivacyCard(BuildContext context, AppUser user) {
    return SurfaceCard(
      padding: const EdgeInsets.all(TabangSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Privacy & data'),
          const SizedBox(height: TabangSpace.xs),
          Text(
            'Aligned with RA 10173 (Data Privacy Act).',
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
          const SizedBox(height: TabangSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 15, color: context.textMuted),
              const SizedBox(width: TabangSpace.sm),
              Expanded(
                child: Text(
                  'Your real name and exact address are never shown to other '
                  'users. Donors and recipients appear as aliases until both '
                  'sides agree to reveal their identity. Staff see real names '
                  'only for verified care coordination.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: context.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.md),
          _detailRow(context, 'Public identity', user.alias),
          _detailRow(context, 'Account type', user.role.label),
          _detailRow(context, 'Visibility', user.isAvailable
              ? 'Listed in the donor directory'
              : 'Hidden from the donor directory'),
          const SizedBox(height: TabangSpace.sm),
          Text(
            'TABANG stores simulated records on this device only. No real '
            'hospital, Red Cross or EHR system is connected.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.55,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// Staff and admin are the people behind the chapter account. The card makes
  /// that official identity explicit: user-facing replies are posted as the
  /// organization, not as a personal alias.
  Widget _buildChapterAffiliationCard(BuildContext context, AppUser user) {
    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ChapterMark(size: 42),
          const SizedBox(width: TabangSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        TabangRepository.chapterName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: context.textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const VerifiedBadge(size: 15),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${user.role.label} · ${TabangRepository.chapterSubtitle}',
                  style: TextStyle(fontSize: 12, color: context.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  'Replies you send in chapter threads are posted under this '
                  'organization identity. Your personal alias stays visible '
                  'only to the chapter console.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
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

  /// Separate avatar sets keep chapter staff visually distinct from community
  /// accounts. The current photo is always included so an older choice remains
  /// visible and selectable.
  List<String> _avatarOptions(AppUser user) {
    final assets = <String>[
      for (
        var i = user.role.isAdminSide ? 37 : 1;
        i <= (user.role.isAdminSide ? 48 : 36);
        i++
      )
        'assets/images/avatars/avatar_${i.toString().padLeft(3, '0')}.png',
    ];
    final current = user.photoAsset;
    if (current != null && !assets.contains(current)) {
      assets.insert(0, current);
    }
    return assets;
  }

  void _showAvatarPicker(BuildContext context, AppUser user) {
    final assets = _avatarOptions(user);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose your profile photo'),
        // A fixed box keeps AlertDialog's intrinsic-width pass away from the
        // scrollable grid, which does not support intrinsic dimensions.
        content: SizedBox(
          width: 430,
          height: 330,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.role.isAdminSide
                    ? 'Chapter staff and administrators pick from a separate '
                          'set so internal accounts are easy to recognise.'
                    : 'Pick the illustration other members see beside your '
                          'alias. Your real photo is never required.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: dialogContext.textMuted,
                ),
              ),
              const SizedBox(height: TabangSpace.md),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 66,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: assets.length,
                  itemBuilder: (context, i) {
                    final asset = assets[i];
                    final selected = asset == user.photoAsset;
                    return Tooltip(
                      message: selected ? 'Current photo' : 'Use this photo',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(40),
                        onTap: () {
                          final messenger = ScaffoldMessenger.of(context);
                          _repo.updateUser(user.copyWith(photoAsset: asset));
                          _repo.logProfileActivity(
                            userId: user.id,
                            kind: ActivityKind.avatar,
                            summary: 'Changed their profile photo',
                          );
                          Navigator.pop(dialogContext);
                          messenger.showSnackBar(
                            const TabangSnackBar(
                              content: Text('Profile photo updated.'),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? TabangColors.crimsonSoft
                                : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? TabangColors.crimson
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: TabangPhoto(
                              asset,
                              semanticLabel: 'Profile photo option ${i + 1}',
                              creditLabel: 'TABANG bundled avatar',
                              fallbackIcon: Icons.person_outline,
                              fallbackIconSize: 20,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
                    TabangDropdown<String>(
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
                      TabangDropdown<BloodType>(
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
                final newName = nameController.text.trim();
                final newAlias = aliasController.text.trim();
                final newPhone = phoneController.text.trim();
                final newWeight = user.role == UserRole.donor
                    ? double.tryParse(weightController.text.trim())
                    : null;
                final typeChanged =
                    user.role == UserRole.donor && bloodType != user.bloodType;

                // The audit entry names the fields, so the console can show
                // what changed instead of just "profile updated".
                final changed = <String>[
                  if (newName != user.fullName) 'full name',
                  if (newAlias != user.alias) 'alias',
                  if (newPhone != user.phone) 'contact number',
                  if (barangay != user.barangay) 'barangay',
                  if (bloodType != user.bloodType) 'blood type',
                  if (user.role == UserRole.donor && newWeight != user.weightKg)
                    'weight',
                ];

                _repo.updateUser(
                  user.copyWith(
                    fullName: newName,
                    alias: newAlias,
                    phone: newPhone,
                    barangay: barangay,
                    bloodType: bloodType,
                    weightKg: newWeight,
                    status: typeChanged ? AccountStatus.unverified : null,
                    bloodCardVerified: typeChanged ? false : null,
                  ),
                );
                _repo.logProfileActivity(
                  userId: user.id,
                  kind: ActivityKind.profile,
                  summary: changed.isEmpty
                      ? 'Saved profile details'
                      : 'Updated ${changed.join(', ')}',
                );
                Navigator.pop(dialogContext);
                if (typeChanged) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const TabangSnackBar(
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
