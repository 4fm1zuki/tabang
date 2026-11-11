import 'package:flutter/material.dart';

import '../core/eligibility.dart';
import '../core/models.dart';
import '../theme.dart';
import 'common.dart';
import 'photo.dart';

/// One donor row, shared by Find Donor and the staff Operations map.
///
/// Both surfaces show the same facts — photo, blood type, alias, barangay,
/// eligibility and donation history — so a donor reads identically to a
/// community user and to chapter staff. Only the trailing [actions] and what
/// tapping the card does differ, which the caller supplies.
class DonorListCard extends StatelessWidget {
  const DonorListCard({
    super.key,
    required this.donor,
    required this.eligibility,
    this.commitmentId,
    this.onTap,
    this.onTapHint,
    this.actions = const [],
  });

  final AppUser donor;
  final EligibilityResult eligibility;

  /// Active request this donor is already coordinating, if any. Shown as a
  /// pill so the same donor is not reserved for two requests at once.
  final String? commitmentId;

  final VoidCallback? onTap;

  /// Tooltip for the card tap, when [onTap] is set.
  final String? onTapHint;

  /// Trailing action buttons; each surface passes the ones that make sense for
  /// the viewer (a donor can message a peer, staff open the account record).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final card = SurfaceCard(
      padding: const EdgeInsets.all(TabangSpace.lg),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: TabangPhoto(
                    donor.photoAsset,
                    semanticLabel: '${donor.mapHandle} profile illustration',
                    creditLabel: donor.mapHandle,
                    fallbackIcon: Icons.person_outline,
                    fallbackIconSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: TabangSpace.sm),
              BloodTypeChip(donor.bloodType ?? BloodType.oPos, size: 30),
              const SizedBox(width: TabangSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donor.mapHandle,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                    Text(
                      donor.shareBarangay ? donor.barangay : 'Barangay hidden',
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                  ],
                ),
              ),
              StatusPill(
                eligibility.isEligible ? 'Eligible' : 'Cooldown',
                tone: toneForEligibility(eligibility),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.sm),
          Row(
            children: [
              Icon(Icons.favorite_border, size: 14, color: context.textMuted),
              const SizedBox(width: 4),
              Text(
                '${donor.totalDonations} donations',
                style: TextStyle(fontSize: 12.5, color: context.textMuted),
              ),
              const SizedBox(width: TabangSpace.md),
              Icon(Icons.schedule, size: 14, color: context.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  donor.lastDonationDate == null
                      ? 'First-time donor'
                      : 'Last ${formatDate(donor.lastDonationDate!)}',
                  style: TextStyle(fontSize: 12.5, color: context.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (commitmentId != null || actions.isNotEmpty) ...[
            const SizedBox(height: TabangSpace.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (commitmentId != null)
                  Tooltip(
                    message:
                        'This donor is already selected for another active '
                        'request. They stay visible, but cannot be reserved for '
                        'two requests at once.',
                    child: StatusPill(
                      'Coordinating · $commitmentId',
                      tone: Tone.info,
                      dense: true,
                    ),
                  ),
                ...actions,
              ],
            ),
          ],
        ],
      ),
    );

    final hint = onTapHint;
    if (hint == null || onTap == null) return card;
    return Tooltip(message: hint, child: card);
  }
}
