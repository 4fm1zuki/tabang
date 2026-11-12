import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/repository.dart';
import '../theme.dart';
import 'common.dart';

/// Colour that stays legible on both themes.
Color warningInk(BuildContext context) =>
    context.isDark ? TabangColors.warningOnDark : TabangColors.warning;

/// The consequences of an active warning, shared by the reminder and Settings.
///
/// Keeping the wording in one place means the sign-in popup, profile banner and
/// settings history all explain the same ladder instead of drifting apart.
const List<String> warningConsequences = [
  'Every warning is saved on your account and visible to chapter staff.',
  'Three active warnings suspend the account automatically.',
  'While suspended you cannot sign in, request blood, or appear in the donor '
      'directory until staff reinstate the account.',
];

/// What the account holder should do after a warning.
const List<String> warningNextSteps = [
  'Read the staff message carefully and stop the behaviour it describes.',
  'Reply to the chapter in Messages if you need to explain or correct a '
      'detail.',
  'Open About & Help to review the community and donation rules.',
  'Cancel or reschedule a booked slot as early as possible instead of not '
      'showing up.',
];

/// Compact banner on the signed-in user's own profile.
class AccountWarningNotice extends StatelessWidget {
  const AccountWarningNotice({
    super.key,
    required this.user,
    required this.warnings,
  });

  final AppUser user;
  final List<AccountWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final latest = warnings.isEmpty ? null : warnings.first;
    final active = user.warningCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TabangSpace.lg),
      decoration: BoxDecoration(
        color: context.warningBg,
        borderRadius: BorderRadius.circular(TabangRadius.lg),
        border: Border.all(color: warningInk(context).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: warningInk(context).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.priority_high_rounded,
                  size: 19,
                  color: warningInk(context),
                ),
              ),
              const SizedBox(width: TabangSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active == 1
                          ? 'Your account has 1 active warning'
                          : 'Your account has $active active warnings',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: warningInk(context),
                      ),
                    ),
                    Text(
                      'Three active warnings suspend the account.',
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (latest != null) ...[
            const SizedBox(height: TabangSpace.md),
            Text(
              'Latest message from ${latest.issuedByAlias}:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              latest.message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: context.textColor,
              ),
            ),
          ],
          const SizedBox(height: TabangSpace.sm),
          Text(
            'The full history and what to do next are in Account standing '
            'below.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// One warning record with its level, issuer, date and exact staff message.
class AccountWarningTile extends StatelessWidget {
  const AccountWarningTile({super.key, required this.warning});

  final AccountWarning warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: TabangSpace.sm),
      padding: const EdgeInsets.all(TabangSpace.md),
      decoration: BoxDecoration(
        color: context.warningBg,
        borderRadius: BorderRadius.circular(TabangRadius.sm),
        border: Border.all(color: warningInk(context).withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(
                'Warning ${warning.level} of 3',
                tone: Tone.warning,
                dense: true,
                icon: Icons.flag_outlined,
              ),
              if (warning.isUnacknowledged)
                const StatusPill('New', tone: Tone.info, dense: true),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            warning.message,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${warning.issuedByAlias} · ${formatDateTime(warning.issuedAt)}',
            style: TextStyle(fontSize: 11, color: context.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Bulleted explanation used by the reminder and the Settings standing card.
class WarningGuidance extends StatelessWidget {
  const WarningGuidance({
    super.key,
    required this.title,
    required this.lines,
    this.icon = Icons.info_outline,
  });

  final String title;
  final List<String> lines;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: context.textColor,
          ),
        ),
        const SizedBox(height: 5),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 14, color: warningInk(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: context.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Sign-in reminder for any warnings the user has not confirmed yet.
///
/// The dialog explains why the account was warned, the risk of another warning,
/// and the next step. Closing it marks those warnings as confirmed, so it does
/// not reappear on every page rebuild; the history stays in Profile/Settings.
Future<void> showSignInWarningReminder(
  BuildContext context, {
  required AppUser user,
}) async {
  final repo = TabangRepository.instance;
  final warnings = repo.unacknowledgedWarningsFor(user.id);
  if (warnings.isEmpty) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.priority_high_rounded, color: warningInk(dialogContext)),
          const SizedBox(width: TabangSpace.sm),
          const Expanded(child: Text('A warning is on your account')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chapter staff reviewed your activity and left the message '
                'below. It is saved on your account and stays visible in '
                'Profile and Settings.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: dialogContext.textMuted,
                ),
              ),
              const SizedBox(height: TabangSpace.md),
              ...warnings.map(
                (warning) => AccountWarningTile(warning: warning),
              ),
              const SizedBox(height: TabangSpace.xs),
              const WarningGuidance(
                title: 'Why this matters',
                lines: warningConsequences,
                icon: Icons.shield_outlined,
              ),
              const SizedBox(height: TabangSpace.sm),
              const WarningGuidance(
                title: 'What to do next',
                lines: warningNextSteps,
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            repo.acknowledgeWarnings(user.id);
            Navigator.pop(dialogContext);
          },
          child: const Text('I understand'),
        ),
      ],
    ),
  );
}
