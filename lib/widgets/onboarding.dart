import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/repository.dart';
import '../theme.dart';
import 'illustrations.dart';

/// True when the signed-in record changed in a way that the shell's cached
/// pages captured in their widget configuration. Preference-only changes
/// (ui mode, notification toggles, onboarding flag) deliberately do not
/// remount pages; those pages read the repository live.
bool shellUserChanged(AppUser before, AppUser after) {
  return before.id != after.id ||
      before.role != after.role ||
      before.bloodType != after.bloodType ||
      before.alias != after.alias ||
      before.fullName != after.fullName ||
      before.barangay != after.barangay ||
      before.status != after.status;
}

/// A single entry in the first-run walkthrough.
class GuideStep {
  const GuideStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

/// Plain-language instructions tailored to the signed-in role.
///
/// The goal is that a first-time smartphone user can finish the three things
/// that matter without reading documentation: complete a profile, find the
/// primary action, and understand who can see their identity.
List<GuideStep> guideStepsFor(AppUser user) {
  switch (user.role) {
    case UserRole.donor:
      return const [
        GuideStep(
          icon: Icons.badge_outlined,
          title: 'Complete your profile',
          body:
              'Add your weight and blood type, then let chapter staff verify '
              'your blood card. Verified donors appear in the donor list.',
        ),
        GuideStep(
          icon: Icons.toggle_on_outlined,
          title: 'Set your availability',
          body:
              'In your Profile, mark yourself available when you can donate. '
              'TABANG hides you automatically during your recovery cooldown.',
        ),
        GuideStep(
          icon: Icons.campaign_outlined,
          title: 'Respond to requests',
          body:
              'Open Requests to see compatible requests. Your response is an '
              'offer, not a commitment — the requester chooses a donor.',
        ),
        GuideStep(
          icon: Icons.lock_outline,
          title: 'Your identity stays private',
          body:
              'Other users only ever see your nickname. Your real name and '
              'contact details are shared only if you both accept a reveal.',
        ),
      ];
    case UserRole.user:
      return const [
        GuideStep(
          icon: Icons.explore_outlined,
          title: 'Start with Discover',
          body:
              'Browse updates, donation drives and guides. Everything is '
              'available before you decide to donate.',
        ),
        GuideStep(
          icon: Icons.add_circle_outline,
          title: 'Request blood when needed',
          body:
              'You can post a request for a patient at any time. TABANG checks '
              'participating blood banks before posting to donors.',
        ),
        GuideStep(
          icon: Icons.volunteer_activism_outlined,
          title: 'Become a donor later',
          body:
              'Open your profile and choose Register as a donor. Chapter staff '
              'verify your blood card before you appear in the directory.',
        ),
      ];
    case UserRole.recipient:
      return const [
        GuideStep(
          icon: Icons.add_circle_outline,
          title: 'Create a request',
          body:
              'Open Requests and tap New request. TABANG checks participating '
              'blood banks first; if stock is short it posts to donors.',
        ),
        GuideStep(
          icon: Icons.how_to_reg_outlined,
          title: 'Choose your donor',
          body:
              'When donors respond, review their eligibility and select the '
              'ones you want. Selection opens a private chat.',
        ),
        GuideStep(
          icon: Icons.forum_outlined,
          title: 'Coordinate in Messages',
          body:
              'Arrange the donation in Messages. Nicknames are used until '
              'both of you agree to reveal real names.',
        ),
      ];
    case UserRole.staff:
    case UserRole.admin:
      return const [
        GuideStep(
          icon: Icons.people_outline,
          title: 'Verify and manage accounts',
          body:
              'Open Users to verify blood cards, record donations, warn or '
              'suspend accounts. You cannot act on your own account.',
        ),
        GuideStep(
          icon: Icons.inventory_2_outlined,
          title: 'Manage inventory',
          body:
              'Inventory tracks component, storage bay and expiry. Expired '
              'bags are excluded from every count automatically.',
        ),
        GuideStep(
          icon: Icons.gavel_outlined,
          title: 'Moderate conversations',
          body:
              'Reports raised in Messages land in Moderation. Resolve or '
              'dismiss them there — the audit trail is kept.',
        ),
      ];
  }
}

/// First-run walkthrough. Shows once per account; users can replay it from
/// Settings at any time.
Future<void> showWelcomeGuide(
  BuildContext context,
  AppUser user, {
  bool markSeen = true,
}) async {
  final steps = guideStepsFor(user);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(TabangSpace.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TabangRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TabangSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: TabangIllustration(TabangArt.welcome, size: 128),
              ),
              const SizedBox(height: TabangSpace.md),
              Center(
                child: Text(
                  'Welcome, ${user.alias}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: dialogContext.textColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Here is everything you need to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: dialogContext.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: TabangSpace.lg),
              for (var i = 0; i < steps.length; i++) ...[
                _GuideRow(index: i + 1, step: steps[i]),
                if (i != steps.length - 1) const SizedBox(height: TabangSpace.md),
              ],
              const SizedBox(height: TabangSpace.xl),
              // One action only: "Skip" and "Got it" both just closed the
              // dialog, so the pair was redundant. The guide stays available
              // from Guides & help at any time.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  if (markSeen) {
    TabangRepository.instance.completeOnboarding(user.id);
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.index, required this.step});

  final int index;
  final GuideStep step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.isDark
                ? const Color(0xFF3A1917)
                : TabangColors.crimsonSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(step.icon, size: 17, color: TabangColors.crimson),
        ),
        const SizedBox(width: TabangSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                step.body,
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
    );
  }
}
