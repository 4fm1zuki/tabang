import 'package:flutter/material.dart';

import '../../core/eligibility.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/donor_registration_dialog.dart';
import '../../widgets/layout.dart';
import '../../widgets/photo.dart';

/// A dedicated home for the donor role.
///
/// Donors are also community members, so this page deliberately keeps blood
/// requests and messages one tap away. The previous navigation merged donors
/// into the recipient experience and lost the "donor tab" the checklist asks
/// for; this surface separates donor status without locking donors out of the
/// request side of the app.
class DonorHubPage extends StatefulWidget {
  const DonorHubPage({
    super.key,
    required this.user,
    this.onOpenRequests,
    this.onOpenMessages,
  });

  final AppUser user;
  final VoidCallback? onOpenRequests;
  final VoidCallback? onOpenMessages;

  @override
  State<DonorHubPage> createState() => _DonorHubPageState();
}

class _DonorHubPageState extends State<DonorHubPage> {
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

  Future<void> _registerAsDonor() async {
    final submitted = await showDonorRegistrationDialog(context, widget.user);
    if (!mounted || !submitted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registration submitted'),
        content: Text(
          'Chapter staff now sees your form. Bring your ID: the interview, '
          'physical examination, blood typing and screening happen at the '
          'chapter. Until staff verifies you, your profile stays out of the '
          'donor directory — you can still request blood or message donors as '
          'a community member.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.55,
            color: context.textMuted,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _repo.userById(widget.user.id) ?? widget.user;
    if (user.role == UserRole.donor) return _buildDonor(context, user);
    return _buildJoin(context, user);
  }

  Widget _buildJoin(BuildContext context, AppUser user) {
    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Donor hub',
            subtitle:
                'Give blood on your own terms. Your nickname stays public.',
          ),
          const SizedBox(height: TabangSpace.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(TabangSpace.xl),
            decoration: BoxDecoration(
              // A gradient on its own read as an unfinished block; the border
              // and shadow give it the same card structure as every panel.
              color: context.surface,
              gradient: TabangGradients.forContext(context),
              borderRadius: BorderRadius.circular(TabangRadius.lg),
              border: Border.all(
                color: TabangColors.crimson.withValues(
                  alpha: context.isDark ? 0.35 : 0.28,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: context.isDark ? 0.3 : 0.06,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.volunteer_activism_outlined,
                      color: TabangColors.crimson,
                      size: 26,
                    ),
                    const SizedBox(width: TabangSpace.md),
                    Expanded(
                      child: Text(
                        'Become a volunteer donor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: context.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TabangSpace.sm),
                Text(
                  'Donating and needing blood are not mutually exclusive. '
                  'Registering adds your blood type and availability to the '
                  'verified directory while keeping your real name private.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.55,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: TabangSpace.lg),
                const Wrap(
                  spacing: TabangSpace.sm,
                  runSpacing: TabangSpace.sm,
                  children: [
                    _Benefit(
                      icon: Icons.verified_user_outlined,
                      label: 'Staff-verified',
                    ),
                    _Benefit(icon: Icons.lock_outline, label: 'Nickname only'),
                    _Benefit(
                      icon: Icons.toggle_on_outlined,
                      label: 'You control availability',
                    ),
                    _Benefit(
                      icon: Icons.health_and_safety_outlined,
                      label: 'Clinical screening',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: TabangSpace.lg),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('How donor registration works'),
                Text(
                  'Registration is completed face-to-face at the chapter. '
                  'Telling the app you are coming just lets staff prepare and '
                  'expect you.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: TabangSpace.md),
                for (final step in const [
                  '1 · Send your registration interest from here',
                  '2 · Visit the PRC chapter in Digos with your ID',
                  '3 · Interview, examination, blood typing and screening',
                  '4 · The chapter issues or renews your donor card',
                  '5 · Staff verifies you here — you appear in the directory',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      step,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: context.textColor,
                      ),
                    ),
                  ),
                const SizedBox(height: TabangSpace.md),
                const SectionLabel('What to bring'),
                const SizedBox(height: TabangSpace.md),
                for (final requirement in kDonorRequirements)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: TabangColors.crimson.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            requirement,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: context.textColor,
                            ),
                          ),
                        ),
                        Text(
                          'At the chapter',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: TabangSpace.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _registerAsDonor,
                    icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                    label: const Text('Start donor registration'),
                  ),
                ),
                const SizedBox(height: TabangSpace.sm),
                Text(
                  'TABANG follows RA 7719: donors are voluntary and unpaid. '
                  'You may withdraw at any time before the needle is inserted.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
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

  /// What stands between the applicant and a verified donor card.
  Widget _buildVerificationCard(
    BuildContext context,
    AppUser user,
    DonorApplication? application,
  ) {
    final status = application?.status ?? DonorApplicationStatus.pending;
    final tone = switch (status) {
      DonorApplicationStatus.verified => Tone.success,
      DonorApplicationStatus.rejected => Tone.danger,
      DonorApplicationStatus.documentsRequested => Tone.info,
      DonorApplicationStatus.pending => Tone.warning,
    };
    final documents = application?.requestedDocuments ?? const <String>[];

    return SurfaceCard(
      highlighted: status == DonorApplicationStatus.documentsRequested,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 18,
                color: TabangColors.crimson,
              ),
              const SizedBox(width: TabangSpace.sm),
              Expanded(
                child: Text(
                  'Donor verification',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: context.textColor,
                  ),
                ),
              ),
              StatusPill(status.label, tone: tone, dense: true),
            ],
          ),
          const SizedBox(height: TabangSpace.sm),
          Text(
            application == null
                ? 'No registration form is on file yet. Fill it up so chapter '
                      'staff can review your details before your first donation.'
                : 'Form ${application.id} submitted '
                      '${formatRelative(application.submittedAt)}. Chapter staff '
                      'verifies your blood card in person; your profile joins the '
                      'directory only after that.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: context.textMuted,
            ),
          ),
          if (application != null) ...[
            const SizedBox(height: TabangSpace.md),
            Wrap(
              spacing: TabangSpace.sm,
              runSpacing: 6,
              children: [
                StatusPill(
                  application.hasExistingCard
                      ? 'Has a PRC donor card'
                      : 'Needs a new donor card',
                  tone: application.hasExistingCard
                      ? Tone.success
                      : Tone.neutral,
                  dense: true,
                ),
                if (application.cardNumber != null)
                  StatusPill(
                    'Card ${application.cardNumber}',
                    tone: Tone.info,
                    dense: true,
                  ),
                if (application.preferredVisit != null)
                  StatusPill(
                    'Visiting ${formatDate(application.preferredVisit!)}',
                    tone: Tone.brand,
                    dense: true,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The medical interview, examination, blood typing and screening '
              'are done by chapter staff on the day you visit — nothing '
              'medical is answered in the app.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: context.textMuted,
              ),
            ),
          ],
          if (documents.isNotEmpty) ...[
            const SizedBox(height: TabangSpace.md),
            Text(
              'Requested through chapter staff',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: 6),
            for (final document in documents)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.pending_actions_outlined,
                      size: 15,
                      color: TabangColors.warning,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        document,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: context.textColor,
                        ),
                      ),
                    ),
                    Text(
                      'To present',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (application?.staffNote != null) ...[
            const SizedBox(height: TabangSpace.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(TabangSpace.md),
              decoration: BoxDecoration(
                color: context.surfaceAlt,
                borderRadius: BorderRadius.circular(TabangRadius.sm),
              ),
              child: Text(
                'Chapter note: ${application!.staffNote}',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: context.textColor,
                ),
              ),
            ),
          ],
          const SizedBox(height: TabangSpace.md),
          SizedBox(
            width: double.infinity,
            child: application == null
                ? FilledButton.icon(
                    onPressed: _registerAsDonor,
                    icon: const Icon(Icons.how_to_reg_outlined, size: 17),
                    label: const Text('Start donor registration'),
                  )
                : OutlinedButton.icon(
                    onPressed: _registerAsDonor,
                    icon: const Icon(Icons.refresh_outlined, size: 17),
                    label: const Text('Update my registration'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonor(BuildContext context, AppUser user) {
    final eligibility = EligibilityEngine.evaluate(user);
    final nextDate = eligibility.eligibleFrom;
    final application = _repo.donorApplicationFor(user.id);
    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Donor hub',
            subtitle: 'Your availability, impact and next donation window.',
            actions: [
              FilledButton.icon(
                onPressed: widget.onOpenRequests,
                icon: const Icon(Icons.assignment_outlined, size: 17),
                label: const Text('Requests'),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),
          if (!user.bloodCardVerified) ...[
            _buildVerificationCard(context, user, application),
            const SizedBox(height: TabangSpace.lg),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(TabangSpace.xl),
            decoration: BoxDecoration(
              gradient: TabangGradients.donorHero,
              borderRadius: BorderRadius.circular(TabangRadius.lg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 500;
                final identity = Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 58,
                          height: 58,
                          child: TabangPhoto(
                            user.photoAsset,
                            semanticLabel: '${user.alias} profile illustration',
                            creditLabel: user.alias,
                            fallbackIcon: Icons.person_outline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: TabangSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.alias,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${user.barangay} · ${user.bloodType?.label ?? "—"}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(
                      user.bloodCardVerified
                          ? (eligibility.isEligible ? 'Eligible' : 'Cooldown')
                          : 'Pending verification',
                      tone: !user.bloodCardVerified
                          ? Tone.warning
                          : eligibility.isEligible
                          ? Tone.success
                          : Tone.warning,
                      onImage: true,
                    ),
                  ],
                );
                final stats = Wrap(
                  spacing: TabangSpace.xl,
                  runSpacing: TabangSpace.md,
                  children: [
                    _HeroStat(
                      value: '${user.totalDonations}',
                      label: 'donations',
                    ),
                    _HeroStat(
                      value: '${(user.totalDonations * 3).clamp(0, 999)}',
                      label: 'lives touched',
                    ),
                    _HeroStat(
                      value: nextDate == null
                          ? 'Now'
                          : '${eligibility.daysRemaining}d',
                      label: nextDate == null ? 'available' : 'to next gift',
                    ),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identity,
                      const SizedBox(height: TabangSpace.lg),
                      stats,
                      const SizedBox(height: TabangSpace.sm),
                      PhotoCredit(
                        user.photoAsset,
                        label: user.alias,
                        onImage: true,
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: TabangSpace.lg),
                        stats,
                      ],
                    ),
                    const SizedBox(height: TabangSpace.sm),
                    PhotoCredit(
                      user.photoAsset,
                      label: user.alias,
                      onImage: true,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: TabangSpace.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final availability = _buildAvailability(context, user);
              final next = _buildNextWindow(context, user, eligibility);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: availability),
                    const SizedBox(width: TabangSpace.lg),
                    Expanded(child: next),
                  ],
                );
              }
              return Column(
                children: [
                  availability,
                  const SizedBox(height: TabangSpace.lg),
                  next,
                ],
              );
            },
          ),
          const SizedBox(height: TabangSpace.lg),
          _buildHistory(context, user),
        ],
      ),
    );
  }

  Widget _buildAvailability(BuildContext context, AppUser user) {
    final away = EligibilityEngine.isAway(user);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Directory availability'),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: user.isAvailable && !away
                      ? context.successBg
                      : context.surfaceAlt,
                  borderRadius: BorderRadius.circular(TabangRadius.sm),
                ),
                child: Icon(
                  user.isAvailable && !away
                      ? Icons.toggle_on_outlined
                      : Icons.toggle_off_outlined,
                  color: user.isAvailable && !away
                      ? TabangColors.success
                      : context.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: TabangSpace.md),
              Expanded(
                child: Text(
                  away
                      ? 'Away — you are hidden from the donor directory.'
                      : user.isAvailable
                      ? 'You are visible to compatible recipients.'
                      : 'You are hidden from the donor directory.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: context.textMuted,
                  ),
                ),
              ),
              Switch(
                value: user.isAvailable,
                onChanged: (value) =>
                    _repo.setDonorAvailability(user.id, value),
              ),
            ],
          ),
          if (away) ...[
            const SizedBox(height: TabangSpace.sm),
            Container(
              padding: const EdgeInsets.fromLTRB(TabangSpace.sm, 4, 4, 4),
              decoration: BoxDecoration(
                color: context.warningBg,
                borderRadius: BorderRadius.circular(TabangRadius.xs),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.hourglass_bottom,
                    size: 16,
                    color: TabangColors.warning,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'TABANG marks donors away after 30 days without activity, '
                      'even while the switch above is on.',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.45,
                        color: TabangColors.warning,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _repo.markActive(user.id),
                    child: const Text("I'm active"),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: TabangSpace.sm),
          Text(
            'TABANG hides you automatically during cooldown even if this '
            'switch is on. Exact addresses are never shown.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.45,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextWindow(
    BuildContext context,
    AppUser user,
    EligibilityResult eligibility,
  ) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Next donation window'),
          Row(
            children: [
              BloodTypeChip(user.bloodType ?? BloodType.oPos, size: 38),
              const SizedBox(width: TabangSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eligibility.isEligible
                          ? 'Eligible now'
                          : eligibility.eligibleFrom != null
                          ? 'Eligible from ${formatDate(eligibility.eligibleFrom!)}'
                          : eligibility.blocker.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      eligibility.isEligible
                          ? 'Whole blood · 12-week interval satisfied'
                          : eligibility.daysRemaining > 0
                          ? '${eligibility.daysRemaining} days remaining · '
                                '${eligibility.blocker.label}'
                          : eligibility.blocker.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(TabangRadius.pill),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: eligibility.isEligible
                  ? 1
                  : (1 - eligibility.daysRemaining / 84).clamp(0.0, 1.0),
            ),
          ),
          const SizedBox(height: TabangSpace.md),
          Text(
            'Whole blood and red cells: 84 days · Platelets: 14 days · '
            'Plasma: 28 days.',
            style: TextStyle(
              fontSize: 10,
              height: 1.45,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(BuildContext context, AppUser user) {
    final entries = <DateTime>[];
    var cursor = user.lastDonationDate;
    for (var i = 0; i < user.totalDonations.clamp(0, 4); i++) {
      if (cursor == null) break;
      entries.add(cursor);
      cursor = cursor.subtract(const Duration(days: 84));
    }
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Donation history'),
          if (entries.isEmpty)
            Text(
              'No recorded donations yet. Your first verified donation will '
              'appear here.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: context.textMuted,
              ),
            )
          else
            ...entries.map(
              (date) => Padding(
                padding: const EdgeInsets.only(bottom: TabangSpace.md),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: TabangColors.crimson,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: TabangSpace.md),
                    Expanded(
                      child: Text(
                        'Whole blood donation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.textColor,
                        ),
                      ),
                    ),
                    Text(
                      formatDate(date),
                      style: TextStyle(fontSize: 11, color: context.textMuted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(TabangRadius.pill),
        border: Border.all(color: context.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: TabangColors.crimson),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: context.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.6,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}
